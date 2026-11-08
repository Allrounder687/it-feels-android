import 'dart:convert';
import 'log_level.dart';
import 'diagnostic_subsystem.dart';

/// Standardized, privacy-conscious structured log record for IT Feels Music.
class LogEntry {
  /// ISO-8601 UTC timestamp of log event emission.
  final DateTime timestamp;

  /// Severity level classification.
  final LogLevel level;

  /// Application semantic version (e.g. "3.9.4").
  final String appVersion;

  /// Platform build number (e.g. "1").
  final String buildNumber;

  /// Host runtime operating system (android, ios, windows, macos, linux, web).
  final String platform;

  /// High-level architectural subsystem.
  final DiagnosticSubsystem module;

  /// Specific Dart class, service, or widget emitting the event.
  final String component;

  /// Canonical, machine-readable event name (e.g. "playback_source_resolved").
  final String eventName;

  /// Unique event occurrence identifier (e.g. "EVT-PLBK-7A3F").
  final String eventId;

  /// Shared trace correlation identifier linking related operations across subsystems.
  final String? correlationId;

  /// App launch session identifier.
  final String sessionId;

  /// Measured operation duration in milliseconds (if applicable).
  final int? operationDurationMs;

  /// Machine-readable error code if operation failed (e.g. "ERR-NET-TIMEOUT").
  final String? errorCode;

  /// Sanitized, human-readable error description.
  final String? errorMessage;

  /// Actionable stack trace snippet (scrubbed of private filesystem paths).
  final String? stackTrace;

  /// Non-sensitive structured key-value context.
  final Map<String, dynamic>? metadata;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.module,
    required this.component,
    required this.eventName,
    required this.eventId,
    this.correlationId,
    required this.sessionId,
    this.operationDurationMs,
    this.errorCode,
    this.errorMessage,
    this.stackTrace,
    this.metadata,
  });

  /// Serializes entry to a structured Map ready for JSON / JSONL output.
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.label,
    'appVersion': appVersion,
    'buildNumber': buildNumber,
    'platform': platform,
    'module': module.name,
    'component': component,
    'eventName': eventName,
    'eventId': eventId,
    if (correlationId != null) 'correlationId': correlationId,
    'sessionId': sessionId,
    if (operationDurationMs != null) 'operationDurationMs': operationDurationMs,
    if (errorCode != null) 'errorCode': errorCode,
    if (errorMessage != null) 'errorMessage': errorMessage,
    if (stackTrace != null) 'stackTrace': stackTrace,
    if (metadata != null && metadata!.isNotEmpty) 'metadata': metadata,
  };

  /// Deserializes a LogEntry from structured JSON.
  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      level: LogLevel.fromString(json['level'] as String?),
      appVersion: json['appVersion'] as String? ?? 'unknown',
      buildNumber: json['buildNumber'] as String? ?? '0',
      platform: json['platform'] as String? ?? 'unknown',
      module: DiagnosticSubsystem.fromString(json['module'] as String?),
      component: json['component'] as String? ?? 'General',
      eventName: json['eventName'] as String? ?? 'unknown_event',
      eventId: json['eventId'] as String? ?? 'EVT-0000',
      correlationId: json['correlationId'] as String?,
      sessionId: json['sessionId'] as String? ?? 'unknown_session',
      operationDurationMs: json['operationDurationMs'] as int?,
      errorCode: json['errorCode'] as String?,
      errorMessage: json['errorMessage'] as String?,
      stackTrace: json['stackTrace'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Single-line compact JSON format suitable for JSONL streaming.
  String toJsonLine() => jsonEncode(toJson());

  /// Readable human-friendly log string for developer console and debugging.
  String toReadableString() {
    final buffer = StringBuffer();
    buffer.write('[${timestamp.toIso8601String()}] ');
    buffer.write('[${level.label.padRight(5)}] ');
    buffer.write('[${module.name.toUpperCase()}:$component] ');
    buffer.write('$eventName: ');
    if (operationDurationMs != null) {
      buffer.write('(${operationDurationMs}ms) ');
    }
    if (errorMessage != null) {
      buffer.write('FAILED [$errorCode]: $errorMessage');
    } else {
      buffer.write('OK');
    }
    if (correlationId != null) {
      buffer.write(' [corr: $correlationId]');
    }
    return buffer.toString();
  }
}
