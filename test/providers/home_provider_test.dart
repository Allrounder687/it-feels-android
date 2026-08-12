import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/services/lastfm_service.dart';
import 'package:it_feels_music/data/services/deezer_api_service.dart';

class MockMusicApiService extends Mock implements MusicApiService {}
class MockLastfmService extends Mock implements LastfmService {}
class MockDeezerApiService extends Mock implements DeezerApiService {}

void main() {
  late MockMusicApiService mockApiService;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({'default_category': 'Trending'});
    mockApiService = MockMusicApiService();
    if (!locator.isRegistered<MusicApiService>()) {
      locator.registerSingleton<MusicApiService>(mockApiService);
    }
    final mockLastfm = MockLastfmService();
    if (!locator.isRegistered<LastfmService>()) {
      locator.registerSingleton<LastfmService>(mockLastfm);
      when(() => mockLastfm.getUserTopTracks(any())).thenAnswer((_) async => []);
      when(() => mockLastfm.isLoggedIn()).thenAnswer((_) async => false);
    }
    final mockDeezer = MockDeezerApiService();
    if (!locator.isRegistered<DeezerApiService>()) {
      locator.registerSingleton<DeezerApiService>(mockDeezer);
      when(() => mockDeezer.getCharts()).thenAnswer((_) async => {'tracks': <Song>[], 'playlists': <Playlist>[]});
    }
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    locator.reset();
  });

  group('HomeNotifier Tests', () {
    test('Initialization fetches homepage data and sets default category', () async {
      when(() => mockApiService.fetchHomepageData(onError: any(named: 'onError')))
          .thenAnswer((_) async => {
                'trending': [
                  Song(
                    id: '1', saavnId: '1', title: 'Trending 1', artist: 'Artist',
                    album: 'Album', duration: 100, coverArt: 'url', addedAt: DateTime.now(),
                  )
                ],
                'playlists': [],
              });

      when(() => mockApiService.searchSongs(any(), count: any(named: 'count'))).thenAnswer((_) async => <Song>[]);
      when(() => mockApiService.searchPlaylists(any(), count: any(named: 'count'))).thenAnswer((_) async => <Playlist>[]);
      when(() => mockApiService.searchAlbums(any(), count: any(named: 'count'))).thenAnswer((_) async => <Playlist>[]);

      container.read(homeProvider);
      await Future.delayed(const Duration(milliseconds: 300));

      expect(container.read(homeProvider).isLoading, false);
      expect(container.read(homeProvider).trendingSongs.length, 1);
      expect(container.read(homeProvider).trendingSongs.first.title, 'Trending 1');
    });

    test('selectCategory changes category and triggers fetch if needed', () async {
      when(() => mockApiService.fetchHomepageData(onError: any(named: 'onError')))
          .thenAnswer((_) async => {'trending': [], 'playlists': []});
      when(() => mockApiService.searchSongs(any(), count: any(named: 'count'))).thenAnswer((_) async => <Song>[]);
      when(() => mockApiService.searchPlaylists(any(), count: any(named: 'count'))).thenAnswer((_) async => <Playlist>[]);
      when(() => mockApiService.searchAlbums(any(), count: any(named: 'count'))).thenAnswer((_) async => <Playlist>[]);

      final notifier = container.read(homeProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 300));

      await notifier.selectCategory('Podcasts');
      expect(container.read(homeProvider).selectedCategory, 'Podcasts');
    });
  });
}
