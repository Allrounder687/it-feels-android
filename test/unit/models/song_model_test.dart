import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/data/models/song_model.dart';

void main() {
  group('Song Model Tests', () {
    test('fromJson parses standard saavn response correctly', () {
      final json = {
        'id': '12345',
        'title': 'Test Song',
        'image': 'https://example.com/image.jpg',
        'more_info': {
          'artistMap': {
            'primary_artists': [
              {'name': 'Artist 1'},
              {'name': 'Artist 2'}
            ]
          },
          'album': 'Test Album',
          'duration': '180',
          'has_lyrics': 'true',
          'language': 'Hindi',
        }
      };

      final song = Song.fromJson(json);

      expect(song.id, 'saavn:12345');
      expect(song.saavnId, '12345');
      expect(song.title, 'Test Song');
      expect(song.artist, 'Artist 1, Artist 2');
      expect(song.album, 'Test Album');
      expect(song.duration, 180);
      expect(song.hasLyrics, true);
      // Cover art is modified by ImageUtils to be sized 500
      expect(song.coverArt.isNotEmpty, true); 
    });

    test('generateSearchVector generates correct tokens', () {
      final vector = Song.generateSearchVector('The Test Song', 'An Artist', 'A Great Album');
      
      expect(vector.contains('test'), true);
      expect(vector.contains('song'), true);
      expect(vector.contains('artist'), true);
      expect(vector.contains('great'), true);
      expect(vector.contains('album'), true);
      
      // Should ignore common words like 'the', 'a', 'an'
      expect(vector.contains('the'), false);
      expect(vector.contains('a'), false);
      expect(vector.contains('an'), false);
    });
    
    test('copyWith updates fields correctly', () {
      final song = Song(
        id: 'saavn:123',
        saavnId: '123',
        title: 'Title',
        artist: 'Artist',
        album: 'Album',
        duration: 100,
        coverArt: 'url',
        addedAt: DateTime.now(),
      );

      final updatedSong = song.copyWith(
        isFavorite: true,
        playCount: 5,
        localFilePath: '/local/path',
      );

      expect(updatedSong.isFavorite, true);
      expect(updatedSong.playCount, 5);
      expect(updatedSong.localFilePath, '/local/path');
      expect(updatedSong.id, song.id); // original should remain unchanged
    });
  });
}
