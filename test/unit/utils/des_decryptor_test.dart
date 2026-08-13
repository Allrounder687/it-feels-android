import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/core/utils/des_decryptor.dart';

void main() {
  group('DesDecryptor Tests', () {
    test('decrypt returns null for empty string', () async {
      final result = await DesDecryptor.decrypt('');
      expect(result, isNull);
    });

    test('decrypt bypasses decryption for standard unencrypted http/https URLs', () async {
      const url = 'https://aac.saavncdn.com/test_track.mp4';
      final result = await DesDecryptor.decrypt(url);
      expect(result, equals(url));
    });

    test('decrypt correctly decrypts valid DES base64 cipher block', () async {
      // Encrypted representation of 'https://aac.saavncdn.com/test_url_96.mp4' using key '38346591'
      const encrypted = 'ID2ieOjCrwfgWvL5sXl4B1ImC5QfbsDyCYPdAVTq0Fm7Jq9PsBC2ExgU7MasW8n/';
      final result = await DesDecryptor.decrypt(encrypted);
      expect(result, equals('https://aac.saavncdn.com/test_url_96.mp4'));
    });

    test('get320kbpsUrl upgrades stream quality', () {
      expect(DesDecryptor.get320kbpsUrl(null), isNull);
      expect(DesDecryptor.get320kbpsUrl(''), isNull);

      // Standard CDN upgrade
      const lowUrl = 'https://preview.saavncdn.com/test_track_96.mp3';
      final upgraded = DesDecryptor.get320kbpsUrl(lowUrl);
      expect(upgraded, equals('https://aac.saavncdn.com/test_track_320.mp4'));

      // Non-preview CDN upgrade
      const otherUrl = 'https://somecdn.com/test_track_160.m4a';
      final otherUpgraded = DesDecryptor.get320kbpsUrl(otherUrl);
      expect(otherUpgraded, equals('https://somecdn.com/test_track_320.mp4'));
    });

    test('get96kbpsUrl downgrades stream quality', () {
      expect(DesDecryptor.get96kbpsUrl(null), isNull);
      expect(DesDecryptor.get96kbpsUrl(''), isNull);

      // High to low
      const highUrl = 'https://aac.saavncdn.com/test_track_320.mp4';
      expect(DesDecryptor.get96kbpsUrl(highUrl), equals('https://aac.saavncdn.com/test_track_96.mp4'));

      // Medium to low
      const midUrl = 'https://aac.saavncdn.com/test_track_160.mp4';
      expect(DesDecryptor.get96kbpsUrl(midUrl), equals('https://aac.saavncdn.com/test_track_96.mp4'));

      // Safe bypass if already low
      const lowUrl = 'https://aac.saavncdn.com/test_track_96.mp4';
      expect(DesDecryptor.get96kbpsUrl(lowUrl), equals(lowUrl));
    });
  });
}
