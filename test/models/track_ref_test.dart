import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/data/models/track_ref.dart';
import 'package:it_feels_music/data/models/song_model.dart';

void main() {
  group('TrackRef', () {
    test('fromJson correctly parses valid Spotify JSON', () {
      final json = {
        'id': '3n3Ppam7vgaVa1iaRUc9Lp',
        'name': 'Mr. Brightside',
        'duration_ms': 222000,
        'artists': [
          {'name': 'The Killers'}
        ],
        'album': {
          'name': 'Hot Fuss',
          'images': [
            {'url': 'https://i.scdn.co/image/ab67616d0000b273b0a70193bb92db433f4ecf81'}
          ]
        }
      };

      final trackRef = TrackRef.fromJson(json);

      expect(trackRef.spotifyId, '3n3Ppam7vgaVa1iaRUc9Lp');
      expect(trackRef.title, 'Mr. Brightside');
      expect(trackRef.artists, ['The Killers']);
      expect(trackRef.album, 'Hot Fuss');
      expect(trackRef.albumArtUrl, 'https://i.scdn.co/image/ab67616d0000b273b0a70193bb92db433f4ecf81');
      expect(trackRef.durationMs, 222000);
    });

    test('fromJson handles missing data gracefully', () {
      final json = {
        'id': 'missing_data_id',
      };

      final trackRef = TrackRef.fromJson(json);

      expect(trackRef.spotifyId, 'missing_data_id');
      expect(trackRef.title, 'Unknown Title');
      expect(trackRef.artists, ['Unknown Artist']);
      expect(trackRef.album, 'Unknown Album');
      expect(trackRef.albumArtUrl, '');
      expect(trackRef.durationMs, 0);
    });

    test('toSong adapts TrackRef to Song correctly', () {
      final trackRef = TrackRef(
        spotifyId: '12345',
        title: 'Test Song (Remastered)',
        artists: ['Artist A', 'Artist B'],
        album: 'Test Album',
        albumArtUrl: 'https://example.com/image.jpg',
        durationMs: 180000,
      );

      final song = trackRef.toSong();

      expect(song.id, 'spotify:12345');
      expect(song.saavnId, '12345'); // Default saavnId fallback to spotifyId
      expect(song.title, 'Test Song (Remastered)');
      expect(song.artist, 'Artist A, Artist B');
      expect(song.album, 'Test Album');
      expect(song.duration, 180); // 180000 ms -> 180 s
      expect(song.coverArt, 'https://example.com/image.jpg');
      
      // Ensure search vector works
      expect(song.searchVector.isNotEmpty, true);
    });
  });
}
