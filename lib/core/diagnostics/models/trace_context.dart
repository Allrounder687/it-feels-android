import 'dart:math';

/// Immutable context tracking an operation across multiple subsystems.
class TraceContext {
  /// Root trace identifier for end-to-end operation tracing.
  final String traceId;

  /// Correlation ID linking related operations (e.g. user taps play -> network -> audio).
  final String correlationId;

  /// Session ID representing the current application execution lifecycle.
  final String sessionId;

  /// Current span identifier for localized sub-operations.
  final String spanId;

  /// Parent span identifier when nested.
  final String? parentSpanId;

  /// Wall-clock time when this trace context was initiated.
  final DateTime startTime;

  static final Random _rng = Random();
  static String? _globalSessionId;

  /// Returns the persistent session identifier for the current app execution.
  static String get currentSessionId {
    _globalSessionId ??= _generateHex(8);
    return _globalSessionId!;
  }

  const TraceContext({
    required this.traceId,
    required this.correlationId,
    required this.sessionId,
    required this.spanId,
    this.parentSpanId,
    required this.startTime,
  });

  /// Factory creating a fresh trace context with auto-generated identifiers.
  factory TraceContext.create({
    String? correlationId,
    String? prefix,
  }) {
    final now = DateTime.now();
    final trace = '${prefix != null ? '$prefix-' : ''}TRC-${_generateHex(6)}';
    final corr = correlationId ?? 'COR-${_generateHex(6)}';
    final span = 'SPN-${_generateHex(4)}';

    return TraceContext(
      traceId: trace,
      correlationId: corr,
      sessionId: currentSessionId,
      spanId: span,
      startTime: now,
    );
  }

  /// Creates a child span nested within the current trace.
  TraceContext createChildSpan([String? subOperation]) {
    return TraceContext(
      traceId: traceId,
      correlationId: correlationId,
      sessionId: sessionId,
      spanId: 'SPN-${subOperation != null ? '$subOperation-' : ''}${_generateHex(4)}',
      parentSpanId: spanId,
      startTime: DateTime.now(),
    );
  }

  /// Calculates elapsed milliseconds from trace initiation to now.
  int get elapsedMs => DateTime.now().difference(startTime).inMilliseconds;

  static String _generateHex(int length) {
    const chars = '0123456789ABCDEF';
    return List.generate(length, (_) => chars[_rng.nextInt(chars.length)]).join();
  }

  Map<String, dynamic> toJson() => {
    'traceId': traceId,
    'correlationId': correlationId,
    'sessionId': sessionId,
    'spanId': spanId,
    'parentSpanId': parentSpanId,
    'startTime': startTime.toIso8601String(),
    'elapsedMs': elapsedMs,
  };
}
