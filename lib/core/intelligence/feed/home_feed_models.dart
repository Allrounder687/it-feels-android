import 'package:it_feels_music/data/models/song_model.dart';

/// The 18 standardized dynamic feed section types supported by the Next-Gen Feed Engine.
enum FeedSectionType {
  featured,
  quickPicks,
  continueListening,
  dailyMix,
  playlistCarousel,
  discoverWeekly,
  releaseRadar,
  trackList,
  artistCarousel,
  albumCarousel,
  moodGrid,
  genreCollection,
  songRadio,
  personalizedDiscovery,
  forgottenFavorites,
  trending,
  aiPlaylistPrompt,
  recentlyAdded,
}

/// Generic feed item model encapsulating tracks, playlists, albums, artists, or interactive prompt capsules.
class FeedItem {
  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String itemType; // 'track', 'playlist', 'album', 'artist', 'action'
  final Song? song;
  final Playlist? playlist;
  final Map<String, dynamic> customData;

  const FeedItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    required this.itemType,
    this.song,
    this.playlist,
    this.customData = const {},
  });

  /// Factory for a track feed item.
  factory FeedItem.fromSong(Song song, {String? subtitle}) {
    return FeedItem(
      id: song.id,
      title: song.title,
      subtitle: subtitle ?? song.artist,
      imageUrl: song.coverArt,
      itemType: 'track',
      song: song,
    );
  }

  /// Factory for a playlist feed item.
  factory FeedItem.fromPlaylist(Playlist playlist, {String? customSubtitle}) {
    return FeedItem(
      id: playlist.id,
      title: playlist.title,
      subtitle: customSubtitle ?? playlist.subtitle,
      imageUrl: playlist.image,
      itemType: 'playlist',
      playlist: playlist,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'imageUrl': imageUrl,
    'itemType': itemType,
    'song': song?.toJson(),
    'playlist': playlist?.toJson(),
    'customData': customData,
  };

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      itemType: json['itemType']?.toString() ?? 'track',
      song: json['song'] is Map<String, dynamic>
          ? Song.fromJson(json['song'] as Map<String, dynamic>)
          : null,
      playlist: json['playlist'] is Map<String, dynamic>
          ? Playlist.fromJson(json['playlist'] as Map<String, dynamic>)
          : null,
      customData: json['customData'] is Map<String, dynamic>
          ? json['customData'] as Map<String, dynamic>
          : {},
    );
  }
}

/// A composable, data-driven section in the personalized home feed.
class HomeFeedSection {
  final String id;
  final FeedSectionType sectionType;
  final String title;
  final String? subtitle;
  final List<FeedItem> items;
  final int priority;
  final bool isPersonalized;
  final Map<String, dynamic> metadata;

  const HomeFeedSection({
    required this.id,
    required this.sectionType,
    required this.title,
    this.subtitle,
    required this.items,
    this.priority = 100,
    this.isPersonalized = false,
    this.metadata = const {},
  });

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  HomeFeedSection copyWith({
    String? id,
    FeedSectionType? sectionType,
    String? title,
    String? subtitle,
    List<FeedItem>? items,
    int? priority,
    bool? isPersonalized,
    Map<String, dynamic>? metadata,
  }) {
    return HomeFeedSection(
      id: id ?? this.id,
      sectionType: sectionType ?? this.sectionType,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      items: items ?? this.items,
      priority: priority ?? this.priority,
      isPersonalized: isPersonalized ?? this.isPersonalized,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sectionType': sectionType.name,
    'title': title,
    'subtitle': subtitle,
    'items': items.map((i) => i.toJson()).toList(),
    'priority': priority,
    'isPersonalized': isPersonalized,
    'metadata': metadata,
  };

  factory HomeFeedSection.fromJson(Map<String, dynamic> json) {
    return HomeFeedSection(
      id: json['id']?.toString() ?? '',
      sectionType: FeedSectionType.values.firstWhere(
        (e) => e.name == json['sectionType'],
        orElse: () => FeedSectionType.trackList,
      ),
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      items: (json['items'] as List<dynamic>?)
              ?.map((i) => FeedItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      priority: json['priority'] is int ? json['priority'] as int : 100,
      isPersonalized: json['isPersonalized'] == true,
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : {},
    );
  }
}

/// Complete personalized Home Feed snapshot.
class HomeFeed {
  final String version;
  final DateTime generatedAt;
  final List<HomeFeedSection> sections;
  final bool isFromCache;
  final Map<String, dynamic> metadata;

  const HomeFeed({
    this.version = '1.0.0',
    required this.generatedAt,
    required this.sections,
    this.isFromCache = false,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'generatedAt': generatedAt.toIso8601String(),
    'sections': sections.map((s) => s.toJson()).toList(),
    'isFromCache': isFromCache,
    'metadata': metadata,
  };

  factory HomeFeed.fromJson(Map<String, dynamic> json) {
    return HomeFeed(
      version: json['version']?.toString() ?? '1.0.0',
      generatedAt: json['generatedAt'] != null
          ? DateTime.tryParse(json['generatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      sections: (json['sections'] as List<dynamic>?)
              ?.map((s) => HomeFeedSection.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      isFromCache: json['isFromCache'] == true,
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : {},
    );
  }
}
