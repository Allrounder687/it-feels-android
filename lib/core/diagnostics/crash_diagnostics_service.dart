import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Categories of tracked production events and failure modes.
enum DiagnosticCategory {
  playback,
  network,
  database,
  framework,
  platform,
  lifecycle,
}

/// Severity classification for diagnostic entries.
enum DiagnosticSeverity {
  info,
  warning,
  error,
  fatal,
}

/// Privacy-conscious diagnostic record capturing actionable error context
/// with strict redaction of authentication tokens, passwords, and PII.
class DiagnosticRecord {
  final String id;
  final DiagnosticCategory category;
  final DiagnosticSeverity severity;
  final String message;
  final String? stackTraceSnippet;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const DiagnosticRecord({
    required this.id,
    required this.category,
    required this.severity,
    required this.message,
    this.stackTraceSnippet,
    required this.timestamp,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category.name,
    'severity': severity.name,
    'message': message,
    'stackTraceSnippet': stackTraceSnippet,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };

  factory DiagnosticRecord.fromJson(Map<String, dynamic> json) => DiagnosticRecord(
    id: json['id'] as String? ?? 'ERR-UNKNOWN',
    category: DiagnosticCategory.values.firstWhere(
      (c) => c.name == json['category'],
      orElse: () => DiagnosticCategory.framework,
    ),
    severity: DiagnosticSeverity.values.firstWhere(
      (s) => s.name == json['severity'],
      orElse: () => DiagnosticSeverity.error,
    ),
    message: json['message'] as String? ?? '',
    stackTraceSnippet: json['stackTraceSnippet'] as String?,
    timestamp: json['timestamp'] != null
        ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
        : DateTime.now(),
    metadata: json['metadata'] as Map<String, dynamic>?,
  );
}

/// Centralized, privacy-conscious Crash & Diagnostics Architecture.
///
/// Features:
/// 1. Automated secret/token/PII scrubbing using multi-pattern regex redaction.
/// 2. Bounded circular in-memory buffer (150 events) preventing memory bloat.
/// 3. Persistent persistent snapshot of critical/fatal errors across app crashes.
/// 4. Generates unique, human-readable reproduction identifiers (e.g. ERR-PLBK-7F2A).
/// 5. Zero network telemetry leaks of user credentials.
class CrashDiagnosticsService {
  static final CrashDiagnosticsService instance = CrashDiagnosticsService._internal();
  factory CrashDiagnosticsService() => instance;

  static const int _maxInMemoryRecords = 150;
  static const int _maxPersistedRecords = 30;
  static const String _persistedDiagnosticsKey = 'obsidian_crash_diagnostics_v1';

  final List<DiagnosticRecord> _records = [];
  final Random _random = Random();
  bool _isInitialized = false;

  CrashDiagnosticsService._internal();

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await _loadPersistedRecords();
  }

  /// Scrubs sensitive credentials, tokens, bearer authorizations, passwords, and emails.
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

