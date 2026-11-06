/// Canonical identity for an artist across multiple catalogues.
class CanonicalArtist {
  final String id;
  final String name;
  final String? imageUrl;
  final List<String> genres;
  final Map<String, String> providerIds;
  final int? monthlyListeners;
  final Map<String, dynamic> metadata;

  const CanonicalArtist({
    required this.id,
    required this.name,
    this.imageUrl,
    this.genres = const [],
    this.providerIds = const {},
    this.monthlyListeners,
    this.metadata = const {},
  });

  CanonicalArtist copyWith({
    String? id,
    String? name,
    String? imageUrl,
    List<String>? genres,
    Map<String, String>? providerIds,
    int? monthlyListeners,
    Map<String, dynamic>? metadata,
  }) {
    return CanonicalArtist(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      genres: genres ?? this.genres,
      providerIds: providerIds ?? this.providerIds,
      monthlyListeners: monthlyListeners ?? this.monthlyListeners,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'imageUrl': imageUrl,
    'genres': genres,
    'providerIds': providerIds,
    'monthlyListeners': monthlyListeners,
    'metadata': metadata,
  };

  factory CanonicalArtist.fromJson(Map<String, dynamic> json) {
    return CanonicalArtist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString(),
      genres: (json['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      providerIds: (json['providerIds'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())) ?? {},
      monthlyListeners: json['monthlyListeners'] is int ? json['monthlyListeners'] as int : null,
      metadata: json['metadata'] is Map<String, dynamic> ? json['metadata'] as Map<String, dynamic> : {},
    );
  }
}
