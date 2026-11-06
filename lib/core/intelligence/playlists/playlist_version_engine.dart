import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/intelligence/playlists/dynamic_playlist_models.dart';

/// Versioning and reconciliation engine that preserves user modifications across scheduled refreshes.
class PlaylistVersionEngine {
  PlaylistVersionEngine._();

  /// Reconciles freshly generated tracks with user modifications:
  /// 1. Excludes any track previously removed by the user (userRemovedTrackIds).
  /// 2. Preserves any track manually added by the user (userAddedTrackIds).
  /// 3. Increments playlist version counter.
  static DynamicPlaylist reconcileRefresh({
    required DynamicPlaylist currentPlaylist,
    required List<Song> freshlyGeneratedTracks,
    DateTime? refreshTime,
  }) {
    final now = refreshTime ?? DateTime.now();
    final userRemoved = currentPlaylist.userRemovedTrackIds;
    final userAdded = currentPlaylist.userAddedTrackIds;

    // 1. Filter out tracks the user explicitly removed
    final filteredGenerated = freshlyGeneratedTracks
        .where((s) => !userRemoved.contains(s.id))
        .toList();

    // 2. Identify preserved user-added tracks from current version
    final preservedUserTracks = currentPlaylist.tracks
        .where((s) => userAdded.contains(s.id))
        .toList();

    // 3. Merge: preserved user tracks placed at the top or merged cleanly without duplicates
    final seenIds = <String>{};
    final finalTracks = <Song>[];

    for (final song in preservedUserTracks) {
      if (seenIds.add(song.id)) {
        finalTracks.add(song);
      }
    }

    for (final song in filteredGenerated) {
      if (seenIds.add(song.id)) {
        finalTracks.add(song);
      }
    }

    final newVersion = currentPlaylist.version + 1;

    return currentPlaylist.copyWith(
      tracks: finalTracks,
      version: newVersion,
      lastRefreshedAt: now,
    );
  }

  /// Records a manual user track addition.
  static DynamicPlaylist addTrack({
    required DynamicPlaylist playlist,
    required Song song,
  }) {
    // If it was previously marked removed, clear it from removed set
    final updatedRemoved = Set<String>.from(playlist.userRemovedTrackIds)..remove(song.id);
    final updatedAdded = Set<String>.from(playlist.userAddedTrackIds)..add(song.id);

    final updatedTracks = List<Song>.from(playlist.tracks);
    if (!updatedTracks.any((s) => s.id == song.id)) {
      updatedTracks.insert(0, song);
    }

    return playlist.copyWith(
      tracks: updatedTracks,
      userAddedTrackIds: updatedAdded,
      userRemovedTrackIds: updatedRemoved,
    );
  }

  /// Records a manual user track deletion.
  static DynamicPlaylist removeTrack({
    required DynamicPlaylist playlist,
    required String songId,
  }) {
    // If it was in userAdded, remove it from added set
    final updatedAdded = Set<String>.from(playlist.userAddedTrackIds)..remove(songId);
    final updatedRemoved = Set<String>.from(playlist.userRemovedTrackIds)..add(songId);

    final updatedTracks = playlist.tracks.where((s) => s.id != songId).toList();

    return playlist.copyWith(
      tracks: updatedTracks,
      userAddedTrackIds: updatedAdded,
      userRemovedTrackIds: updatedRemoved,
    );
  }

  /// Creates a point-in-time snapshot of the playlist for rollback capabilities.
  static PlaylistVersionSnapshot createSnapshot(DynamicPlaylist playlist) {
    return PlaylistVersionSnapshot(
      playlistId: playlist.id,
      version: playlist.version,
      timestamp: playlist.lastRefreshedAt,
      trackIds: playlist.tracks.map((s) => s.id).toList(),
    );
  }
}
