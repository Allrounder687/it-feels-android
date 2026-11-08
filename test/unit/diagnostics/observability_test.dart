import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/core/diagnostics/models/log_level.dart';
import 'package:it_feels_music/core/diagnostics/models/diagnostic_subsystem.dart';
import 'package:it_feels_music/core/diagnostics/models/log_entry.dart';
import 'package:it_feels_music/core/diagnostics/models/trace_context.dart';
import 'package:it_feels_music/core/diagnostics/observability_service.dart';
import 'package:it_feels_music/core/diagnostics/trackers/playback_diagnostics_tracker.dart';
import 'package:it_feels_music/core/diagnostics/trackers/network_diagnostics_tracker.dart';
import 'package:it_feels_music/core/diagnostics/trackers/database_diagnostics_tracker.dart';
import 'package:it_feels_music/core/diagnostics/trackers/performance_telemetry_tracker.dart';
import 'package:it_feels_music/core/diagnostics/export/diagnostic_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Structured Logging & Schema Tests', () {
    test('LogEntry serializes and deserializes cleanly with all required fields', () {
      final now = DateTime.now().toUtc();
      final entry = LogEntry(
        timestamp: now,
        level: LogLevel.error,
        appVersion: '3.9.4',
        buildNumber: '1',
        platform: 'windows',
        module: DiagnosticSubsystem.playback,
        component: 'AudioPlayerHandler',
        eventName: 'playback_error',
        eventId: 'EVT-PLBK-12345',
        correlationId: 'COR-TEST-99',
        sessionId: 'SES-ABCDEF',
        operationDurationMs: 42,
        errorCode: 'ERR-DEC-CODEC',
        errorMessage: 'Decoder failed to negotiate stream format',
        stackTrace: 'at AudioPlayerHandler.play (audio_player_handler.dart:340)',
        metadata: {'streamBitrate': 320},
      );

      final jsonMap = entry.toJson();
      expect(jsonMap['level'], 'ERROR');
      expect(jsonMap['module'], 'playback');
      expect(jsonMap['eventName'], 'playback_error');
      expect(jsonMap['correlationId'], 'COR-TEST-99');
      expect(jsonMap['operationDurationMs'], 42);

      final deserialized = LogEntry.fromJson(jsonMap);
      expect(deserialized.level, LogLevel.error);
      expect(deserialized.module, DiagnosticSubsystem.playback);
      expect(deserialized.eventId, 'EVT-PLBK-12345');
      expect(deserialized.errorCode, 'ERR-DEC-CODEC');
      expect(deserialized.metadata?['streamBitrate'], 320);

      final jsonLine = entry.toJsonLine();
      expect(jsonLine.contains('"level":"ERROR"'), isTrue);
      expect(jsonLine.contains('"component":"AudioPlayerHandler"'), isTrue);
    });

    test('LogLevel parses strings and accurately compares severity order', () {
      expect(LogLevel.trace.isAtLeast(LogLevel.trace), isTrue);
      expect(LogLevel.error.isAtLeast(LogLevel.warn), isTrue);
      expect(LogLevel.warn.isAtLeast(LogLevel.error), isFalse);
      expect(LogLevel.fatal.isAtLeast(LogLevel.info), isTrue);

      expect(LogLevel.fromString('FATAL'), LogLevel.fatal);
      expect(LogLevel.fromString('error'), LogLevel.error);
      expect(LogLevel.fromString('invalid_level'), LogLevel.info);
    });
  });

  group('Privacy Redaction & Sensitive Data Scrubbing Tests', () {
    test('Redacts Bearer authorization tokens from messages and metadata', () {
      const raw = 'Failed query with Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xyz123';
      final sanitized = ObservabilityService.scrubSensitiveData(raw);

      expect(sanitized.contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'), isFalse);
      expect(sanitized, contains('Bearer [REDACTED_TOKEN]'));
    });

    test('Redacts user email addresses from error logs', () {
      const raw = 'User listener.john.doe@example.com experienced playback failure';
      final sanitized = ObservabilityService.scrubSensitiveData(raw);

      expect(sanitized.contains('listener.john.doe@example.com'), isFalse);
      expect(sanitized, contains('[REDACTED_EMAIL]'));
    });

    test('Redacts personal Windows user directory paths', () {
      const raw = r'File not found at C:\Users\JohnDoeSecret\AppData\Local\it_feels_music\cache\song.mp3';
      final sanitized = ObservabilityService.scrubSensitiveData(raw);

      expect(sanitized.contains('JohnDoeSecret'), isFalse);
      expect(sanitized, contains(r'C:\Users\[USER]\AppData'));
    });

    test('Redacts signed CDN token query parameters from streaming URLs', () {
      const raw = 'https://c.saavncdn.com/123/stream.mp4?token=secretTokenValue123&expires=999999999';
      final sanitized = ObservabilityService.scrubSensitiveData(raw);

      expect(sanitized.contains('secretTokenValue123'), isFalse);
      expect(sanitized, contains('token=[REDACTED_SIG]'));
    });
  });

  group('Correlation ID & Event Tracing Tests', () {
    test('TraceContext generates unique traceId, correlationId and child spans', () {
      final rootTrace = TraceContext.create(prefix: 'PLBK');
      expect(rootTrace.traceId.startsWith('PLBK-TRC-'), isTrue);
      expect(rootTrace.correlationId.startsWith('COR-'), isTrue);
      expect(rootTrace.sessionId, isNotEmpty);

      final childSpan = rootTrace.createChildSpan('resolve');
      expect(childSpan.traceId, rootTrace.traceId);
      expect(childSpan.correlationId, rootTrace.correlationId);
      expect(childSpan.parentSpanId, rootTrace.spanId);
      expect(childSpan.spanId.contains('resolve'), isTrue);
    });

    test('PlaybackDiagnosticsTracker emits linked trace through entire lifecycle', () {
      final tracker = PlaybackDiagnosticsTracker.instance;
      final obs = ObservabilityService.instance;
      obs.clearLogs();

      // 1. Play requested
      final trace = tracker.trackPlayRequested(
        songId: 'song_101',
        songTitle: 'Tum Hi Ho',
        sourceOrigin: 'daily_mix_1',
      );
      expect(tracker.activeTrackId, 'song_101');
      expect(tracker.currentCorrelationId, trace.correlationId);

      // 2. Source resolution
      tracker.trackSourceResolutionStarted(provider: 'jiosaavn');
      tracker.trackSourceResolved(
        provider: 'jiosaavn',
        streamHost: 'c.saavncdn.com',
        bitrateKbps: 320,
      );

      // 3. Player buffering & first audio
      tracker.trackBufferingStarted();
      tracker.trackBufferingCompleted(isFirstAudio: true);

      // 4. Seek
      tracker.trackSeekStarted(targetPosition: const Duration(seconds: 45));
      tracker.trackSeekCompleted(resultingPosition: const Duration(seconds: 45));

      final logs = obs.getRecentLogs(correlationId: trace.correlationId);
      expect(logs.length, greaterThanOrEqualTo(4));
      expect(logs.any((l) => l.eventName == 'playback_requested'), isTrue);
      expect(logs.any((l) => l.eventName == 'source_resolved'), isTrue);
      expect(logs.any((l) => l.eventName == 'first_audio_rendered'), isTrue);
    });
  });

  group('Network & Database Diagnostics Tests', () {
    test('NetworkDiagnosticsTracker sanitizes URLs and flags HTTP 429 throttling', () {
      final tracker = NetworkDiagnosticsTracker.instance;
      final obs = ObservabilityService.instance;
      obs.clearLogs();

      // Test endpoint template sanitization
      final sanitized = NetworkDiagnosticsTracker.sanitizeEndpoint(
        'https://api.jiosaavn.com/v1/songs/9876543210/lyrics',
      );
      expect(sanitized, 'api.jiosaavn.com/v1/songs/:num/lyrics');

      // Test 429 tracking
      tracker.trackRequest(
        provider: 'jiosaavn',
        method: 'GET',
        rawUrl: 'https://api.jiosaavn.com/v1/search?query=arijit',
        statusCode: 429,
        durationMs: 350,
      );

      final warnLogs = obs.getRecentLogs(minLevel: LogLevel.warn);
      expect(warnLogs.any((l) => l.errorCode == 'ERR-NET-429'), isTrue);
    });

    test('DatabaseDiagnosticsTracker records query latency and flags slow queries', () {
      final tracker = DatabaseDiagnosticsTracker.instance;
      final obs = ObservabilityService.instance;
      obs.clearLogs();

      // Fast query
      tracker.trackQuery(
        collection: 'SongHistory',
        queryType: 'findRecent',
        durationMs: 8,
        resultCount: 15,
      );

      // Slow query (>50ms)
      tracker.trackQuery(
        collection: 'DownloadedSongs',
        queryType: 'deepScan',
        durationMs: 95,
        resultCount: 450,
      );

      final slowWarnings = obs.getRecentLogs(minLevel: LogLevel.warn);
      expect(slowWarnings.any((l) => l.errorCode == 'WARN-DB-SLOW'), isTrue);
    });
  });

  group('Performance Telemetry & Diagnostic Export Tests', () {
    test('PerformanceTelemetryTracker calculates accurate p50, p95, p99 percentiles', () {
      final tracker = PerformanceTelemetryTracker.instance;

      for (int i = 1; i <= 100; i++) {
        tracker.recordMetric('search_latency', i * 5); // 5ms to 500ms
      }

      final stats = tracker.getPercentiles('search_latency');
      expect(stats['count'], 100);
      expect(stats['p50'], inInclusiveRange(240, 260));
      expect(stats['p95'], inInclusiveRange(470, 485));
      expect(stats['p99'], inInclusiveRange(490, 500));
    });

    test('DiagnosticExportService generates complete structured export package', () async {
      final exporter = DiagnosticExportService.instance;
      final payload = await exporter.generateExportPayload();

      expect(payload.containsKey('metadata'), isTrue);
      expect(payload.containsKey('systemSummary'), isTrue);
      expect(payload.containsKey('performanceMetrics'), isTrue);
      expect(payload.containsKey('auditLogs'), isTrue);

      final markdown = await exporter.generateReadableMarkdownReport();
      expect(markdown, contains('# IT FEELS MUSIC — DIAGNOSTIC EXPORT SUMMARY'));
      expect(markdown, contains('## 1. Subsystem Health & Latencies'));
      expect(markdown, contains('Privacy Redaction Statement'));
    });

    test('ObservabilityService isolates errors and prevents crashing on null input', () {
      final obs = ObservabilityService.instance;
      // Must not throw even with anomalous/extreme inputs
      expect(() {
        obs.error(
          subsystem: DiagnosticSubsystem.framework,
          component: 'StressTest',
          eventName: 'stress_event',
          errorMessage: '',
          stackTrace: null,
          metadata: null,
        );
      }, returnsNormally);
    });
  });
}