    return sanitized;
  }

  /// Generates a structured, deterministic reproduction identifier.
  String _generateErrorId(DiagnosticCategory category) {
    final prefix = switch (category) {
      DiagnosticCategory.playback => 'PLBK',
      DiagnosticCategory.network => 'NET',
      DiagnosticCategory.database => 'DB',
      DiagnosticCategory.framework => 'FWK',
      DiagnosticCategory.platform => 'PLAT',
      DiagnosticCategory.lifecycle => 'LIFE',
    };
    final code = (_random.nextInt(0xFFFFF) + 0x10000).toRadixString(16).toUpperCase().padLeft(5, '0');
    return 'ERR-$prefix-$code';
  }

  /// Extracts the top 5 most actionable lines from a stack trace.
  static String? _extractStackTraceSnippet(dynamic stackTrace) {
    if (stackTrace == null) return null;
    final raw = stackTrace.toString();
    if (raw.isEmpty) return null;
    final lines = raw
        .split('\n')
        .where((l) => l.trim().isNotEmpty && !l.contains('CrashDiagnosticsService'))
        .take(5)
        .join('\n');
    return scrubSensitiveData(lines);
  }

  /// Records a structured diagnostic entry into the buffer.
  DiagnosticRecord record({
    required DiagnosticCategory category,
    required DiagnosticSeverity severity,
    required String message,
    dynamic stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    final recordId = _generateErrorId(category);
    final sanitizedMessage = scrubSensitiveData(message);
    final stackSnippet = _extractStackTraceSnippet(stackTrace);

    final record = DiagnosticRecord(
      id: recordId,
      category: category,
      severity: severity,
      message: sanitizedMessage,
      stackTraceSnippet: stackSnippet,
      timestamp: DateTime.now(),
      metadata: metadata != null ? _sanitizeMetadata(metadata) : null,
    );

    _records.add(record);
    if (_records.length > _maxInMemoryRecords) {
      _records.removeAt(0);
    }

    if (severity == DiagnosticSeverity.error || severity == DiagnosticSeverity.fatal) {
      debugPrint('[CrashDiagnostics] ${record.id} [${category.name.toUpperCase()}]: $sanitizedMessage');
      _persistRecord(record);
    }

    return record;
  }

  Map<String, dynamic> _sanitizeMetadata(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    for (final entry in map.entries) {
      if (entry.value is String) {
        result[entry.key] = scrubSensitiveData(entry.value as String);
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  // --- Specialized Convenience Loggers ---

  DiagnosticRecord recordPlaybackFailure({
    required String songId,
    required String songTitle,
    required String reason,
    dynamic stackTrace,
    int? retryAttempt,
  }) {
    return record(
      category: DiagnosticCategory.playback,
      severity: DiagnosticSeverity.error,
      message: 'Playback failure for "$songTitle" ($songId): $reason',
      stackTrace: stackTrace,
      metadata: {
        'songId': songId,
        'retryAttempt': retryAttempt ?? 0,
      },
    );
  }

  DiagnosticRecord recordNetworkFailure({
    required String provider,
    required String endpoint,
    required String error,
    int? statusCode,
  }) {
    return record(
      category: DiagnosticCategory.network,
      severity: (statusCode != null && statusCode >= 500)
          ? DiagnosticSeverity.error
          : DiagnosticSeverity.warning,
      message: 'Network failure on $provider ($endpoint): $error',
      metadata: {
        'provider': provider,
        'statusCode': statusCode,
      },
    );
  }

  DiagnosticRecord recordDatabaseError({
    required String operation,
    required String error,
    dynamic stackTrace,
  }) {
    return record(
      category: DiagnosticCategory.database,
      severity: DiagnosticSeverity.error,
      message: 'Database operation "$operation" failed: $error',
      stackTrace: stackTrace,
    );
  }

  DiagnosticRecord recordFrameworkError(
    FlutterErrorDetails details,
  ) {
    return record(
      category: DiagnosticCategory.framework,
      severity: DiagnosticSeverity.error,
      message: details.exceptionAsString(),
      stackTrace: details.stack,
      metadata: {
        'library': details.library ?? 'flutter',
        'context': details.context?.toDescription(),
      },
    );
  }

  // --- Querying & Reports ---

  List<DiagnosticRecord> getRecentRecords({
    DiagnosticCategory? category,
    DiagnosticSeverity? minSeverity,
    int limit = 50,
  }) {
    var filtered = _records.reversed.toList();
    if (category != null) {
      filtered = filtered.where((r) => r.category == category).toList();
    }
    if (minSeverity != null) {
      filtered = filtered.where((r) => r.severity.index >= minSeverity.index).toList();
    }
    return filtered.take(limit).toList();
  }

  Map<String, dynamic> generateDiagnosticReport() {
    final now = DateTime.now();
    final countsByCategory = <String, int>{};
    for (final c in DiagnosticCategory.values) {
      countsByCategory[c.name] = _records.where((r) => r.category == c).length;
    }

    final countsBySeverity = <String, int>{};
    for (final s in DiagnosticSeverity.values) {
      countsBySeverity[s.name] = _records.where((r) => r.severity == s).length;
    }

    return {
      'generatedAt': now.toIso8601String(),
      'totalRecords': _records.length,
      'categoryBreakdown': countsByCategory,
      'severityBreakdown': countsBySeverity,
      'recentErrors': getRecentRecords(minSeverity: DiagnosticSeverity.error, limit: 10)
          .map((r) => r.toJson())
          .toList(),
    };
  }

  void clearLogs() {
    _records.clear();
  }

  // --- Persistence ---

  Future<void> _persistRecord(DiagnosticRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_persistedDiagnosticsKey) ?? [];
      final updated = List<String>.from(raw)..add(jsonEncode(record.toJson()));
      if (updated.length > _maxPersistedRecords) {
        updated.removeRange(0, updated.length - _maxPersistedRecords);
      }
      await prefs.setStringList(_persistedDiagnosticsKey, updated);
    } catch (_) {}
  }

  Future<void> _loadPersistedRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_persistedDiagnosticsKey) ?? [];
      for (final item in raw) {
        try {
          final decoded = jsonDecode(item) as Map<String, dynamic>;
          _records.add(DiagnosticRecord.fromJson(decoded));
        } catch (_) {}
      }
    } catch (_) {}
  }
}
