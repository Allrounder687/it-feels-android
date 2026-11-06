import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/utils/track_validation_engine.dart';
import 'package:it_feels_music/core/utils/string_utils.dart';

/// Provenance and locator reference for a track on an external or local provider.
class ProviderTrackRef {
  final String provider; // e.g. 'saavn', 'spotify', 'youtube', 'local'
  final String providerTrackId;
  final String? streamUrl;
  final String? encryptedMediaUrl;
  final int? bitrate;
  final DateTime lastVerifiedAt;
  final Map<String, dynamic> rawMetadata;

  const ProviderTrackRef({
    required this.provider,
    required this.providerTrackId,
    this.streamUrl,
    this.encryptedMediaUrl,
    this.bitrate,
    required this.lastVerifiedAt,
    this.rawMetadata = const {},
  });

  bool get isPlayable => streamUrl != null && streamUrl!.trim().isNotEmpty;

  ProviderTrackRef copyWith({
    String? provider,
    String? providerTrackId,
    String? streamUrl,
    String? encryptedMediaUrl,
    int? bitrate,
    DateTime? lastVerifiedAt,
    Map<String, dynamic>? rawMetadata,
  }) {
    return ProviderTrackRef(
      provider: provider ?? this.provider,
      providerTrackId: providerTrackId ?? this.providerTrackId,
      streamUrl: streamUrl ?? this.streamUrl,
      encryptedMediaUrl: encryptedMediaUrl ?? this.encryptedMediaUrl,
      bitrate: bitrate ?? this.bitrate,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      rawMetadata: rawMetadata ?? this.rawMetadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'providerTrackId': providerTrackId,
    'streamUrl': streamUrl,
    'encryptedMediaUrl': encryptedMediaUrl,
    'bitrate': bitrate,
    'lastVerifiedAt': lastVerifiedAt.toIso8601String(),
    'rawMetadata': rawMetadata,
  };

  factory ProviderTrackRef.fromJson(Map<String, dynamic> json) {
    return ProviderTrackRef(
      provider: json['provider']?.toString() ?? 'saavn',
      providerTrackId: json['providerTrackId']?.toString() ?? '',
      streamUrl: json['streamUrl']?.toString(),
      encryptedMediaUrl: json['encryptedMediaUrl']?.toString(),
      bitrate: json['bitrate'] is int ? json['bitrate'] as int : null,
      lastVerifiedAt: json['lastVerifiedAt'] != null
          ? DateTime.tryParse(json['lastVerifiedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      rawMetadata: json['rawMetadata'] is Map<String, dynamic>
          ? json['rawMetadata'] as Map<String, dynamic>
          : {},
    );
  }
}

/// Resolved playback candidate with TTL caching to guard against expired CDN tokens.
class PlaybackCandidate {
  final CanonicalTrack track;
  final ProviderTrackRef providerRef;
  final String streamUrl;
  final Duration ttl;
  final DateTime resolvedAt;

  PlaybackCandidate({
    required this.track,
    required this.providerRef,
    required this.streamUrl,
    this.ttl = const Duration(hours: 4),
    DateTime? resolvedAt,
  }) : resolvedAt = resolvedAt ?? DateTime.now();

  bool get isExpired => DateTime.now().isAfter(resolvedAt.add(ttl));

  Map<String, dynamic> toJson() => {
    'track': track.toJson(),
    'providerRef': providerRef.toJson(),
    'streamUrl': streamUrl,
    'ttlMs': ttl.inMilliseconds,
    'resolvedAt': resolvedAt.toIso8601String(),
  };

  factory PlaybackCandidate.fromJson(Map<String, dynamic> json) {
    return PlaybackCandidate(
      track: CanonicalTrack.fromJson(json['track'] as Map<String, dynamic>),
      providerRef: ProviderTrackRef.fromJson(json['providerRef'] as Map<String, dynamic>),
      streamUrl: json['streamUrl']?.toString() ?? '',
      ttl: Duration(milliseconds: json['ttlMs'] is int ? json['ttlMs'] as int : 14400000),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Immutable, decoupled canonical identity for a musical track across multiple sources.
class CanonicalTrack {
  final String id;
  final String title;
  final String artist;
  final List<String> artists;
  final String album;
  final int duration; // in seconds
  final String coverArt;
  final String? isrc;
  final List<ProviderTrackRef> providerRefs;
  final String genre;
  final int year;
  final String language;
  final bool isExplicit;
  final bool hasLyrics;
  final DateTime addedAt;
  final Map<String, dynamic> metadata;

  const CanonicalTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.artists = const [],
    required this.album,
    required this.duration,
    required this.coverArt,
    this.isrc,
    this.providerRefs = const [],
    this.genre = 'Unknown',
    this.year = 2024,
    this.language = 'unknown',
    this.isExplicit = false,
    this.hasLyrics = false,
    required this.addedAt,
    this.metadata = const {},
  });

  /// Canonical normalized key for deduplication and acoustic matching.
  String get normalizedKey => TrackValidationEngine.normalizeTrackKey(title, artist);

  /// Whether at least one provider reference possesses a playable stream.
  bool get hasPlayableSource => providerRefs.any((ref) => ref.isPlayable);

  /// Primary provider reference.
  ProviderTrackRef? get primaryRef => providerRefs.isNotEmpty ? providerRefs.first : null;

  /// Deterministically creates a canonical track ID from clean metadata.
  static String generateDeterministicId(String title, String artist, {String? isrc}) {
    if (isrc != null && isrc.trim().isNotEmpty) {
      return 'isrc:${isrc.trim().toUpperCase()}';
    }
    final key = TrackValidationEngine.normalizeTrackKey(title, artist);
    final bytes = utf8.encode(key);
    final hash = sha256.convert(bytes).toString().substring(0, 16);
    return 'ct_$hash';
  }

  /// Converts existing Song model into CanonicalTrack preserving all metadata and references.
  factory CanonicalTrack.fromSong(Song song, {String provider = 'saavn'}) {
    final cleanTitle = StringUtils.cleanText(song.title);
    final cleanArtist = StringUtils.cleanText(song.artist);
    final cleanAlbum = StringUtils.cleanText(song.album);
    final canonId = generateDeterministicId(cleanTitle, cleanArtist);

    final artistList = cleanArtist
        .split(RegExp(r'[,&/]'))
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();

    final ref = ProviderTrackRef(
      provider: provider,
      providerTrackId: song.id,
      streamUrl: song.streamUrl,
      encryptedMediaUrl: song.encryptedMediaUrl,
      lastVerifiedAt: DateTime.now(),
      rawMetadata: {
        'saavnId': song.saavnId,
        'genre': song.genre,
        'year': song.year,
        'language': song.language,
        'isExplicit': song.isExplicit,
      },
    );

    return CanonicalTrack(
      id: canonId,
      title: cleanTitle,
      artist: cleanArtist,
      artists: artistList.isNotEmpty ? artistList : [cleanArtist],
      album: cleanAlbum,
      duration: song.duration,
      coverArt: song.coverArt,
      providerRefs: [ref],
      genre: song.genre,
      year: song.year,
      language: song.language,
      isExplicit: song.isExplicit,
      hasLyrics: song.hasLyrics,
      addedAt: song.addedAt,
      metadata: {
        'playCount': song.playCount,
        'skipCount': song.skipCount,
        'isFavorite': song.isFavorite,
        'localFilePath': song.localFilePath,
      },
    );
  }

  /// Converts this canonical track into a legacy Song model for downstream player execution.
  Song toSong({String? preferredProvider}) {
    ProviderTrackRef? selectedRef;
    if (preferredProvider != null) {
      for (final ref in providerRefs) {
        if (ref.provider == preferredProvider) {
          selectedRef = ref;
          break;
        }
      }
    }
    selectedRef ??= primaryRef;

    final providerId = selectedRef?.providerTrackId ?? id;
    final saavnId = providerId.contains(':') ? providerId.split(':').last : providerId;

    return Song(
      id: providerId,
      saavnId: saavnId,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      coverArt: coverArt,
      streamUrl: selectedRef?.streamUrl,
      encryptedMediaUrl: selectedRef?.encryptedMediaUrl,
      hasLyrics: hasLyrics,
      genre: genre,
      year: year,
      language: language,
      isExplicit: isExplicit,
      addedAt: addedAt,
      isFavorite: metadata['isFavorite'] == true,
      localFilePath: metadata['localFilePath']?.toString(),
    );
  }

  CanonicalTrack copyWith({
    String? id,
    String? title,
    String? artist,
    List<String>? artists,
    String? album,
    int? duration,
    String? coverArt,
    String? isrc,
    List<ProviderTrackRef>? providerRefs,
    String? genre,
    int? year,
    String? language,
    bool? isExplicit,
    bool? hasLyrics,
    DateTime? addedAt,
    Map<String, dynamic>? metadata,
  }) {
    return CanonicalTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      artists: artists ?? this.artists,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      coverArt: coverArt ?? this.coverArt,
      isrc: isrc ?? this.isrc,
      providerRefs: providerRefs ?? this.providerRefs,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      language: language ?? this.language,
      isExplicit: isExplicit ?? this.isExplicit,
      hasLyrics: hasLyrics ?? this.hasLyrics,
      addedAt: addedAt ?? this.addedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'artists': artists,
    'album': album,
    'duration': duration,
    'coverArt': coverArt,
    'isrc': isrc,
    'providerRefs': providerRefs.map((r) => r.toJson()).toList(),
    'genre': genre,
    'year': year,
    'language': language,
    'isExplicit': isExplicit,
    'hasLyrics': hasLyrics,
    'addedAt': addedAt.toIso8601String(),
    'metadata': metadata,
  };

  factory CanonicalTrack.fromJson(Map<String, dynamic> json) {
    return CanonicalTrack(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      artists: (json['artists'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      album: json['album']?.toString() ?? '',
      duration: json['duration'] is int ? json['duration'] as int : 0,
      coverArt: json['coverArt']?.toString() ?? '',
      isrc: json['isrc']?.toString(),
      providerRefs: (json['providerRefs'] as List<dynamic>?)
              ?.map((r) => ProviderTrackRef.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      genre: json['genre']?.toString() ?? 'Unknown',
      year: json['year'] is int ? json['year'] as int : 2024,
      language: json['language']?.toString() ?? 'unknown',
      isExplicit: json['isExplicit'] == true,
      hasLyrics: json['hasLyrics'] == true,
      addedAt: json['addedAt'] != null
          ? DateTime.tryParse(json['addedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : {},
    );
  }
}
