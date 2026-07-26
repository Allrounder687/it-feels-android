import 'song_model.dart';

class CustomPlaylist {
  final String id;
  String title;
  final DateTime createdAt;
  List<Song> songs;

  CustomPlaylist({
    required this.id,
    required this.title,
    required this.createdAt,
    this.songs = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'songs': songs
          .map((s) => {
                'id': s.id,
                'saavnId': s.saavnId,
                'title': s.title,
                'artist': s.artist,
                'album': s.album,
                'duration': s.duration,
                'coverArt': s.coverArt,
                'encryptedMediaUrl': s.encryptedMediaUrl,
                'hasLyrics': s.hasLyrics,
              })
          .toList(),
    };
  }

  factory CustomPlaylist.fromJson(Map<String, dynamic> json) {
    List<Song> loadedSongs = [];
    if (json['songs'] != null) {
      final List<dynamic> songList = json['songs'];
      loadedSongs = songList.map((item) => Song.fromJson(Map<String, dynamic>.from(item))).toList();
    }

    return CustomPlaylist(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? 'My Playlist',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      songs: loadedSongs,
    );
  }
}
