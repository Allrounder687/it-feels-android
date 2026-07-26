import 'package:isar/isar.dart';
import '../../core/utils/image_utils.dart';
import '../../core/utils/string_utils.dart';

part 'song_model.g.dart';

@collection
class Song {
  Id isarId = Isar.autoIncrement; // Isar internal ID
  
  @Index(unique: true, replace: true)
  String id; // Usually Saavn ID
  
  String saavnId;
  String title;
  String artist;
  String album;
  int duration; // in seconds
  String coverArt;
  String? streamUrl;
  String? encryptedMediaUrl;
  bool hasLyrics;

  // --- NEW FIELDS FOR RICH METADATA & ISAR SEARCH ---
  
  // Deep/Regional Metadata
  String genre;
  int year;
  String language;
  bool isExplicit;
  
  // Behavioral & Engagement Data
  int playCount;
  int skipCount;
  DateTime? lastPlayedAt;
  DateTime addedAt;
  bool isFavorite;
  
  // Hybrid Architecture State
  String? localFilePath;
  @enumerated
  OfflineStatus offlineStatus;
  
  // Advanced Search Vector (FTS)
  @Index(type: IndexType.value)
  List<String> searchVector; 

  Song({
    this.isarId = Isar.autoIncrement,
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
    this.genre = 'Unknown',
    this.year = 2024,
    this.language = 'unknown',
    this.isExplicit = false,
    this.playCount = 0,
    this.skipCount = 0,
    this.lastPlayedAt,
    required this.addedAt,
    this.isFavorite = false,
    this.localFilePath,
    this.offlineStatus = OfflineStatus.none,
    this.searchVector = const [],
  });

  static String cleanText(String text) {
    return StringUtils.cleanText(text);
  }

  // Generates the words array for Isar FTS
  static List<String> generateSearchVector(String title, String artist, String album) {
    final combined = '$title $artist $album'.toLowerCase();
    // Remove special characters
    final cleaned = combined.replaceAll(RegExp(r'[^a-z0-9\s]'), '');
    // Ignore small common words for better search efficiency
    final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty && w != 'the' && w != 'a' && w != 'an').toList();
    return words.toSet().toList(); // Unique words
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
    
    final cleanTitle = StringUtils.cleanText(songTitle.toString());
    final cleanArtist = StringUtils.cleanText(artistName);
    final cleanAlbum = StringUtils.cleanText(albumTitle.toString());

    return Song(
      id: id.startsWith('saavn:') ? id : 'saavn:$id',
      saavnId: saavnId,
      title: cleanTitle,
      artist: cleanArtist,
      album: cleanAlbum,
      duration: durationSec,
      coverArt: rawImage,
      encryptedMediaUrl: encUrl,
      hasLyrics: hasLrc,
      language: json['language']?.toString() ?? (json['more_info'] != null ? json['more_info']['language'] : 'unknown'),
      year: int.tryParse(json['year']?.toString() ?? '2024') ?? 2024,
      isExplicit: json['explicit_content'] == '1' || json['explicit_content'] == 1,
      addedAt: DateTime.now(),
      searchVector: generateSearchVector(cleanTitle, cleanArtist, cleanAlbum),
    );
  }

  Song copyWith({
    String? streamUrl,
    String? coverArt,
    String? localFilePath,
    OfflineStatus? offlineStatus,
    int? playCount,
    bool? isFavorite,
    DateTime? lastPlayedAt,
  }) {
    return Song(
      isarId: isarId,
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
      genre: genre,
      year: year,
      language: language,
      isExplicit: isExplicit,
      playCount: playCount ?? this.playCount,
      skipCount: skipCount,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      addedAt: addedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      localFilePath: localFilePath ?? this.localFilePath,
      offlineStatus: offlineStatus ?? this.offlineStatus,
      searchVector: searchVector,
    );
  }
}

enum OfflineStatus { none, downloading, downloaded }

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
