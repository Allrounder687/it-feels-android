/// Canonical identity for an album or EP release.
class CanonicalAlbum {
  final String id;
  final String title;
  final String artist;
  final String? coverArt;
  final int? year;
  final int? trackCount;
  final List<String> canonicalTrackIds;
  final Map<String, String> providerIds;
  final Map<String, dynamic> metadata;

  const CanonicalAlbum({
    required this.id,
    required this.title,
    required this.artist,
    this.coverArt,
    this.year,
    this.trackCount,
    this.canonicalTrackIds = const [],
    this.providerIds = const {},
    this.metadata = const {},
  });

  CanonicalAlbum copyWith({
    String? id,
    String? title,
    String? artist,
    String? coverArt,
    int? year,
    int? trackCount,
    List<String>? canonicalTrackIds,
    Map<String, String>? providerIds,
    Map<String, dynamic>? metadata,
  }) {
    return CanonicalAlbum(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      coverArt: coverArt ?? this.coverArt,
      year: year ?? this.year,
      trackCount: trackCount ?? this.trackCount,
      canonicalTrackIds: canonicalTrackIds ?? this.canonicalTrackIds,
      providerIds: providerIds ?? this.providerIds,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'coverArt': coverArt,
    'year': year,
    'trackCount': trackCount,
    'canonicalTrackIds': canonicalTrackIds,
    'providerIds': providerIds,
    'metadata': metadata,
  };

  factory CanonicalAlbum.fromJson(Map<String, dynamic> json) {
    return CanonicalAlbum(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      coverArt: json['coverArt']?.toString(),
      year: json['year'] is int ? json['year'] as int : null,
      trackCount: json['trackCount'] is int ? json['trackCount'] as int : null,
      canonicalTrackIds: (json['canonicalTrackIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      providerIds: (json['providerIds'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())) ?? {},
      metadata: json['metadata'] is Map<String, dynamic> ? json['metadata'] as Map<String, dynamic> : {},
    );
  }
}
