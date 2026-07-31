import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/features/home/home_provider.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';

class MockMusicApiService extends Mock implements MusicApiService {}

void main() {
  late MockMusicApiService mockApiService;

  setUp(() {
    SharedPreferences.setMockInitialValues({'default_category': 'Trending'});
    mockApiService = MockMusicApiService();
    if (!locator.isRegistered<MusicApiService>()) {
      locator.registerSingleton<MusicApiService>(mockApiService);
    }
  });

  tearDown(() {
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

      final notifier = HomeNotifier();
      expect(notifier.state.isLoading, true);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.state.isLoading, false);
      expect(notifier.state.trendingSongs.length, 1);
      expect(notifier.state.trendingSongs.first.title, 'Trending 1');
    });

    test('selectCategory changes category and triggers fetch if needed', () async {
      when(() => mockApiService.fetchHomepageData(onError: any(named: 'onError')))
          .thenAnswer((_) async => {'trending': [], 'playlists': []});
      when(() => mockApiService.searchSongs(any(), count: any(named: 'count'))).thenAnswer((_) async => <Song>[]);
      when(() => mockApiService.searchPlaylists(any(), count: any(named: 'count'))).thenAnswer((_) async => <Playlist>[]);
      when(() => mockApiService.searchAlbums(any(), count: any(named: 'count'))).thenAnswer((_) async => <Playlist>[]);

      when(() => mockApiService.searchAll('Podcasts')).thenAnswer((_) async => {'songs': <Song>[], 'playlists': <Playlist>[]});
      when(() => mockApiService.searchPlaylists('Podcasts')).thenAnswer((_) async => <Playlist>[]);

      final notifier = HomeNotifier();
      await Future.delayed(const Duration(milliseconds: 100));

      await notifier.selectCategory('Podcasts');
      expect(notifier.state.selectedCategory, 'Podcasts');
      
      verify(() => mockApiService.searchAll('Podcasts')).called(1);
    });
  });
}
