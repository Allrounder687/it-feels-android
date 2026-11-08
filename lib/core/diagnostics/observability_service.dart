import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'models/log_entry.dart';
import 'models/log_level.dart';
import 'models/diagnostic_subsystem.dart';
import 'models/trace_context.dart';
import 'storage/rotating_log_file_sink.dart';

/// Centralized, production-grade observability and structured logging engine.
///
/// Features:
/// 1. Unified structured logging with standard severity levels (TRACE to FATAL).
/// 2. Automatic multi-pattern privacy scrubbing (redacts tokens, emails, PII, paths).
/// 3. Bounded in-memory circular buffer (200 records) for real-time dashboard inspection.
/// 4. Asynchronous file sink with log rotation and retention management.
/// 5. Trace and correlation ID tracking across decoupled subsystems.
/// 6. High-frequency event deduplication and sampling safeguards.
class ObservabilityService {
  static final ObservabilityService instance = ObservabilityService._internal();
  factory ObservabilityService() => instance;

  static const int _maxInMemoryEntries = 200;

  final List<LogEntry> _inMemoryEntries = [];
  final StreamController<LogEntry> _logStreamController = StreamController<LogEntry>.broadcast();
  final Map<String, DateTime> _recentDeduplicationMap = {};
  final Random _rng = Random();

  String _appVersion = '3.9.4';
  String _buildNumber = '1';
  String _platformName = 'unknown';
  bool _isInitialized = false;

  ObservabilityService._internal();

  /// Stream of emitted log records for reactive UI diagnostic dashboards.
  Stream<LogEntry> get logStream => _logStreamController.stream;

