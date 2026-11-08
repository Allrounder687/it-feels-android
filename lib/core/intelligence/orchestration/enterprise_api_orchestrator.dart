import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'circuit_breaker.dart';
import 'rate_limiter.dart';
import 'tiered_cache_manager.dart';
import 'provider_health_monitor.dart';

/// Central Enterprise API Orchestrator that coordinates all external provider requests,
/// enforcing token-bucket rate limiting, circuit breaker protection, layered caching,
/// request deduplication, SSRF defense, and edge proxy fallbacks.
class EnterpriseApiOrchestrator {
  static const String _edgeProxyBase = 'https://it-feels-proxy.cleverfox687.workers.dev';
  static final EnterpriseApiOrchestrator _instance = EnterpriseApiOrchestrator._internal();
  factory EnterpriseApiOrchestrator() => _instance;

  final http.Client _client = http.Client();
  final TieredCacheManager cache = TieredCacheManager();
  final ProviderHealthMonitor healthMonitor = ProviderHealthMonitor();
  final Random _random = Random();

  final Map<String, CircuitBreaker> _circuitBreakers = {};
  final Map<String, TokenBucketRateLimiter> _rateLimiters = {};
  final Map<String, Future<dynamic>> _inFlightRequests = {};

  EnterpriseApiOrchestrator._internal() {
    _registerProvider('saavn', permitsPerSec: 10.0, failureThreshold: 6);
    _registerProvider('musicbrainz', permitsPerSec: 1.0, failureThreshold: 4); // Strict MB 1 req/s rule
    _registerProvider('wikidata', permitsPerSec: 4.0, failureThreshold: 5);
    _registerProvider('lastfm', permitsPerSec: 5.0, failureThreshold: 5);
    _registerProvider('listenbrainz', permitsPerSec: 3.0, failureThreshold: 5);
    _registerProvider('coverartarchive', permitsPerSec: 5.0, failureThreshold: 5);
    _registerProvider('lrclib', permitsPerSec: 5.0, failureThreshold: 5);
  }

  void _registerProvider(String name, {required double permitsPerSec, int failureThreshold = 5}) {
    _circuitBreakers[name] = CircuitBreaker(
      providerName: name,
      failureThreshold: failureThreshold,
      resetTimeout: const Duration(seconds: 30),
    );
    _rateLimiters[name] = TokenBucketRateLimiter(
      providerName: name,
      permitsPerSecond: permitsPerSec,
    );
  }

  CircuitBreaker getCircuitBreaker(String provider) {
    return _circuitBreakers.putIfAbsent(
      provider,
      () => CircuitBreaker(providerName: provider),
    );
  }

