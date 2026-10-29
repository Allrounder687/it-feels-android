import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/core/utils/des_decryptor.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/data/datasources/local_cache_data_source.dart';

class FakeLocalCacheDataSource extends Fake implements LocalCacheDataSource {
  List<Song>? cachedSearch;
  Map<String, dynamic>? cachedFeed;

  @override
  Future<List<Song>?> getCachedSearchResults(String query) async => cachedSearch;

  @override
  Future<Map<String, dynamic>?> getCachedHomeFeed() async => cachedFeed;

  @override
  Future<void> cacheSearchResults(String query, List<Song> results) async {
    cachedSearch = results;
  }
}

void main() {
  late FakeLocalCacheDataSource fakeCache;
  late MusicRepository repository;

  final sampleSong = Song(
    id: 'test_123',
    saavnId: 'test_123',
    title: 'Test Title',
    artist: 'Test Artist',
    album: 'Test Album',
    duration: 180,
    coverArt: 'https://example.com/cover.jpg',
    addedAt: DateTime.now(),
  );

  setUp(() {
    fakeCache = FakeLocalCacheDataSource();
    repository = MusicRepository(cacheDataSource: fakeCache);
  });

  group('MusicRepository Stream & Decryption Tests', () {
    test('instant TripleDES client-side decryption resolves valid 320kbps MP4 CDN URL', () async {
      const encryptedSample = 'ID2ieOjCrwfgWvL5sXl4B1ImC5QfbsDyCYPdAVTq0Fm7Jq9PsBC2ExgU7MasW8n/';
      final decrypted = await DesDecryptor.decrypt(encryptedSample);
      expect(decrypted, equals('https://aac.saavncdn.com/test_url_320.mp4'));

      final songWithEncryptedUrl = sampleSong.copyWith(
        encryptedMediaUrl: encryptedSample,
      );
      final streamUrl = await repository.getStreamUrl(songWithEncryptedUrl);
      expect(streamUrl, equals('https://aac.saavncdn.com/test_url_320.mp4'));
    });

    test('getStreamUrl passes through radio: streams directly without addon worker', () async {
      final radioSong = sampleSong.copyWith(
        id: 'radio:station_123',
        streamUrl: 'https://stream.radio.org/live.mp3',
      );

      final url = await repository.getStreamUrl(radioSong);
      expect(url, equals('https://stream.radio.org/live.mp3'));
    });

    test('getStreamUrl passes through direct HTTP streams directly', () async {
      final directSong = sampleSong.copyWith(
        streamUrl: 'https://aac.saavncdn.com/direct_sample.mp4',
      );

      final url = await repository.getStreamUrl(directSong);
      expect(url, equals('https://aac.saavncdn.com/direct_sample.mp4'));
    });
  });
}
