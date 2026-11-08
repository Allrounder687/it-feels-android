import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/services/data_integrity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Data Integrity & Corrupted Payload Recovery Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('safeWriteString validates JSON and creates rolling backup snapshot', () async {
      final service = DataIntegrityService.instance;
      const key = 'test_favorites_key';
      final validJson1 = jsonEncode([{'id': 'song_1', 'title': 'First Song'}]);
      final validJson2 = jsonEncode([{'id': 'song_1', 'title': 'First Song'}, {'id': 'song_2', 'title': 'Second Song'}]);

      // 1st write
      final ok1 = await service.safeWriteString(key, validJson1);
      expect(ok1, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(key), equals(validJson1));
      expect(prefs.getString('${key}_backup_snapshot'), isNull); // No previous state yet

      // 2nd write - should snapshot validJson1 into backup
      final ok2 = await service.safeWriteString(key, validJson2);
      expect(ok2, isTrue);
      expect(prefs.getString(key), equals(validJson2));
      expect(prefs.getString('${key}_backup_snapshot'), equals(validJson1));
    });

    test('safeWriteString rejects corrupted or malformed JSON payloads', () async {
      final service = DataIntegrityService.instance;
      const key = 'test_corrupt_key';
      const malformedJson = '{"id": "incomplete_json';

      final ok = await service.safeWriteString(key, malformedJson);
      expect(ok, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(key), isNull);
    });

    test('safeReadString automatically rolls back to backup when primary is corrupted', () async {
      final service = DataIntegrityService.instance;
      const key = 'test_recovery_key';
      final backupJson = jsonEncode([{'id': 'restored_song', 'title': 'Restored Masterpiece'}]);
      const corruptedJson = '{"broken": [truncated...';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, corruptedJson);
      await prefs.setString('${key}_backup_snapshot', backupJson);

      // Reading primary should detect corruption, roll back to backup, and auto-heal
      final recovered = await service.safeReadString(key);
      expect(recovered, isNotNull);
      expect(recovered, equals(backupJson));

      // Assert that primary key was auto-healed in storage
      expect(prefs.getString(key), equals(backupJson));
    });

    test('deduplicateList removes duplicated entities and preserves unique order', () {
      final rawList = [
        {'id': 'track_1', 'title': 'Track One'},
        {'id': 'track_2', 'title': 'Track Two'},
        {'id': 'track_1', 'title': 'Track One Duplicate'},
        {'id': 'track_3', 'title': 'Track Three'},
        {'id': 'track_2', 'title': 'Track Two Duplicate'},
      ];

      final deduplicated = DataIntegrityService.deduplicateList(rawList);
      expect(deduplicated.length, equals(3));
      expect(deduplicated[0]['id'], equals('track_1'));
      expect(deduplicated[1]['id'], equals('track_2'));
      expect(deduplicated[2]['id'], equals('track_3'));
    });
  });
}
