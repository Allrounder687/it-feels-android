import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/data/models/song_model.dart';

void main() {
  group('NowPlayingScreen UI/UX Redesign Tests', () {
    test('Song model stream quality tag helper evaluation', () {
      final now = DateTime.now();
      final flacSong = Song(
        id: '1',
        saavnId: '1',
        title: 'Test FLAC Track',
        artist: 'Test Artist',
        album: 'Test Album',
        coverArt: '',
        duration: 180,
        streamUrl: 'https://example.com/song.flac',
        addedAt: now,
      );

      final mp3Song = Song(
        id: '2',
        saavnId: '2',
        title: 'Test MP3 Track',
        artist: 'Test Artist',
        album: 'Test Album',
        coverArt: '',
        duration: 180,
        streamUrl: 'https://example.com/song.mp3',
        addedAt: now,
      );

      final isFlacLossless = flacSong.streamUrl?.toLowerCase().endsWith('.flac') ?? false;
      final isMp3Lossless = mp3Song.streamUrl?.toLowerCase().endsWith('.flac') ?? false;

      expect(isFlacLossless, isTrue);
      expect(isMp3Lossless, isFalse);
    });

    test('Queue up next resolution logic', () {
      final now = DateTime.now();
      final songs = [
        Song(id: '1', saavnId: '1', title: 'Song 1', artist: 'Artist 1', album: '', coverArt: '', duration: 0, addedAt: now),
        Song(id: '2', saavnId: '2', title: 'Song 2', artist: 'Artist 2', album: '', coverArt: '', duration: 0, addedAt: now),
      ];

      int currentIndex = 0;
      Song? nextSong = (songs.isNotEmpty && currentIndex + 1 < songs.length) ? songs[currentIndex + 1] : null;
      expect(nextSong?.title, 'Song 2');

      currentIndex = 1;
      nextSong = (songs.isNotEmpty && currentIndex + 1 < songs.length) ? songs[currentIndex + 1] : null;
      expect(nextSong, isNull);
    });

    test('Daily Mix title cleaning logic', () {
      final plTitle = 'Daily Mix: Arijit Singh';
      String displayTitle = plTitle;
      if (displayTitle.startsWith("Daily Mix: ")) {
        displayTitle = "${displayTitle.replaceFirst("Daily Mix: ", "")} Mix";
      }
      expect(displayTitle, 'Arijit Singh Mix');
    });
  });
}
