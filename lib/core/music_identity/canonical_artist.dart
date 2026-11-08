import '../intelligence/federation/data_provenance.dart';

/// Canonical identity for an artist across multiple catalogues, enriched with
/// authoritative biographical, historical, and relational intelligence.
class CanonicalArtist {
  final String id;
  final String name;
  final String? imageUrl;
  final List<String> genres;
  final Map<String, String> providerIds; // e.g. {'saavn': '123', 'mbid': '...', 'wikidata': 'Q...'}
  final int? monthlyListeners;
  final String? biography;
  final List<String> nativeNames;
  final String? country;
  final String? activeYears;
  final List<String> recordLabels;
  final List<String> collaborators;
  final List<String> influences;
  final List<String> relatedArtists;
  final List<Map<String, dynamic>> timeline;
  final DataProvenance? provenance;
  final Map<String, dynamic> metadata;

  const CanonicalArtist({
    required this.id,
    required this.name,
    this.imageUrl,
    this.genres = const [],
    this.providerIds = const {},
    this.monthlyListeners,
    this.biography,
    this.nativeNames = const [],
    this.country,
    this.activeYears,
    this.recordLabels = const [],
    this.collaborators = const [],
    this.influences = const [],
    this.relatedArtists = const [],
    this.timeline = const [],
    this.provenance,
    this.metadata = const {},
  });

  CanonicalArtist copyWith({
    String? id,
    String? name,
    String? imageUrl,
    List<String>? genres,
    Map<String, String>? providerIds,
    int? monthlyListeners,
    String? biography,
    List<String>? nativeNames,
    String? country,
    String? activeYears,
    List<String>? recordLabels,
    List<String>? collaborators,
    List<String>? influences,
    List<String>? relatedArtists,
    List<Map<String, dynamic>>? timeline,
    DataProvenance? provenance,
    Map<String, dynamic>? metadata,
  }) {
    return CanonicalArtist(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      genres: genres ?? this.genres,
      providerIds: providerIds ?? this.providerIds,
      monthlyListeners: monthlyListeners ?? this.monthlyListeners,
      biography: biography ?? this.biography,
      nativeNames: nativeNames ?? this.nativeNames,
      country: country ?? this.country,
      activeYears: activeYears ?? this.activeYears,
      recordLabels: recordLabels ?? this.recordLabels,
      collaborators: collaborators ?? this.collaborators,
      influences: influences ?? this.influences,
      relatedArtists: relatedArtists ?? this.relatedArtists,
      timeline: timeline ?? this.timeline,
      provenance: provenance ?? this.provenance,
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
    'biography': biography,
    'nativeNames': nativeNames,
    'country': country,
    'activeYears': activeYears,
    'recordLabels': recordLabels,
    'collaborators': collaborators,
    'influences': influences,
    'relatedArtists': relatedArtists,
    'timeline': timeline,
    if (provenance != null) 'provenance': provenance!.toJson(),
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
      biography: json['biography']?.toString(),
      nativeNames: (json['nativeNames'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      country: json['country']?.toString(),
      activeYears: json['activeYears']?.toString(),
      recordLabels: (json['recordLabels'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      collaborators: (json['collaborators'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      influences: (json['influences'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      relatedArtists: (json['relatedArtists'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      timeline: (json['timeline'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [],
      provenance: json['provenance'] is Map<String, dynamic>
          ? DataProvenance.fromJson(json['provenance'] as Map<String, dynamic>)
          : null,
      metadata: json['metadata'] is Map<String, dynamic> ? json['metadata'] as Map<String, dynamic> : {},
    );
  }
}
