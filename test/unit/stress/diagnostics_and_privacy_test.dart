import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/core/diagnostics/crash_diagnostics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CrashDiagnosticsService.instance.clearLogs();
  });

  group('CrashDiagnosticsService Privacy Scrubbing', () {
    test('redacts Bearer tokens in strings', () {
      const raw = 'Request failed with header Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xyz';
      final scrubbed = CrashDiagnosticsService.scrubSensitiveData(raw);

      expect(scrubbed.contains('Bearer [REDACTED_TOKEN]'), isTrue);
      expect(scrubbed.contains('eyJhbGci'), isFalse);
    });

    test('redacts user email addresses', () {
      const raw = 'Error reported for user john.doe@example.com during session';
      final scrubbed = CrashDiagnosticsService.scrubSensitiveData(raw);

      expect(scrubbed.contains('[REDACTED_EMAIL]'), isTrue);
      expect(scrubbed.contains('john.doe@example.com'), isFalse);
    });

    test('redacts passwords and API keys', () {
      const raw = 'Config dump: apiKey: ak_live_999999, token="secret_token_123", password=MyP@ssword123';
      final scrubbed = CrashDiagnosticsService.scrubSensitiveData(raw);

      expect(scrubbed.contains('apiKey=[REDACTED]'), isTrue);
      expect(scrubbed.contains('token=[REDACTED]'), isTrue);
      expect(scrubbed.contains('password=[REDACTED]'), isTrue);
      expect(scrubbed.contains('ak_live_999999'), isFalse);
      expect(scrubbed.contains('secret_token_123'), isFalse);
      expect(scrubbed.contains('MyP@ssword123'), isFalse);
    });

    test('redacts Windows user personal directory paths', () {
      const raw = r'Stack trace: C:\Users\AliceSmith\AppData\Local\ItFeels\cache\stream.mp4';
      final scrubbed = CrashDiagnosticsService.scrubSensitiveData(raw);

      expect(scrubbed.contains(r'C:\Users\[USER]\AppData\Local\ItFeels\cache\stream.mp4'), isTrue);
      expect(scrubbed.contains('AliceSmith'), isFalse);
    });
  });

  group('CrashDiagnosticsService Structured Reproduction Identifiers', () {
    test('generates expected category prefixes in error IDs', () {
      final diag = CrashDiagnosticsService.instance;

      final plbk = diag.record(
        category: DiagnosticCategory.playback,
        severity: DiagnosticSeverity.error,
        message: 'Stream failed',
      );
      expect(plbk.id, startsWith('ERR-PLBK-'));

      final net = diag.record(
        category: DiagnosticCategory.network,
        severity: DiagnosticSeverity.warning,
        message: 'Timeout 408',
      );
      expect(net.id, startsWith('ERR-NET-'));

      final db = diag.record(
        category: DiagnosticCategory.database,
        severity: DiagnosticSeverity.error,
        message: 'Isar write failed',
      );
      expect(db.id, startsWith('ERR-DB-'));

      final fwk = diag.record(
        category: DiagnosticCategory.framework,
        severity: DiagnosticSeverity.error,
        message: 'Widget overflow',
      );
      expect(fwk.id, startsWith('ERR-FWK-'));

      final plat = diag.record(
        category: DiagnosticCategory.platform,
        severity: DiagnosticSeverity.info,
        message: 'Audio route changed',
      );
      expect(plat.id, startsWith('ERR-PLAT-'));

      final life = diag.record(
        category: DiagnosticCategory.lifecycle,
        severity: DiagnosticSeverity.info,
        message: 'App paused',
      );
      expect(life.id, startsWith('ERR-LIFE-'));
    });
  });

  group('CrashDiagnosticsService Circular Buffer & Reports', () {
    test('enforces bounded memory limit (150 items) on circular buffer', () {
      final diag = CrashDiagnosticsService.instance;

      for (int i = 0; i < 180; i++) {
        diag.record(
          category: DiagnosticCategory.playback,
          severity: DiagnosticSeverity.info,
          message: 'Operation message $i',
        );
      }

      final records = diag.getRecentRecords(limit: 300);
      expect(records.length, equals(150));
      // Most recent item should be message 179
      expect(records.first.message, equals('Operation message 179'));
      // Oldest retained item should be message 30 (since 180 - 150 = 30)
      expect(records.last.message, equals('Operation message 30'));
    });

    test('generates comprehensive diagnostic report schema', () {
      final diag = CrashDiagnosticsService.instance;

      diag.recordPlaybackFailure(
        songId: 'song_123',
        songTitle: 'Tum Hi Ho',
        reason: 'HTTP 403 Forbidden',
      );
      diag.recordNetworkFailure(
        provider: 'JioSaavn',
        endpoint: '/api.php',
        error: 'SocketException: Connection reset by peer',
        statusCode: 502,
      );
      diag.recordDatabaseError(
        operation: 'savePlaylist',
        error: 'Disk full',
      );

      final report = diag.generateDiagnosticReport();

      expect(report.containsKey('generatedAt'), isTrue);
      expect(report['totalRecords'], equals(3));
      expect(report['categoryBreakdown']['playback'], equals(1));
      expect(report['categoryBreakdown']['network'], equals(1));
      expect(report['categoryBreakdown']['database'], equals(1));

      final recentErrors = report['recentErrors'] as List;
      expect(recentErrors.length, equals(3));
      expect(recentErrors.first['id'], isNotNull);
    });

    test('sanitizes metadata payload strings', () {
      final diag = CrashDiagnosticsService.instance;

      final record = diag.record(
        category: DiagnosticCategory.network,
        severity: DiagnosticSeverity.error,
        message: 'Auth fail',
        metadata: {
          'token': 'Bearer secret123token',
          'userEmail': 'test@example.com',
          'retryCount': 2,
        },
      );

      expect(record.metadata?['token'], equals('Bearer [REDACTED_TOKEN]'));
      expect(record.metadata?['userEmail'], equals('[REDACTED_EMAIL]'));
      expect(record.metadata?['retryCount'], equals(2));
    });
  });
}
