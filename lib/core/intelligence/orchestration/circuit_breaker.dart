
/// States of a resilient circuit breaker pattern.
enum CircuitState { closed, open, halfOpen }

/// Circuit breaker guarding against cascading failures to external music APIs.
class CircuitBreaker {
  final String providerName;
  final int failureThreshold;
  final Duration resetTimeout;
  final int halfOpenSuccessThreshold;

  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  int _successCount = 0;
  DateTime? _lastFailureTime;
  DateTime? _stateChangedAt;

  CircuitBreaker({
    required this.providerName,
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(seconds: 30),
    this.halfOpenSuccessThreshold = 2,
  }) {
    _stateChangedAt = DateTime.now();
  }

  CircuitState get state {
    if (_state == CircuitState.open && _lastFailureTime != null) {
      if (DateTime.now().difference(_lastFailureTime!) >= resetTimeout) {
        _state = CircuitState.halfOpen;
        _successCount = 0;
        _stateChangedAt = DateTime.now();
      }
    }
    return _state;
  }

  bool get isExecutionPermitted => state != CircuitState.open;

  void recordSuccess() {
    if (_state == CircuitState.halfOpen) {
      _successCount++;
      if (_successCount >= halfOpenSuccessThreshold) {
        _state = CircuitState.closed;
        _failureCount = 0;
        _stateChangedAt = DateTime.now();
      }
    } else if (_state == CircuitState.closed) {
      _failureCount = 0;
    }
  }

  void recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_state == CircuitState.closed && _failureCount >= failureThreshold) {
      _state = CircuitState.open;
      _stateChangedAt = DateTime.now();
    } else if (_state == CircuitState.halfOpen) {
      _state = CircuitState.open;
      _stateChangedAt = DateTime.now();
    }
  }

  void reset() {
    _state = CircuitState.closed;
    _failureCount = 0;
    _successCount = 0;
    _lastFailureTime = null;
    _stateChangedAt = DateTime.now();
  }

  Map<String, dynamic> getStatus() => {
    'provider': providerName,
    'state': state.name.toUpperCase(),
    'failureCount': _failureCount,
    'lastFailure': _lastFailureTime?.toIso8601String(),
    'stateChangedAt': _stateChangedAt?.toIso8601String(),
  };
}
