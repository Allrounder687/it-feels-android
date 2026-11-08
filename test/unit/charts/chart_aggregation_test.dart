import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/core/intelligence/charts/chart_aggregation_service.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/models/song_model.dart';

class MockMusicRepository implements IMusicRepository {
  @override
  Future<List<Song>> getPlaylistTracks(String playlistId) async {
    return List.generate(
      40,
      (i) => Song(
        id: 'track_$i',
        saavnId: 'saavn_$i',
        title: 'Playlist Track $i',
        artist: 'Arijit Singh',
        album: 'Album $i',
        language: 'hindi',
        duration: 210,
        coverArt: 'https://example.com/art_$i.jpg',
        addedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<List<Song>> searchSongs(String query, {int count = 20, int page = 1}) async {
    return List.generate(
      count,
      (i) => Song(
        id: 'search_item_${query}_$i',
        saavnId: 'search_saavn_$i',
        title: 'Search Song $i',
        artist: 'Pritam',
        album: 'OST $i',
        language: 'hindi',
        duration: 220,
        coverArt: 'https://example.com/search_$i.jpg',
        addedAt: DateTime.now(),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    locator.registerSingleton<IMusicRepository>(MockMusicRepository());
  });

  tearDownAll(() {
    locator.reset();
  });

  group('ChartAggregationService Tests', () {
    test('provides at least 7 verified categories including top 50 charts', () {
      const categories = ChartAggregationService.categories;
      expect(categories.length, greaterThanOrEqualTo(7));

      final categoryIds = categories.map((c) => c.id).toSet();
      expect(categoryIds.contains('hindi_top_50'), isTrue);
      expect(categoryIds.contains('india_superhits'), isTrue);
      expect(categoryIds.contains('international_top_50'), isTrue);
      expect(categoryIds.contains('punjabi_top_50'), isTrue);
      expect(categoryIds.contains('telugu_top_50'), isTrue);
      expect(categoryIds.contains('tamil_top_50'), isTrue);
      expect(categoryIds.contains('viral_hits'), isTrue);
    });

    test('fetches and aggregates at least 50 verified tracks with deduplication', () async {
      final service = ChartAggregationService.instance;

      final tracks = await service.fetchChartTracks('hindi_top_50', forceRefresh: true);
      expect(tracks.length, greaterThanOrEqualTo(50));

      // Verify no duplicates by ID
      final ids = tracks.map((t) => t.id).toSet();
      expect(ids.length, tracks.length);
    });

    test('caches results and reports valid cache', () async {
      final service = ChartAggregationService.instance;
      expect(service.isCacheValid('hindi_top_50'), isTrue);
      expect(service.getLastUpdated('hindi_top_50'), isNotNull);
    });
  });
}
