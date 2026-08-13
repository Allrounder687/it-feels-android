import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:it_feels_music/data/services/smart_cache_service.dart';
import 'package:it_feels_music/services/database_service.dart';
import 'package:it_feels_music/services/download_service.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/models/song_model.dart';

class MockDatabaseService extends Mock implements DatabaseService {}
class MockDownloadService extends Mock implements DownloadService {}

void main() {
  late MockDatabaseService mockDbService;
  late MockDownloadService mockDownloadService;
  late SmartCacheService smartCacheService;

  setUpAll(() {
    registerFallbackValue(Song(
      id: '',
      saavnId: '',
      title: '',
      artist: '',
      album: '',
      duration: 0,
      coverArt: '',
      genre: '',
      year: 2026,
      language: '',
      isExplicit: false,
      playCount: 0,
      skipCount: 0,
      addedAt: DateTime.now(),
      isFavorite: false,
      offlineStatus: OfflineStatus.none,
      searchVector: [],
    ));

    mockDownloadService = MockDownloadService();
    if (!locator.isRegistered<DownloadService>()) {
      locator.registerSingleton<DownloadService>(mockDownloadService);
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDbService = MockDatabaseService();
    smartCacheService = SmartCacheService(dbService: mockDbService);

    when(() => mockDownloadService.downloadSong(any())).thenAnswer((_) async => true);
  });

  group('SmartCacheService syncTopSongs', () {
    test('aborts early if smart downloads are disabled in settings', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('enable_smart_downloads_v1', false);

      await smartCacheService.syncTopSongs();

      verifyNever(() => mockDbService.getTopPlayedSongs(limit: any(named: 'limit')));
    });

    test('aborts if database has no top songs to cache', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('enable_smart_downloads_v1', true);

      when(() => mockDbService.getTopPlayedSongs(limit: any(named: 'limit')))
          .thenAnswer((_) async => <Song>[]);

      await smartCacheService.syncTopSongs();

      verifyNever(() => mockDownloadService.downloadSong(any()));
    });

    test('downloads only new non-radio songs that are not already cached', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('enable_smart_downloads_v1', true);
      await prefs.setString('downloaded_songs_json_v1', jsonEncode([
        {
          'id': 'saavn:already_downloaded',
          'saavnId': 'already_downloaded',
          'title': 'Song A',
          'artist': 'Artist A',
          'album': 'Album A',
          'duration': 200,
          'coverArt': '',
        }
      ]));

      final songA = Song(
        id: 'saavn:already_downloaded',
        saavnId: 'already_downloaded',
        title: 'Song A',
        artist: 'Artist A',
        album: 'Album A',
        duration: 200,
        coverArt: '',
        genre: '',
        year: 2026,
        language: '',
        isExplicit: false,
        playCount: 10,
        skipCount: 0,
        addedAt: DateTime.now(),
      );

      final songB = Song(
        id: 'saavn:new_song',
        saavnId: 'new_song',
        title: 'Song B',
        artist: 'Artist B',
        album: 'Album B',
        duration: 220,
        coverArt: '',
        genre: '',
        year: 2026,
        language: '',
        isExplicit: false,
        playCount: 5,
        skipCount: 0,
        addedAt: DateTime.now(),
      );

      final radioSong = Song(
        id: 'radio:123',
        saavnId: '123',
        title: 'Radio Song',
        artist: 'Artist C',
        album: 'Album C',
        duration: 250,
        coverArt: '',
        genre: '',
        year: 2026,
        language: '',
        isExplicit: false,
        playCount: 8,
        skipCount: 0,
        addedAt: DateTime.now(),
      );

      when(() => mockDbService.getTopPlayedSongs(limit: any(named: 'limit')))
          .thenAnswer((_) async => [songA, songB, radioSong]);

      await smartCacheService.syncTopSongs();

      // Should only trigger download for songB
      verify(() => mockDownloadService.downloadSong(songB)).called(1);
      verifyNever(() => mockDownloadService.downloadSong(songA));
      verifyNever(() => mockDownloadService.downloadSong(radioSong));
    });
  });
}
