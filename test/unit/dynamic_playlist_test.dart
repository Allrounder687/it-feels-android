import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/intelligence/playlists/dynamic_playlist_models.dart';
import 'package:it_feels_music/core/intelligence/playlists/playlist_version_engine.dart';

void main() {
  group('Dynamic Playlist Lifecycle & Versioning Tests', () {
    test('user additions and deletions are preserved across scheduled refreshes', () {
      final initialTracks = [
        Song(
          id: 'song_1',
          saavnId: 'song_1',
          title: 'Track 1',
          artist: 'Artist A',
          album: 'Album',
          duration: 180,
          coverArt: '',
          addedAt: DateTime.now(),
        ),
        Song(
          id: 'song_2',
          saavnId: 'song_2',
          title: 'Track 2',
          artist: 'Artist B',
          album: 'Album',
          duration: 200,
          coverArt: '',
          addedAt: DateTime.now(),
        ),
      ];

      var playlist = DynamicPlaylist(
        id: 'daily_mix_1',
        title: 'Bollywood Romance',
        subtitle: 'Daily Mix',
        tracks: initialTracks,
        version: 1,
        lastRefreshedAt: DateTime.now(),
      );

      // User manually removes song_2
      playlist = PlaylistVersionEngine.removeTrack(playlist: playlist, songId: 'song_2');
      expect(playlist.tracks.any((s) => s.id == 'song_2'), isFalse);
      expect(playlist.userRemovedTrackIds, contains('song_2'));

      // User manually adds song_custom
      final customSong = Song(
        id: 'song_custom',
        saavnId: 'song_custom',
        title: 'User Favorite',
        artist: 'Artist C',
        album: 'Album',
        duration: 220,
        coverArt: '',
        addedAt: DateTime.now(),
      );
      playlist = PlaylistVersionEngine.addTrack(playlist: playlist, song: customSong);
      expect(playlist.tracks.first.id, 'song_custom');
      expect(playlist.userAddedTrackIds, contains('song_custom'));

      // Now simulated backend scheduled refresh occurs with fresh songs including song_2 and song_3
      final freshlyGenerated = [
        Song(
          id: 'song_2', // Should be omitted because user deleted it!
          saavnId: 'song_2',
          title: 'Track 2',
          artist: 'Artist B',
          album: 'Album',
          duration: 200,
          coverArt: '',
          addedAt: DateTime.now(),
        ),
        Song(
          id: 'song_3',
          saavnId: 'song_3',
          title: 'Track 3',
          artist: 'Artist D',
          album: 'Album',
          duration: 190,
          coverArt: '',
          addedAt: DateTime.now(),
        ),
      ];

      final refreshed = PlaylistVersionEngine.reconcileRefresh(
        currentPlaylist: playlist,
        freshlyGeneratedTracks: freshlyGenerated,
      );

      // Version must increment to 2
      expect(refreshed.version, 2);

      // User added track must survive refresh!
      expect(refreshed.tracks.any((s) => s.id == 'song_custom'), isTrue);

      // User deleted track must NOT be re-added!
      expect(refreshed.tracks.any((s) => s.id == 'song_2'), isFalse);

      // Fresh track 3 must be present!
      expect(refreshed.tracks.any((s) => s.id == 'song_3'), isTrue);
    });

    test('PlaylistVersionSnapshot captures point in time snapshot', () {
      final playlist = DynamicPlaylist(
        id: 'daily_mix_2',
        title: 'Pop Mix',
        subtitle: 'Pop Hits',
        tracks: [
          Song(id: 'p1', saavnId: 'p1', title: 'T1', artist: 'A', album: 'Al', duration: 100, coverArt: '', addedAt: DateTime.now()),
        ],
        version: 3,
        lastRefreshedAt: DateTime.now(),
      );

      final snapshot = PlaylistVersionEngine.createSnapshot(playlist);
      expect(snapshot.playlistId, 'daily_mix_2');
      expect(snapshot.version, 3);
      expect(snapshot.trackIds, ['p1']);

      final json = snapshot.toJson();
      final restored = PlaylistVersionSnapshot.fromJson(json);
      expect(restored.version, 3);
      expect(restored.trackIds.first, 'p1');
    });
  });
}
