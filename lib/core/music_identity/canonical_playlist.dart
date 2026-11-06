/// Canonical identity for a curated, dynamic, or user-created playlist.
class CanonicalPlaylist {
  final String id;
  final String title;
  final String? subtitle;
  final String? description;
  final String? coverArt;
  final List<String> canonicalTrackIds;
  final int version;
  final bool isDynamic;
  final DateTime lastRefreshedAt;
  final Map<String, dynamic> metadata;

  const CanonicalPlaylist({
    required this.id,
    required this.title,
    this.subtitle,
    this.description,
    this.coverArt,
    this.canonicalTrackIds = const [],
    this.version = 1,
    this.isDynamic = false,
    required this.lastRefreshedAt,
    this.metadata = const {},
  });

  int get trackCount => canonicalTrackIds.length;

  CanonicalPlaylist copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? description,
    String? coverArt,
    List<String>? canonicalTrackIds,
    int? version,
    bool? isDynamic,
    DateTime? lastRefreshedAt,
    Map<String, dynamic>? metadata,
  }) {
    return CanonicalPlaylist(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      coverArt: coverArt ?? this.coverArt,
      canonicalTrackIds: canonicalTrackIds ?? this.canonicalTrackIds,
      version: version ?? this.version,
      isDynamic: isDynamic ?? this.isDynamic,
      lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'description': description,
    'coverArt': coverArt,
    'canonicalTrackIds': canonicalTrackIds,
    'version': version,
    'isDynamic': isDynamic,
    'lastRefreshedAt': lastRefreshedAt.toIso8601String(),
    'metadata': metadata,
  };

  factory CanonicalPlaylist.fromJson(Map<String, dynamic> json) {
    return CanonicalPlaylist(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      description: json['description']?.toString(),
      coverArt: json['coverArt']?.toString(),
      canonicalTrackIds: (json['canonicalTrackIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      version: json['version'] is int ? json['version'] as int : 1,
      isDynamic: json['isDynamic'] == true,
      lastRefreshedAt: json['lastRefreshedAt'] != null
          ? DateTime.tryParse(json['lastRefreshedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      metadata: json['metadata'] is Map<String, dynamic> ? json['metadata'] as Map<String, dynamic> : {},
    );
  }
}
