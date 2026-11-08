import 'dart:async';
import 'dart:math';

/// Token-bucket rate limiter enforcing provider-specific throughput limits
/// without crashing or overwhelming upstream servers.
class TokenBucketRateLimiter {
  final String providerName;
  final double permitsPerSecond;
  final double maxTokens;

  double _availableTokens;
  DateTime _lastRefill;
  final Random _jitter = Random();

  TokenBucketRateLimiter({
    required this.providerName,
    required this.permitsPerSecond,
    double? maxTokens,
  })  : maxTokens = maxTokens ?? permitsPerSecond,
        _availableTokens = maxTokens ?? permitsPerSecond,
        _lastRefill = DateTime.now();

  void _refill() {
    final now = DateTime.now();
    final elapsedSec = now.difference(_lastRefill).inMicroseconds / 1000000.0;
    _availableTokens = min(maxTokens, _availableTokens + (elapsedSec * permitsPerSecond));
    _lastRefill = now;
  }

  /// Asynchronously waits until a permit is available.
  Future<void> acquire({Duration maxWait = const Duration(seconds: 10)}) async {
    final startTime = DateTime.now();

    while (true) {
      _refill();

      if (_availableTokens >= 1.0) {
        _availableTokens -= 1.0;
        return;
      }

      final deficit = 1.0 - _availableTokens;
      final waitMs = (deficit / permitsPerSecond * 1000).ceil();
      final jitterMs = _jitter.nextInt(40); // 0-40ms jitter to prevent thundering herds

      if (DateTime.now().difference(startTime).inMilliseconds + waitMs > maxWait.inMilliseconds) {
        throw TimeoutException('Rate limit permit acquisition timed out for $providerName');
      }

      await Future.delayed(Duration(milliseconds: waitMs + jitterMs));
    }
  }

  /// Non-blocking check if a token can be consumed immediately.
  bool tryAcquire() {
    _refill();
    if (_availableTokens >= 1.0) {
      _availableTokens -= 1.0;
      return true;
    }
    return false;
  }
}
