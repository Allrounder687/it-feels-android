import '../models/diagnostic_subsystem.dart';
import '../observability_service.dart';

/// Network failure root causes.
enum NetworkFailureCategory {
  dnsResolution,
  connectionTimeout,
  handshakeFailure,
  http4xxClientError,
  http5xxServerError,
  rateLimited429,
  parsingException,
  offlineNoRoute,
}

/// Dedicated tracker for network integrations and HTTP/REST operations.
class NetworkDiagnosticsTracker {
  static final NetworkDiagnosticsTracker instance = NetworkDiagnosticsTracker._internal();
  factory NetworkDiagnosticsTracker() => instance;

  final ObservabilityService _obs = ObservabilityService.instance;
  final Map<String, int> _endpointRequestCounts = {};

  NetworkDiagnosticsTracker._internal();

  /// Sanitizes raw URLs into generic endpoint templates (e.g. `/api/songs/:id`).
  static String sanitizeEndpoint(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl);
      final host = uri.host;
      final pathSegments = uri.pathSegments;

      final sanitizedSegments = pathSegments.map((seg) {
        if (RegExp(r'^[0-9]+$').hasMatch(seg)) return ':num';
        if (RegExp(r'^[a-f0-9-]{32,36}$', caseSensitive: false).hasMatch(seg)) return ':uuid';
        return seg;
      }).join('/');

      return '$host/$sanitizedSegments';
    } catch (_) {
      return 'invalid_uri';
    }
  }

  /// Records an outbound network request execution and outcome.
  void trackRequest({
    required String provider, // "jiosaavn", "cloudflare", "musicbrainz", "firebase"
    required String method,   // "GET", "POST", etc.
    required String rawUrl,
    required int statusCode,
    required int durationMs,
    int? responseSizeBytes,
    int retryCount = 0,
    bool isCacheHit = false,
    String? correlationId,
  }) {
    final sanitizedEndpoint = sanitizeEndpoint(rawUrl);

    // Track request frequency for redundant call detection
    _endpointRequestCounts[sanitizedEndpoint] = (_endpointRequestCounts[sanitizedEndpoint] ?? 0) + 1;
    final totalCalls = _endpointRequestCounts[sanitizedEndpoint]!;

    final isError = statusCode >= 400;
    final isSlow = durationMs > 1200;

    final meta = <String, dynamic>{
      'provider': provider,
      'method': method,
      'endpoint': sanitizedEndpoint,
      'statusCode': statusCode,
      'durationMs': durationMs,
      'responseSizeBytes': responseSizeBytes ?? 0,
      'retryCount': retryCount,
      'isCacheHit': isCacheHit,
      'cumulativeCalls': totalCalls,
    };

    if (statusCode == 429) {
      _obs.warn(
        subsystem: DiagnosticSubsystem.network,
        component: 'EnterpriseApiOrchestrator',
        eventName: 'rate_limit_throttled',
        correlationId: correlationId,
        durationMs: durationMs,
        errorCode: 'ERR-NET-429',
        errorMessage: 'Rate limit (429) received from $provider at $sanitizedEndpoint',
        metadata: meta,
      );
    } else if (isError) {
      _obs.error(
        subsystem: DiagnosticSubsystem.network,
        component: 'EnterpriseApiOrchestrator',
        eventName: 'network_request_failed',
        correlationId: correlationId,
        durationMs: durationMs,
        errorCode: 'ERR-HTTP-$statusCode',
        errorMessage: 'HTTP $statusCode on $provider ($sanitizedEndpoint)',
        metadata: meta,
      );
    } else if (isSlow) {
      _obs.warn(
        subsystem: DiagnosticSubsystem.network,
        component: 'EnterpriseApiOrchestrator',
        eventName: 'slow_network_request',
        correlationId: correlationId,
        durationMs: durationMs,
        errorCode: 'WARN-NET-LATENCY',
        errorMessage: 'Slow network call (${durationMs}ms) to $provider',
        metadata: meta,
      );
    } else {
      _obs.debug(
        subsystem: DiagnosticSubsystem.network,
        component: 'EnterpriseApiOrchestrator',
        eventName: 'network_request_completed',
        correlationId: correlationId,
        durationMs: durationMs,
        metadata: meta,
      );
    }
  }

  /// Records network failure when no HTTP status was received (timeout, DNS, socket).
  void trackNetworkException({
    required String provider,
    required String rawUrl,
    required NetworkFailureCategory category,
    required String errorMessage,
    dynamic stackTrace,
    String? correlationId,
  }) {
    final sanitizedEndpoint = sanitizeEndpoint(rawUrl);

    _obs.error(
      subsystem: DiagnosticSubsystem.network,
      component: 'EnterpriseApiOrchestrator',
      eventName: 'network_connection_exception',
      correlationId: correlationId,
      errorCode: 'ERR-NET-${category.name.toUpperCase()}',
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      metadata: {
        'provider': provider,
        'endpoint': sanitizedEndpoint,
        'category': category.name,
      },
    );
  }

  Map<String, int> get endpointRequestCounts => Map.unmodifiable(_endpointRequestCounts);
}
