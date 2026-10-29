import 'package:isar/isar.dart';
import 'package:it_feels_music/core/utils/image_utils.dart';
import 'package:it_feels_music/core/utils/string_utils.dart';

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
  int? playbackPositionMs; // To track exact playback timestamp
  DateTime? lastPlayedAt;
  DateTime addedAt;
  bool isFavorite;
  
  // Hybrid Architecture State
  String? localFilePath;
  @enumerated
  OfflineStatus offlineStatus;
  
  // Sync Pipeline State
  bool isDirty;
  
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
    this.playbackPositionMs,
    this.lastPlayedAt,
    required this.addedAt,
    this.isFavorite = false,
    this.localFilePath,
    this.offlineStatus = OfflineStatus.none,
    this.searchVector = const [],
    this.isDirty = false,
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

    String artistName = '';
    
    if (json['more_info'] != null && json['more_info']['artistMap'] != null) {
      final primary = json['more_info']['artistMap']['primary_artists'];
      if (primary is List && primary.isNotEmpty) {
        artistName = primary.map((x) => x['name'] ?? '').where((x) => x.isNotEmpty).join(', ');
      } else if (primary is String && primary.isNotEmpty) {
        artistName = primary;
      }
      if (artistName.isEmpty) {
        final allArtists = json['more_info']['artistMap']['artists'];
        if (allArtists is List && allArtists.isNotEmpty) {
          artistName = allArtists.map((x) => x['name'] ?? '').where((x) => x.isNotEmpty).join(', ');
        }
      }
    }
    if (artistName.isEmpty && json['more_info'] != null && json['more_info']['singers'] != null && json['more_info']['singers'].toString().trim().isNotEmpty) {
      artistName = json['more_info']['singers'].toString().trim();
    }
    if (artistName.isEmpty && json['artist'] != null && json['artist'].toString().trim().isNotEmpty) {
      artistName = json['artist'].toString().trim();
    }
    if (artistName.isEmpty && json['subtitle'] != null && json['subtitle'].toString().trim().isNotEmpty) {
      final sub = json['subtitle'].toString().trim();
      artistName = sub.contains(' - ') ? sub.split(' - ').first.trim() : sub;
    }

    if (artistName.isEmpty || artistName == 'null') {
      artistName = 'Unknown Artist';
    }

    final songTitle = json['title'] ?? json['song'] ?? json['name'] ?? 'Unknown Title';
    final albumTitle = json['album'] ?? (json['more_info'] != null ? json['more_info']['album'] : '') ?? '';
    final durationSec = int.tryParse(json['duration']?.toString() ?? (json['more_info'] != null ? json['more_info']['duration']?.toString() ?? '0' : '0')) ?? 0;
    
    // Fix: Handle both snake_case (API) and camelCase (Local Cache / Isar)
    final encUrl = json['encryptedMediaUrl'] ?? json['encrypted_media_url'] ?? (json['more_info'] != null ? json['more_info']['encrypted_media_url'] : null);
    
    // Fix: Handle hasLyrics from cache
    bool hasLrc = false;
    if (json.containsKey('hasLyrics')) {
      hasLrc = json['hasLyrics'] == true || json['hasLyrics'] == 'true';
    } else if (json['more_info'] != null) {
      hasLrc = (json['more_info']['has_lyrics'] == 'true' || json['more_info']['has_lyrics'] == true);
    }
    
    final cleanTitle = StringUtils.cleanText(songTitle.toString());
    final cleanArtist = StringUtils.cleanText(artistName);
    final cleanAlbum = StringUtils.cleanText(albumTitle.toString());

    return Song(
      id: (id.startsWith('saavn:') || id.startsWith('youtube:')) ? id : 'saavn:$id',
      saavnId: saavnId,
      title: cleanTitle,
      artist: cleanArtist,
      album: cleanAlbum,
      duration: durationSec,
      coverArt: rawImage,
      encryptedMediaUrl: encUrl,
      hasLyrics: hasLrc,
      language: json['language']?.toString() ?? (json['more_info'] != null ? json['more_info']['language']?.toString() : null) ?? 'unknown',
      year: int.tryParse(json['year']?.toString() ?? '2024') ?? 2024,
      isExplicit: json['explicit_content'] == '1' || json['explicit_content'] == 1,
      addedAt: DateTime.now(),
      searchVector: generateSearchVector(cleanTitle, cleanArtist, cleanAlbum),
      isDirty: false,
    );
  }

  Song copyWith({
    String? id,
    String? saavnId,
    String? title,
    String? artist,
    String? album,
    int? duration,
    String? streamUrl,
    String? coverArt,
    String? encryptedMediaUrl,
    bool? hasLyrics,
    String? genre,
    int? year,
    String? language,
    bool? isExplicit,
    String? localFilePath,
    OfflineStatus? offlineStatus,
    int? playCount,
    int? skipCount,
    int? playbackPositionMs,
    bool? isFavorite,
    DateTime? lastPlayedAt,
    bool? isDirty,
  }) {
    return Song(
      isarId: isarId,
      id: id ?? this.id,
      saavnId: saavnId ?? this.saavnId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      coverArt: coverArt ?? this.coverArt,
      streamUrl: streamUrl ?? this.streamUrl,
      encryptedMediaUrl: encryptedMediaUrl ?? this.encryptedMediaUrl,
      hasLyrics: hasLyrics ?? this.hasLyrics,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      language: language ?? this.language,
      isExplicit: isExplicit ?? this.isExplicit,
      playCount: playCount ?? this.playCount,
      skipCount: skipCount ?? this.skipCount,
      playbackPositionMs: playbackPositionMs ?? this.playbackPositionMs,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      addedAt: addedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      localFilePath: localFilePath ?? this.localFilePath,
      offlineStatus: offlineStatus ?? this.offlineStatus,
      searchVector: searchVector,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'saavnId': saavnId,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      'coverArt': coverArt,
      'streamUrl': streamUrl,
      'encryptedMediaUrl': encryptedMediaUrl,
      'hasLyrics': hasLyrics,
      'genre': genre,
      'year': year,
      'language': language,
      'isExplicit': isExplicit,
      'playCount': playCount,
      'skipCount': skipCount,
      'playbackPositionMs': playbackPositionMs,
      'lastPlayedAt': lastPlayedAt?.toIso8601String(),
      'addedAt': addedAt.toIso8601String(),
      'isFavorite': isFavorite,
      'localFilePath': localFilePath,
      'offlineStatus': offlineStatus.index,
      'isDirty': isDirty,
    };
  }
}

