import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/core/utils/lrc_parser.dart';

void main() {
  group('LrcParser Tests', () {
    test('parse returns empty list for empty string', () {
      final result = LrcParser.parse('');
      expect(result, isEmpty);
    });

    test('parse parses standard LRC timestamps [mm:ss.xx]', () {
      const lrc = '[01:23.45]This is a lyric';
      final result = LrcParser.parse(lrc);

      expect(result, hasLength(1));
      expect(result[0].text, equals('This is a lyric'));
      expect(
        result[0].time, 
        equals(const Duration(minutes: 1, seconds: 23, milliseconds: 450)),
      );
    });

    test('parse parses fallback LRC timestamps [mm:ss]', () {
      const lrc = '[02:10]Lyric line';
      final result = LrcParser.parse(lrc);

      expect(result, hasLength(1));
      expect(result[0].text, equals('Lyric line'));
      expect(
        result[0].time, 
        equals(const Duration(minutes: 2, seconds: 10)),
      );
    });

    test('parse sorts lyrics chronologically', () {
      const lrc = '''
[02:00]Later line
[01:00]Earlier line
[01:30]Middle line
''';
      final result = LrcParser.parse(lrc);

      expect(result, hasLength(3));
      expect(result[0].text, equals('Earlier line'));
      expect(result[1].text, equals('Middle line'));
      expect(result[2].text, equals('Later line'));
    });

    test('parse skips invalid lines and empty lyric lines', () {
      const lrc = '''
[invalid]Invalid line
[01:00]
[02:00]Valid line
''';
      final result = LrcParser.parse(lrc);

      expect(result, hasLength(1));
      expect(result[0].text, equals('Valid line'));
      expect(result[0].time, equals(const Duration(minutes: 2)));
    });

    test('parse pads and crops milliseconds correctly', () {
      // 1 digit millis => 500ms
      // 3 digit millis => 123ms
      const lrc = '''
[00:10.5]Line 1
[00:20.123]Line 2
''';
      final result = LrcParser.parse(lrc);

      expect(result, hasLength(2));
      expect(result[0].time.inMilliseconds, equals(10500));
      expect(result[1].time.inMilliseconds, equals(20123));
    });
  });
}