  /// Validates URL to guard against SSRF attacks targeting internal networks.
  bool isSafeExternalUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) return false;
      final host = uri.host.toLowerCase();

      // Blacklist private/loopback addresses
      if (host == 'localhost' ||
          host.startsWith('127.') ||
          host.startsWith('10.') ||
          host.startsWith('192.168.') ||
          host == '0.0.0.0' ||
          host.endsWith('.local') ||
          host.endsWith('.internal')) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Executes an HTTP GET request through the orchestration pipeline.
  Future<Map<String, dynamic>?> getJson({
    required String provider,
    required String url,
    Map<String, String>? headers,
    CacheContentType? cacheType,
    Duration? customTtl,
    bool useProxyFallback = true,
  }) async {
    if (!isSafeExternalUrl(url)) {
      healthMonitor.recordFailure(provider, error: 'SSRF blocked unsafe URL: $url');
      return null;
    }

    final cacheKey = '$provider:${url.hashCode}';

    // 1. Layered Cache Check
    if (cacheType != null) {
      final cached = await cache.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) return cached;
    }

    // 2. Request Deduplication
    if (_inFlightRequests.containsKey(cacheKey)) {
      return await _inFlightRequests[cacheKey] as Map<String, dynamic>?;
    }

    final future = _executeGetWithResilience(
      provider: provider,
      url: url,
      headers: headers,
      useProxyFallback: useProxyFallback,
    );

    _inFlightRequests[cacheKey] = future;

    try {
      final result = await future;
      if (result != null && cacheType != null) {
        await cache.put(cacheKey, result, type: cacheType, customTtl: customTtl);
      }
      return result;
    } finally {
      _inFlightRequests.remove(cacheKey);
    }
  }

  Future<Map<String, dynamic>?> _executeGetWithResilience({
    required String provider,
    required String url,
    Map<String, String>? headers,
    bool useProxyFallback = true,
  }) async {
    final cb = getCircuitBreaker(provider);
    if (!cb.isExecutionPermitted) {
      healthMonitor.recordFailure(provider, error: 'Circuit Breaker OPEN - failing fast');
      return null;
    }

    final limiter = _rateLimiters[provider];
    if (limiter != null) {
      try {
        await limiter.acquire(maxWait: const Duration(seconds: 8));
      } catch (e) {
        healthMonitor.recordFailure(provider, error: 'Rate limit timeout: $e');
        return null;
      }
    }

    final effectiveHeaders = {
      'User-Agent': 'ITFeelsMusic/3.7.0 (contact@itfeels.app)',
      'Accept': 'application/json',
      ...?headers,
    };

    int attempts = 0;
    const maxAttempts = 2;

    while (attempts < maxAttempts) {
      attempts++;
      final stopwatch = Stopwatch()..start();

      try {
        final uri = Uri.parse(url);
        final response = await _client.get(uri, headers: effectiveHeaders).timeout(const Duration(seconds: 9));
        stopwatch.stop();

        if (response.statusCode >= 200 && response.statusCode < 300) {
          cb.recordSuccess();
          healthMonitor.recordSuccess(provider, stopwatch.elapsedMilliseconds);
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map<String, dynamic>) {
            return decoded;
          } else if (decoded is List) {
            return {'data': decoded};
          }
          return null;
        } else if (response.statusCode == 429) {
          // Rate limited
          healthMonitor.recordFailure(provider, latencyMs: stopwatch.elapsedMilliseconds, error: 'HTTP 429 Rate Limited', is429: true);
          final retryAfterSec = int.tryParse(response.headers['retry-after'] ?? '2') ?? 2;
          await Future.delayed(Duration(seconds: min(5, retryAfterSec)));
          continue;
        } else {
          healthMonitor.recordFailure(provider, latencyMs: stopwatch.elapsedMilliseconds, error: 'HTTP ${response.statusCode}');
        }
      } catch (e) {
        stopwatch.stop();
        healthMonitor.recordFailure(provider, latencyMs: stopwatch.elapsedMilliseconds, error: e.toString());

        // On network/reset error, try Cloudflare proxy fallback once
        if (useProxyFallback && attempts == 1) {
          final proxyUrl = '$_edgeProxyBase/api/v1/image-proxy?url=${Uri.encodeComponent(url)}';
          try {
            final proxyResp = await _client.get(Uri.parse(proxyUrl), headers: effectiveHeaders).timeout(const Duration(seconds: 10));
            if (proxyResp.statusCode == 200) {
              cb.recordSuccess();
              healthMonitor.recordSuccess(provider, stopwatch.elapsedMilliseconds);
              final decoded = jsonDecode(utf8.decode(proxyResp.bodyBytes));
              if (decoded is Map<String, dynamic>) return decoded;
              if (decoded is List) return {'data': decoded};
            }
          } catch (_) {}
        }

        // Exponential backoff with jitter
        final backoffMs = (300 * pow(2, attempts)) + _random.nextInt(150);
        await Future.delayed(Duration(milliseconds: backoffMs.toInt()));
      }
    }

    cb.recordFailure();
    return null;
  }

  /// Returns consolidated status report for diagnostics sheet.
  Map<String, dynamic> getDiagnosticReport() {
    return healthMonitor.getReport(_circuitBreakers);
  }
}
