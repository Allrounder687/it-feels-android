import 'dart:collection';
import '../models/diagnostic_subsystem.dart';
import '../observability_service.dart';

/// Telemetry instrumenter for application performance and latency benchmarks.
class PerformanceTelemetryTracker {
  static final PerformanceTelemetryTracker instance = PerformanceTelemetryTracker._internal();
  factory PerformanceTelemetryTracker() => instance;

  final ObservabilityService _obs = ObservabilityService.instance;
  final Map<String, Queue<int>> _latencySamples = {};
  static const int _maxSamplesPerMetric = 100;

  DateTime? _appStartTime;
  DateTime? _firstRenderTime;

  PerformanceTelemetryTracker._internal();

  /// Records app process launch timestamp.
  void markAppStart() {
    _appStartTime = DateTime.now();
  }

  /// Records first frame rendered.
  void markFirstScreenRendered({String screenName = 'HomeScreen'}) {
    _firstRenderTime = DateTime.now();
    final startupDurationMs = _appStartTime != null
        ? _firstRenderTime!.difference(_appStartTime!).inMilliseconds
        : null;

    _obs.info(
      subsystem: DiagnosticSubsystem.performance,
      component: 'ApplicationLifecycle',
      eventName: 'startup_first_render_completed',
      durationMs: startupDurationMs,
      metadata: {
        'screenName': screenName,
        'startupDurationMs': startupDurationMs,
      },
    );
  }

  /// Records a measurable latency sample (e.g. "search_latency", "artwork_decode", "feed_load").
  void recordMetric(String metricName, int latencyMs, {String? correlationId}) {
    final queue = _latencySamples.putIfAbsent(metricName, () => Queue<int>());
    queue.add(latencyMs);
    if (queue.length > _maxSamplesPerMetric) {
      queue.removeFirst();
    }

    // Emit warning if metric breaches critical SLA
    if (metricName == 'search_latency' && latencyMs > 800) {
      _obs.warn(
        subsystem: DiagnosticSubsystem.performance,
        component: 'SearchEngine',
        eventName: 'slow_search_operation',
        correlationId: correlationId,
        durationMs: latencyMs,
        errorCode: 'WARN-PERF-SEARCH',
        errorMessage: 'Search query exceeded 800ms SLA (${latencyMs}ms)',
      );
    }
  }

  /// Computes p50, p95, and p99 percentiles for a metric.
  Map<String, int> getPercentiles(String metricName) {
    final queue = _latencySamples[metricName];
    if (queue == null || queue.isEmpty) {
      return {'p50': 0, 'p95': 0, 'p99': 0, 'count': 0};
    }

    final sorted = queue.toList()..sort();
    final count = sorted.length;

    final p50 = sorted[(count * 0.50).floor().clamp(0, count - 1)];
    final p95 = sorted[(count * 0.95).floor().clamp(0, count - 1)];
    final p99 = sorted[(count * 0.99).floor().clamp(0, count - 1)];

    return {
      'p50': p50,
      'p95': p95,
      'p99': p99,
      'count': count,
    };
  }

  Map<String, Map<String, int>> getAllMetricSummaries() {
    final result = <String, Map<String, int>>{};
    for (final key in _latencySamples.keys) {
      result[key] = getPercentiles(key);
    }
    return result;
  }
}
