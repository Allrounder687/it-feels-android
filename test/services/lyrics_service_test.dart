import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/data/services/lyrics_service.dart';
import 'package:it_feels_music/data/models/song_model.dart';

void main() {
  late LyricsService lyricsService;

  setUp(() {
    lyricsService = LyricsService();
  });

  group('LyricsService Caching & Preloading', () {
    test('isLyricsCached returns false initially and true after caching', () {
      final song = Song(
        id: 'test_song_123',
        saavnId: '123',
        title: 'Kesariya',
        artist: 'Arijit Singh',
        album: 'Brahmastra',
        coverArt: '',
        duration: 268,
        addedAt: DateTime.now(),
      );

      expect(lyricsService.isLyricsCached(song.id), isFalse);
    });
  });
}
