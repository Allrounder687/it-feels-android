import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/services/lastfm_service.dart';

class MockMusicRepository extends Mock implements IMusicRepository {}
class MockLastfmService extends Mock implements LastfmService {}

void main() {
  late MockMusicRepository mockMusicRepo;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({'default_category': 'Trending'});
    mockMusicRepo = MockMusicRepository();
    if (!locator.isRegistered<IMusicRepository>()) {
      locator.registerSingleton<IMusicRepository>(mockMusicRepo);
    }
    final mockLastfm = MockLastfmService();
    if (!locator.isRegistered<LastfmService>()) {
      locator.registerSingleton<LastfmService>(mockLastfm);
      when(() => mockLastfm.getUserTopTracks(any())).thenAnswer((_) async => []);
      when(() => mockLastfm.isLoggedIn()).thenAnswer((_) async => false);
    }
    when(() => mockMusicRepo.getCharts()).thenAnswer((_) async => {'tracks': <Song>[], 'playlists': <Playlist>[]});
    when(() => mockMusicRepo.getChartsByLanguage(any())).thenAnswer((_) async => {'tracks': <Song>[], 'playlists': <Playlist>[]});
    when(() => mockMusicRepo.getFeaturedPlaylistsByLanguage(any())).thenAnswer((_) async => <Playlist>[]);
    when(() => mockMusicRepo.getPlaylistTracks(any())).thenAnswer((_) async => <Song>[]);

    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    locator.reset();
  });

  group('HomeNotifier Tests', () {
    test('Initialization fetches homepage data and sets default category', () async {
      when(() => mockMusicRepo.fetchHomepageData(onError: any(named: 'onError')))
          .thenAnswer((_) async => {
                'trending': [
                  Song(
                    id: '1', saavnId: '1', title: 'Trending 1', artist: 'Artist',
                    album: 'Album', duration: 100, coverArt: 'url', addedAt: DateTime.now(),
                  )
                ],
                'playlists': [],
              });

      when(() => mockMusicRepo.searchSongs(any(), count: any(named: 'count'))).thenAnswer((_) async => <Song>[]);
      when(() => mockMusicRepo.searchPlaylists(any(), count: any(named: 'count'))).thenAnswer((_) async => <Playlist>[]);
      when(() => mockMusicRepo.searchAlbums(any(), count: any(named: 'count'))).thenAnswer((_) async => <Playlist>[]);

      container.read(homeProvider);
      await Future.delayed(const Duration(milliseconds: 800));

      expect(container.read(homeProvider).isLoading, false);
      expect(container.read(homeProvider).trendingSongs.length, 1);
      expect(container.read(homeProvider).trendingSongs.first.title, 'Trending 1');
    });

    test('selectCategory changes category and triggers fetch if needed', () async {
      when(() => mockMusicRepo.fetchHomepageData(onError: any(named: 'onError')))
          .thenAnswer((_) async => {'trending': [], 'playlists': []});
      when(() => mockMusicRepo.searchSongs(any(), count: any(named: 'count'))).thenAnswer((_) async => <Song>[]);
      when(() => mockMusicRepo.searchPlaylists(any(), count: any(named: 'count'))).thenAnswer((_) async => <Playlist>[]);
      when(() => mockMusicRepo.searchAlbums(any(), count: any(named: 'count'))).thenAnswer((_) async => <Playlist>[]);

      final notifier = container.read(homeProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 800));

      await notifier.selectCategory('Podcasts');
      expect(container.read(homeProvider).selectedCategory, 'Podcasts');
    });
  });
}
