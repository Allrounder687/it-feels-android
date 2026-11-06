import 'package:it_feels_music/data/models/song_model.dart';

/// A versioned dynamic playlist with stable identity that preserves user modifications across refreshes.
class DynamicPlaylist {
  final String id;
  final String title;
  final String subtitle;
  final String? coverArt;
  final List<Song> tracks;
  final Set<String> userAddedTrackIds;
  final Set<String> userRemovedTrackIds;
  final int version;
  final DateTime lastRefreshedAt;
  final Map<String, dynamic> metadata;

  const DynamicPlaylist({
    required this.id,
    required this.title,
    required this.subtitle,
    this.coverArt,
    this.tracks = const [],
    this.userAddedTrackIds = const {},
    this.userRemovedTrackIds = const {},
    this.version = 1,
    required this.lastRefreshedAt,
    this.metadata = const {},
  });

  int get trackCount => tracks.length;

  /// Converts this dynamic playlist into standard Playlist model for UI navigation.
  Playlist toPlaylist() {
    return Playlist(
      id: id,
      title: title,
      subtitle: subtitle,
      image: coverArt ?? (tracks.isNotEmpty ? tracks.first.image : ''),
      songCount: tracks.length,
      songs: tracks,
    );
  }

  DynamicPlaylist copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? coverArt,
    List<Song>? tracks,
    Set<String>? userAddedTrackIds,
    Set<String>? userRemovedTrackIds,
    int? version,
    DateTime? lastRefreshedAt,
    Map<String, dynamic>? metadata,
  }) {
    return DynamicPlaylist(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      coverArt: coverArt ?? this.coverArt,
      tracks: tracks ?? this.tracks,
      userAddedTrackIds: userAddedTrackIds ?? this.userAddedTrackIds,
      userRemovedTrackIds: userRemovedTrackIds ?? this.userRemovedTrackIds,
      version: version ?? this.version,
      lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'coverArt': coverArt,
    'tracks': tracks.map((t) => t.toJson()).toList(),
    'userAddedTrackIds': userAddedTrackIds.toList(),
    'userRemovedTrackIds': userRemovedTrackIds.toList(),
    'version': version,
    'lastRefreshedAt': lastRefreshedAt.toIso8601String(),
    'metadata': metadata,
  };

  factory DynamicPlaylist.fromJson(Map<String, dynamic> json) {
    return DynamicPlaylist(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      coverArt: json['coverArt']?.toString(),
      tracks: (json['tracks'] as List<dynamic>?)
              ?.map((t) => Song.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      userAddedTrackIds: (json['userAddedTrackIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ??
          {},
      userRemovedTrackIds: (json['userRemovedTrackIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ??
          {},
      version: json['version'] is int ? json['version'] as int : 1,
      lastRefreshedAt: json['lastRefreshedAt'] != null
          ? DateTime.tryParse(json['lastRefreshedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : {},
    );
  }
}

/// Point-in-time snapshot of playlist tracks for version history and rollback.
class PlaylistVersionSnapshot {
  final String playlistId;
  final int version;
  final DateTime timestamp;
  final List<String> trackIds;

  const PlaylistVersionSnapshot({
    required this.playlistId,
    required this.version,
    required this.timestamp,
    required this.trackIds,
  });

  Map<String, dynamic> toJson() => {
    'playlistId': playlistId,
    'version': version,
    'timestamp': timestamp.toIso8601String(),
    'trackIds': trackIds,
  };

  factory PlaylistVersionSnapshot.fromJson(Map<String, dynamic> json) {
    return PlaylistVersionSnapshot(
      playlistId: json['playlistId']?.toString() ?? '',
      version: json['version'] is int ? json['version'] as int : 1,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      trackIds: (json['trackIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