enum OfflineStatus { none, downloading, downloaded }

class Playlist {
  final String id;
  final String title;
  final String coverArt;
  final int songCount;
  final String type; // 'playlist' or 'album'
  final List<Song>? songs;
  final String? followerCount;

  Playlist({
    required this.id,
    required this.title,
    required this.coverArt,
    required this.songCount,
    this.type = 'playlist',
    this.songs,
    this.followerCount,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    var rawImage = json['image']?.toString() ?? '';
    if (rawImage.isNotEmpty) {
      rawImage = ImageUtils.getSizedCoverArt(rawImage, size: 500);
    }
    
    String? parsedFollowerCount;
    final fc = json['follower_count'] ?? json['fan_count'] ?? json['play_count'] ?? (json['more_info'] != null ? (json['more_info']['follower_count'] ?? json['more_info']['fan_count']) : null);
    if (fc != null && fc.toString().isNotEmpty) {
      try {
        final double count = double.parse(fc.toString().replaceAll(',', ''));
        if (count >= 1000000) {
          parsedFollowerCount = '${(count / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}M';
        } else if (count >= 1000) {
          parsedFollowerCount = '${(count / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}K';
        } else {
          parsedFollowerCount = count.toInt().toString();
        }
      } catch (e) {
        parsedFollowerCount = fc.toString();
      }
    }

    return Playlist(
      id: json['listid']?.toString() ?? json['id']?.toString() ?? '',
      title: StringUtils.cleanText(json['title']?.toString() ?? json['listname']?.toString() ?? json['name']?.toString() ?? 'Playlist'),
      coverArt: rawImage,
      songCount: int.tryParse(json['list_count']?.toString() ?? json['count']?.toString() ?? '0') ?? 0,
      type: json['type']?.toString() ?? 'playlist',
      followerCount: parsedFollowerCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'image': coverArt,
    'count': songCount,
    'type': type,
    'follower_count': followerCount,
  };
}

class LyricLine {
  final Duration time;
  final String text;
  final String? translation;
  final String? transliteration;

  LyricLine({required this.time, required this.text, this.translation, this.transliteration});

  Map<String, dynamic> toJson() => {
    'timeMs': time.inMilliseconds,
    'text': text,
    'translation': translation,
    'transliteration': transliteration,
  };

  factory LyricLine.fromJson(Map<String, dynamic> json) => LyricLine(
    time: Duration(milliseconds: json['timeMs'] as int),
    text: json['text'] as String,
    translation: json['translation'] as String?,
    transliteration: json['transliteration'] as String?,
  );
}
