import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/log_level.dart';
import '../observability_service.dart';
import '../storage/rotating_log_file_sink.dart';
import '../trackers/performance_telemetry_tracker.dart';
import '../trackers/network_diagnostics_tracker.dart';

/// Previews and bundles diagnostic logs into structured, exportable formats.
class DiagnosticExportService {
  static final DiagnosticExportService instance = DiagnosticExportService._internal();
  factory DiagnosticExportService() => instance;

  final ObservabilityService _obs = ObservabilityService.instance;

  DiagnosticExportService._internal();

  /// Generates a comprehensive, privacy-scrubbed diagnostic export bundle.
  Future<Map<String, dynamic>> generateExportPayload() async {
    final recentLogs = _obs.getRecentLogs(limit: 150);
    final errorLogs = _obs.getRecentLogs(minLevel: LogLevel.error, limit: 50);
    final perfMetrics = PerformanceTelemetryTracker.instance.getAllMetricSummaries();
    final networkEndpoints = NetworkDiagnosticsTracker.instance.endpointRequestCounts;
    final totalDiskBytes = await RotatingLogFileSink.instance.computeTotalStorageBytes();

    final exportManifest = {
      'metadata': {
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'appVersion': _obs.appVersion,
        'buildNumber': _obs.buildNumber,
        'platform': _obs.platformName,
        'sessionId': _obs.getSubsystemSummary()['sessionId'],
        'logStorageBytesOnDisk': totalDiskBytes,
      },
      'systemSummary': _obs.getSubsystemSummary(),
      'performanceMetrics': perfMetrics,
      'networkSummary': {
        'trackedEndpoints': networkEndpoints,
      },
      'recentErrors': errorLogs.map((e) => e.toJson()).toList(),
      'auditLogs': recentLogs.map((e) => e.toJson()).toList(),
    };

    return exportManifest;
  }

  /// Formats the diagnostic export as a clean, human-readable Markdown summary.
  Future<String> generateReadableMarkdownReport() async {
    final payload = await generateExportPayload();
    final meta = payload['metadata'] as Map<String, dynamic>;
    final perf = payload['performanceMetrics'] as Map<String, dynamic>;
    final errors = payload['recentErrors'] as List<dynamic>;

    final buf = StringBuffer();
    buf.writeln('# IT FEELS MUSIC — DIAGNOSTIC EXPORT SUMMARY');
    buf.writeln('**Generated**: ${meta['exportedAt']}');
    buf.writeln('**Platform**: ${meta['platform']} | **Version**: v${meta['appVersion']} (Build ${meta['buildNumber']})');
    buf.writeln('**Session ID**: `${meta['sessionId']}`');
    buf.writeln('**Disk Footprint**: ${(meta['logStorageBytesOnDisk'] / 1024).toStringAsFixed(1)} KB\n');

    buf.writeln('## 1. Subsystem Health & Latencies');
    if (perf.isEmpty) {
      buf.writeln('No latency telemetry recorded in this session.\n');
    } else {
      buf.writeln('| Metric | p50 (ms) | p95 (ms) | p99 (ms) | Samples |');
      buf.writeln('|---|---|---|---|---|');
      for (final entry in perf.entries) {
        final m = entry.value as Map<String, dynamic>;
        buf.writeln('| ${entry.key} | ${m['p50']}ms | ${m['p95']}ms | ${m['p99']}ms | ${m['count']} |');
      }
      buf.writeln('');
    }

    buf.writeln('## 2. Recent Errors (${errors.length})');
    if (errors.isEmpty) {
      buf.writeln('Zero unhandled errors recorded in this session. Status: Healthy.\n');
    } else {
      for (final err in errors.take(10)) {
        final e = err as Map<String, dynamic>;
        buf.writeln('- **[${e['errorCode'] ?? 'ERR'}]** `${e['module']}:${e['component']}` — ${e['errorMessage']}');
        if (e['stackTrace'] != null) {
          buf.writeln('  ```');
          buf.writeln('  ${e['stackTrace']}');
          buf.writeln('  ```');
        }
      }
      buf.writeln('');
    }

    buf.writeln('## 3. Privacy Redaction Statement');
    buf.writeln('All Bearer tokens, private stream URLs, passwords, email addresses, and personal local filesystem paths have been scrubbed in compliance with Project Obsidian privacy standards.');

    return buf.toString();
  }

  /// Writes export package to the device file system and returns the saved file path.
  Future<String?> writeExportPackageToDisk() async {
    if (kIsWeb) return null;
    try {
      final baseDir = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${baseDir.path}/it_feels_exports');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final jsonFile = File('${exportDir.path}/diagnostics_export_$timestamp.json');
      final mdFile = File('${exportDir.path}/diagnostics_summary_$timestamp.md');

      final payload = await generateExportPayload();
      final markdown = await generateReadableMarkdownReport();

      await jsonFile.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
      await mdFile.writeAsString(markdown);

      return jsonFile.path;
    } catch (e) {
      debugPrint('[DiagnosticExportService] Write error: $e');
      return null;
    }
  }
}
