import '../models/diagnostic_subsystem.dart';
import '../observability_service.dart';

/// Database and local persistence diagnostic tracker.
class DatabaseDiagnosticsTracker {
  static final DatabaseDiagnosticsTracker instance = DatabaseDiagnosticsTracker._internal();
  factory DatabaseDiagnosticsTracker() => instance;

  final ObservabilityService _obs = ObservabilityService.instance;
  static const int slowQueryThresholdMs = 50;

  DatabaseDiagnosticsTracker._internal();

  /// Records a database read/query operation.
  void trackQuery({
    required String collection, // e.g. "SongHistory", "DownloadedSongs"
    required String queryType,  // e.g. "findRecent", "searchFts", "getAll"
    required int durationMs,
    required int resultCount,
    String? correlationId,
  }) {
    final isSlow = durationMs > slowQueryThresholdMs;
    final meta = <String, dynamic>{
      'collection': collection,
      'queryType': queryType,
      'durationMs': durationMs,
      'resultCount': resultCount,
    };

    if (isSlow) {
      _obs.warn(
        subsystem: DiagnosticSubsystem.database,
        component: 'DatabaseService',
        eventName: 'slow_database_query',
        correlationId: correlationId,
        durationMs: durationMs,
        errorCode: 'WARN-DB-SLOW',
        errorMessage: 'Database query on $collection ($queryType) took ${durationMs}ms',
        metadata: meta,
      );
    } else {
      _obs.debug(
        subsystem: DiagnosticSubsystem.database,
        component: 'DatabaseService',
        eventName: 'database_query_executed',
        correlationId: correlationId,
        durationMs: durationMs,
        metadata: meta,
      );
    }
  }

  /// Records a database write or transaction.
  void trackWrite({
    required String collection,
    required String operation, // "insert", "update", "delete", "batchInsert"
    required int durationMs,
    required int affectedRecords,
    String? correlationId,
  }) {
    final meta = <String, dynamic>{
      'collection': collection,
      'operation': operation,
      'durationMs': durationMs,
      'affectedRecords': affectedRecords,
    };

    _obs.debug(
      subsystem: DiagnosticSubsystem.database,
      component: 'DatabaseService',
      eventName: 'database_write_executed',
      correlationId: correlationId,
      durationMs: durationMs,
      metadata: meta,
    );
  }

  /// Records database operation or migration error.
  void trackError({
    required String collection,
    required String operation,
    required String errorMessage,
    dynamic stackTrace,
    String? correlationId,
  }) {
    _obs.error(
      subsystem: DiagnosticSubsystem.database,
      component: 'DatabaseService',
      eventName: 'database_operation_failed',
      correlationId: correlationId,
      errorCode: 'ERR-DB-TRANSACTION',
      errorMessage: 'Database error in $collection.$operation: $errorMessage',
      stackTrace: stackTrace,
      metadata: {
        'collection': collection,
        'operation': operation,
      },
    );
  }
}