  /// Initializes system metadata and local storage sink.
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      if (!kIsWeb) {
        if (Platform.isAndroid) {
          _platformName = 'android';
        } else if (Platform.isIOS) {
          _platformName = 'ios';
        } else if (Platform.isWindows) {
          _platformName = 'windows';
        } else if (Platform.isMacOS) {
          _platformName = 'macos';
        } else if (Platform.isLinux) {
          _platformName = 'linux';
        }
      } else {
        _platformName = 'web';
      }

      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version.isNotEmpty ? info.version : '3.9.4';
      _buildNumber = info.buildNumber.isNotEmpty ? info.buildNumber : '1';
    } catch (_) {
      _platformName = Platform.operatingSystem;
    }

    await RotatingLogFileSink.instance.init();
    info(
      subsystem: DiagnosticSubsystem.lifecycle,
      component: 'ObservabilityService',
      eventName: 'observability_initialized',
      metadata: {
        'platform': _platformName,
        'appVersion': _appVersion,
        'buildNumber': _buildNumber,
        'sessionId': TraceContext.currentSessionId,
      },
    );
  }

  // --- Core Logging API ---

  void trace({
    required DiagnosticSubsystem subsystem,
    required String component,
    required String eventName,
    String? correlationId,
    int? durationMs,
    Map<String, dynamic>? metadata,
  }) {
    _emit(
      level: LogLevel.trace,
      subsystem: subsystem,
      component: component,
      eventName: eventName,
      correlationId: correlationId,
      durationMs: durationMs,
      metadata: metadata,
    );
  }

  void debug({
    required DiagnosticSubsystem subsystem,
    required String component,
    required String eventName,
    String? correlationId,
    int? durationMs,
    Map<String, dynamic>? metadata,
  }) {
    _emit(
      level: LogLevel.debug,
      subsystem: subsystem,
      component: component,
      eventName: eventName,
      correlationId: correlationId,
      durationMs: durationMs,
      metadata: metadata,
    );
  }

  void info({
    required DiagnosticSubsystem subsystem,
    required String component,
    required String eventName,
    String? correlationId,
    int? durationMs,
    Map<String, dynamic>? metadata,
  }) {
    _emit(
      level: LogLevel.info,
      subsystem: subsystem,
      component: component,
      eventName: eventName,
      correlationId: correlationId,
      durationMs: durationMs,
      metadata: metadata,
    );
  }

  void warn({
    required DiagnosticSubsystem subsystem,
    required String component,
    required String eventName,
    String? correlationId,
    int? durationMs,
    String? errorCode,
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) {
    _emit(
      level: LogLevel.warn,
      subsystem: subsystem,
      component: component,
      eventName: eventName,
      correlationId: correlationId,
      durationMs: durationMs,
      errorCode: errorCode,
      errorMessage: errorMessage,
      metadata: metadata,
    );
  }

  void error({
    required DiagnosticSubsystem subsystem,
    required String component,
    required String eventName,
    String? correlationId,
    int? durationMs,
    String? errorCode,
    required String errorMessage,
    dynamic stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    _emit(
      level: LogLevel.error,
      subsystem: subsystem,
      component: component,
      eventName: eventName,
      correlationId: correlationId,
      durationMs: durationMs,
      errorCode: errorCode ?? 'ERR-GENERIC',
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      metadata: metadata,
    );
  }

  void fatal({
    required DiagnosticSubsystem subsystem,
    required String component,
    required String eventName,
    String? correlationId,
    int? durationMs,
    String? errorCode,
    required String errorMessage,
    dynamic stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    _emit(
      level: LogLevel.fatal,
      subsystem: subsystem,
      component: component,
      eventName: eventName,
      correlationId: correlationId,
      durationMs: durationMs,
      errorCode: errorCode ?? 'ERR-FATAL',
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      metadata: metadata,
    );
  }

  // --- Internal Event Dispatcher & Safeguards ---

  void _emit({
    required LogLevel level,
    required DiagnosticSubsystem subsystem,
    required String component,
    required String eventName,
    String? correlationId,
    int? durationMs,
    String? errorCode,
    String? errorMessage,
    dynamic stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    // Duplicate warning suppression: identical message within 5s
    if (level == LogLevel.warn && errorMessage != null) {
      final key = '$subsystem:$component:$errorMessage';
      final now = DateTime.now();
      final lastEmitted = _recentDeduplicationMap[key];
      if (lastEmitted != null && now.difference(lastEmitted) < const Duration(seconds: 5)) {
        return; // Suppressed duplicate
      }
      _recentDeduplicationMap[key] = now;
      if (_recentDeduplicationMap.length > 50) {
        _recentDeduplicationMap.remove(_recentDeduplicationMap.keys.first);
      }
    }

    final eventId = _generateEventId(subsystem);
    final sanitizedMessage = errorMessage != null ? scrubSensitiveData(errorMessage) : null;
    final stackSnippet = _extractStackTraceSnippet(stackTrace);
    final sanitizedMeta = metadata != null ? _sanitizeMetadata(metadata) : null;

    final entry = LogEntry(
      timestamp: DateTime.now().toUtc(),
      level: level,
      appVersion: _appVersion,
      buildNumber: _buildNumber,
      platform: _platformName,
      module: subsystem,
      component: component,
      eventName: eventName,
      eventId: eventId,
      correlationId: correlationId,
      sessionId: TraceContext.currentSessionId,
      operationDurationMs: durationMs,
      errorCode: errorCode,
      errorMessage: sanitizedMessage,
      stackTrace: stackSnippet,
      metadata: sanitizedMeta,
    );

    // Bounded in-memory queue
    _inMemoryEntries.add(entry);
    if (_inMemoryEntries.length > _maxInMemoryEntries) {
      _inMemoryEntries.removeAt(0);
    }

    // Print to developer console in debug mode
    if (kDebugMode && level.isAtLeast(LogLevel.info)) {
      debugPrint('[${level.label}] [${subsystem.name}:$component] $eventName ${entry.errorMessage ?? ''}');
    }

    // Stream for UI
    if (!_logStreamController.isClosed) {
      _logStreamController.add(entry);
    }

    // Disk persistence
    RotatingLogFileSink.instance.enqueue(entry);
  }

  // --- Privacy & Sensitive Data Scrubbing ---

  /// Scrubs sensitive credentials, tokens, bearer authorizations, passwords, emails,
  /// user directory paths, and signed media URLs.
  static String scrubSensitiveData(String input) {
    if (input.isEmpty) return input;
    String sanitized = input;

    // 1. Bearer authorization tokens
    sanitized = sanitized.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
      'Bearer [REDACTED_TOKEN]',
    );

    // 2. Email addresses
    sanitized = sanitized.replaceAll(
      RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
      '[REDACTED_EMAIL]',
    );

    // 3. Passwords and credentials in JSON or query params
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'(password|secret|apiKey|api_key|token|auth)["\s:=]+([^"\s,&]+)', caseSensitive: false),
      (match) => '${match.group(1)}=[REDACTED]',
    );

    // 4. Windows user paths with personal names (e.g. C:\Users\Username\...)
    sanitized = sanitized.replaceAll(
      RegExp(r'[A-Za-z]:[\\/]Users[\\/][^\\/]+[\\/]', caseSensitive: false),
      r'C:\Users\[USER]\',
    );

    // 5. Signed stream CDN token parameters
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'(\?|&)(token|auth|sign|signature|expires)=[^&\s]+', caseSensitive: false),
      (match) => '${match.group(1)}${match.group(2)}=[REDACTED_SIG]',
    );

    return sanitized;
  }

  Map<String, dynamic> _sanitizeMetadata(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    for (final entry in map.entries) {
      if (entry.value is String) {
        result[entry.key] = scrubSensitiveData(entry.value as String);
      } else if (entry.value is Map) {
        result[entry.key] = _sanitizeMetadata(Map<String, dynamic>.from(entry.value as Map));
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  static String? _extractStackTraceSnippet(dynamic stackTrace) {
    if (stackTrace == null) return null;
    final raw = stackTrace.toString();
    if (raw.isEmpty) return null;
    final lines = raw
        .split('\n')
        .where((l) => l.trim().isNotEmpty && !l.contains('ObservabilityService'))
        .take(5)
        .join('\n');
    return scrubSensitiveData(lines);
  }

  String _generateEventId(DiagnosticSubsystem subsystem) {
    final prefix = switch (subsystem) {
      DiagnosticSubsystem.playback => 'PLBK',
      DiagnosticSubsystem.network => 'NET',
      DiagnosticSubsystem.database => 'DB',
      DiagnosticSubsystem.content => 'CONT',
      DiagnosticSubsystem.performance => 'PERF',
      DiagnosticSubsystem.framework => 'FWK',
      DiagnosticSubsystem.platform => 'PLAT',
      DiagnosticSubsystem.lifecycle => 'LIFE',
      DiagnosticSubsystem.security => 'SEC',
    };
    final code = (_rng.nextInt(0xFFFFF) + 0x10000).toRadixString(16).toUpperCase().padLeft(5, '0');
    return 'EVT-$prefix-$code';
  }

  // --- Query & Telemetry API ---

  List<LogEntry> getRecentLogs({
    DiagnosticSubsystem? subsystem,
    LogLevel? minLevel,
    String? correlationId,
    String? searchQuery,
    int limit = 100,
  }) {
    var filtered = _inMemoryEntries.reversed.toList();
    if (subsystem != null) {
      filtered = filtered.where((e) => e.module == subsystem).toList();
    }
    if (minLevel != null) {
      filtered = filtered.where((e) => e.level.isAtLeast(minLevel)).toList();
    }
    if (correlationId != null) {
      filtered = filtered.where((e) => e.correlationId == correlationId).toList();
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      filtered = filtered.where((e) =>
        e.eventName.toLowerCase().contains(q) ||
        (e.errorMessage?.toLowerCase().contains(q) ?? false) ||
        e.component.toLowerCase().contains(q) ||
        (e.errorCode?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    return filtered.take(limit).toList();
  }

  Map<String, dynamic> getSubsystemSummary() {
    final countsBySubsystem = <String, int>{};
    for (final s in DiagnosticSubsystem.values) {
      countsBySubsystem[s.name] = _inMemoryEntries.where((e) => e.module == s).length;
    }

    final countsByLevel = <String, int>{};
    for (final l in LogLevel.values) {
      countsByLevel[l.name] = _inMemoryEntries.where((e) => e.level == l).length;
    }

    return {
      'totalInMemory': _inMemoryEntries.length,
      'sessionId': TraceContext.currentSessionId,
      'platform': _platformName,
      'appVersion': _appVersion,
      'subsystemCounts': countsBySubsystem,
      'levelCounts': countsByLevel,
      'recentErrors': getRecentLogs(minLevel: LogLevel.error, limit: 10)
          .map((e) => e.toJson())
          .toList(),
    };
  }

  void clearLogs() {
    _inMemoryEntries.clear();
  }

  String get platformName => _platformName;
  String get appVersion => _appVersion;
  String get buildNumber => _buildNumber;
}
