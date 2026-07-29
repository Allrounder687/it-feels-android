import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/services/storage_service.dart';
import 'package:it_feels_music/data/models/song_model.dart';

void main() {
  setUp(() {
    // Mock SharedPreferences for tests
    SharedPreferences.setMockInitialValues({});
  });

  group('StorageService Tests', () {
    test('save and load default category', () async {
      // By default it should return 'Bollywood' if not set
      final defaultCategory = await StorageService.loadDefaultCategory();
      expect(defaultCategory, 'Bollywood');

      // Save a new category
      await StorageService.saveDefaultCategory('Pop');
      
      // Load and verify
      final updatedCategory = await StorageService.loadDefaultCategory();
      expect(updatedCategory, 'Pop');
    });

    test('save and load listening history', () async {
      final history = {'Artist A': 5, 'Artist B': 2};
      await StorageService.saveListeningHistory(history);

      final loadedHistory = await StorageService.loadListeningHistory();
      expect(loadedHistory, history);
    });

    test('save and load settings', () async {
      await StorageService.saveSettings(
        wifiQuality: '320 kbps',
        mobileQuality: '128 kbps',
        downloadQuality: '320 kbps',
        theme: 'Light',
        customDownloadPath: '/custom/path',
        enableAndroidAuto: false,
        hapticsMode: 'light',
      );

      final settings = await StorageService.loadSettings();
      expect(settings['wifiQuality'], '320 kbps');
      expect(settings['mobileQuality'], '128 kbps');
      expect(settings['theme'], 'Light');
      expect(settings['customDownloadPath'], '/custom/path');
    });

    test('save and load recently played', () async {
      final song = Song(
        id: 'saavn:recent1',
        saavnId: 'recent1',
        title: 'Recent Song',
        artist: 'Recent Artist',
        album: 'Recent Album',
        duration: 200,
        coverArt: 'url',
        addedAt: DateTime.now(),
      );

      await StorageService.saveRecentlyPlayed([song]);

      final loadedSongs = await StorageService.loadRecentlyPlayed();
      expect(loadedSongs.length, 1);
      expect(loadedSongs.first.id, 'saavn:recent1');
      expect(loadedSongs.first.title, 'Recent Song');
    });
  });
}
