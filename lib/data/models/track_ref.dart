import 'package:it_feels_music/data/models/song_model.dart';

class TrackRef {
  final String spotifyId;
  final String? saavnId;
  final String? youtubeId;
  final String title;
  final List<String> artists;
  final String album;
  final String albumArtUrl;
  final int durationMs;

  TrackRef({
    required this.spotifyId,
    this.saavnId,
    this.youtubeId,
    required this.title,
    required this.artists,
    required this.album,
    required this.albumArtUrl,
    required this.durationMs,
  });

  factory TrackRef.fromJson(Map<String, dynamic> json) {
    // Basic mapping from Spotify Track Object
    final String id = json['id'] ?? '';
    final String name = json['name'] ?? 'Unknown Title';
    
    final List<String> artistNames = [];
    if (json['artists'] != null) {
      for (var artist in json['artists']) {
        if (artist['name'] != null) {
          artistNames.add(artist['name']);
        }
      }
    }

    String albumName = 'Unknown Album';
    String imageUrl = '';
    
    if (json['album'] != null) {
      albumName = json['album']['name'] ?? 'Unknown Album';
      if (json['album']['images'] != null && (json['album']['images'] as List).isNotEmpty) {
        // Typically the first image is the largest
        imageUrl = json['album']['images'][0]['url'] ?? '';
      }
    }

    return TrackRef(
      spotifyId: id,
      title: name,
      artists: artistNames.isNotEmpty ? artistNames : ['Unknown Artist'],
      album: albumName,
      albumArtUrl: imageUrl,
      durationMs: json['duration_ms'] ?? 0,
    );
  }

  // Adapter to convert TrackRef to the existing Song model for player UI compatibility
  Song toSong() {
    return Song(
      id: 'spotify:$spotifyId',
      saavnId: saavnId ?? spotifyId,
      title: Song.cleanText(title),
      artist: Song.cleanText(artists.join(', ')),
      album: Song.cleanText(album),
      duration: (durationMs / 1000).round(),
      coverArt: albumArtUrl,
      addedAt: DateTime.now(),
      searchVector: Song.generateSearchVector(
        Song.cleanText(title),
        Song.cleanText(artists.join(' ')),
        Song.cleanText(album),
      ),
    );
  }
}
