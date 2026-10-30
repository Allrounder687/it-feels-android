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

    test('Playlist.fromJson handles search, featured, and contents-based contracts', () {
      // 1. Search Result (listid, listname, count)
      final searchJson = {
        'listid': '1185452256',
        'listname': 'Hollywood Instrumentals',
        'count': '42',
        'image': 'https://c.saavncdn.com/test.jpg',
      };
      final p1 = Playlist.fromJson(searchJson);
      expect(p1.id, '1185452256');
      expect(p1.title, 'Hollywood Instrumentals');
      expect(p1.songCount, 42);

      // 2. Featured Result (id, title, more_info.song_count)
      final featuredJson = {
        'id': '1302090358',
        'title': 'Chartbusters 2026 - International',
        'image': 'https://c.saavncdn.com/test2.jpg',
        'more_info': {
          'song_count': '50',
          'follower_count': '2193',
        },
      };
      final p2 = Playlist.fromJson(featuredJson);
      expect(p2.id, '1302090358');
      expect(p2.title, 'Chartbusters 2026 - International');
      expect(p2.songCount, 50);

      // 3. Detail Result with list_count: 0 but contents string
      final detailJson = {
        'id': '81399744',
        'title': 'Heartbeats',
        'list_count': '0',
        'more_info': {
          'contents': 'song1,song2,song3,song4,song5',
          'follower_count': '112000',
        },
      };
      final p3 = Playlist.fromJson(detailJson);
      expect(p3.id, '81399744');
      expect(p3.title, 'Heartbeats');
      expect(p3.songCount, 5); // Must not be 0 despite list_count: 0
    });
  });
}
