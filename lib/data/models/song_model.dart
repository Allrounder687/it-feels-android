import '../../core/utils/image_utils.dart';
import '../../core/utils/string_utils.dart';

class Song {
  final String id;
  final String saavnId;
  final String title;
  final String artist;
  final String album;
  final int duration; // in seconds
  final String coverArt;
  final String? streamUrl;
  final String? encryptedMediaUrl;
  final bool hasLyrics;

  Song({
    required this.id,
    required this.saavnId,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.coverArt,
    this.streamUrl,
    this.encryptedMediaUrl,
    this.hasLyrics = false,
  });

  static String cleanText(String text) {
    return StringUtils.cleanText(text);
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? json['saavnId']?.toString() ?? '';
    final saavnId = id.contains(':') ? id.split(':').last : id;

    var rawImage = json['image']?.toString() ?? json['coverArt']?.toString() ?? '';
    if (rawImage.isNotEmpty) {
      rawImage = ImageUtils.getSizedCoverArt(rawImage, size: 500);
    }

    String artistName = 'Unknown Artist';
    if (json['more_info'] != null && json['more_info']['artistMap'] != null) {
      final primary = json['more_info']['artistMap']['primary_artists'];
      if (primary is List && primary.isNotEmpty) {
        artistName = primary.map((x) => x['name'] ?? '').where((x) => x.isNotEmpty).join(', ');
      }
    } else if (json['artist'] != null && json['artist'].toString().isNotEmpty) {
      artistName = json['artist'].toString();
    } else if (json['more_info'] != null && json['more_info']['singers'] != null) {
      artistName = json['more_info']['singers'].toString();
    }

    final songTitle = json['title'] ?? json['song'] ?? json['name'] ?? 'Unknown Title';
    final albumTitle = json['album'] ?? (json['more_info'] != null ? json['more_info']['album'] : '') ?? '';
    final durationSec = int.tryParse(json['duration']?.toString() ?? (json['more_info'] != null ? json['more_info']['duration']?.toString() ?? '0' : '0')) ?? 0;
    final encUrl = json['encrypted_media_url'] ?? (json['more_info'] != null ? json['more_info']['encrypted_media_url'] : null);
    final hasLrc = json['more_info'] != null ? (json['more_info']['has_lyrics'] == 'true' || json['more_info']['has_lyrics'] == true) : false;

    return Song(
      id: id.startsWith('saavn:') ? id : 'saavn:$id',
      saavnId: saavnId,
      title: StringUtils.cleanText(songTitle.toString()),
      artist: StringUtils.cleanText(artistName),
      album: StringUtils.cleanText(albumTitle.toString()),
      duration: durationSec,
      coverArt: rawImage,
      encryptedMediaUrl: encUrl,
      hasLyrics: hasLrc,
    );
  }

  Song copyWith({
    String? streamUrl,
    String? coverArt,
  }) {
    return Song(
      id: id,
      saavnId: saavnId,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      coverArt: coverArt ?? this.coverArt,
      streamUrl: streamUrl ?? this.streamUrl,
      encryptedMediaUrl: encryptedMediaUrl,
      hasLyrics: hasLyrics,
    );
  }
}

class Playlist {
  final String id;
  final String title;
  final String coverArt;
  final int songCount;
  final String type; // 'playlist' or 'album'

  Playlist({
    required this.id,
    required this.title,
    required this.coverArt,
    required this.songCount,
    this.type = 'playlist',
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    var rawImage = json['image']?.toString() ?? '';
    if (rawImage.isNotEmpty) {
      rawImage = ImageUtils.getSizedCoverArt(rawImage, size: 500);
    }
    return Playlist(
      id: json['listid']?.toString() ?? json['id']?.toString() ?? '',
      title: StringUtils.cleanText(json['title']?.toString() ?? json['listname']?.toString() ?? json['name']?.toString() ?? 'Playlist'),
      coverArt: rawImage,
      songCount: int.tryParse(json['list_count']?.toString() ?? json['count']?.toString() ?? '0') ?? 0,
      type: json['type']?.toString() ?? 'playlist',
    );
  }
}

class LyricLine {
  final Duration time;
  final String text;

  LyricLine({required this.time, required this.text});
}
