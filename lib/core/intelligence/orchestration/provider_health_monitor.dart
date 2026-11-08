import 'circuit_breaker.dart';

class ProviderHealthStats {
  final String providerName;
  int totalRequests = 0;
  int successfulRequests = 0;
  int failedRequests = 0;
  int rateLimitEvents = 0;
  int totalLatencyMs = 0;
  int lastLatencyMs = 0;
  DateTime? lastSuccessAt;
  DateTime? lastFailureAt;
  String? lastErrorMessage;

  ProviderHealthStats({required this.providerName});

  double get successRate =>
      totalRequests == 0 ? 1.0 : successfulRequests / totalRequests;

  int get averageLatencyMs => successfulRequests == 0
      ? 0
      : (totalLatencyMs / successfulRequests).round();

  Map<String, dynamic> toJson({CircuitState? circuitState}) => {
    'provider': providerName,
    'totalRequests': totalRequests,
    'successfulRequests': successfulRequests,
    'failedRequests': failedRequests,
    'rateLimitEvents': rateLimitEvents,
    'successRate': '${(successRate * 100).toStringAsFixed(1)}%',
    'avgLatencyMs': averageLatencyMs,
    'lastLatencyMs': lastLatencyMs,
    'circuitState': circuitState?.name.toUpperCase() ?? 'CLOSED',
    'lastSuccess': lastSuccessAt?.toIso8601String() ?? 'None',
    'lastFailure': lastFailureAt?.toIso8601String() ?? 'None',
    'lastError': lastErrorMessage ?? 'None',
  };
}

/// Central health and telemetry monitor for all external music providers.
class ProviderHealthMonitor {
  static final ProviderHealthMonitor _instance = ProviderHealthMonitor._internal();
  factory ProviderHealthMonitor() => _instance;
  ProviderHealthMonitor._internal();

  final Map<String, ProviderHealthStats> _stats = {};

  ProviderHealthStats _getOrCreate(String provider) {
    return _stats.putIfAbsent(provider, () => ProviderHealthStats(providerName: provider));
  }

  void recordSuccess(String provider, int latencyMs) {
    final s = _getOrCreate(provider);
    s.totalRequests++;
    s.successfulRequests++;
    s.lastLatencyMs = latencyMs;
    s.totalLatencyMs += latencyMs;
    s.lastSuccessAt = DateTime.now();
  }

  void recordFailure(String provider, {int latencyMs = 0, String? error, bool is429 = false}) {
    final s = _getOrCreate(provider);
    s.totalRequests++;
    s.failedRequests++;
    s.lastLatencyMs = latencyMs;
    if (is429) s.rateLimitEvents++;
    s.lastFailureAt = DateTime.now();
    s.lastErrorMessage = error;
  }

  List<ProviderHealthStats> getAllStats() => _stats.values.toList();

  Map<String, dynamic> getReport(Map<String, CircuitBreaker> circuitBreakers) {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'providers': _stats.map((key, stat) {
        final cb = circuitBreakers[key];
        return MapEntry(key, stat.toJson(circuitState: cb?.state));
      }),
    };
  }
}
