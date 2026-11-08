import '../intelligence/federation/data_provenance.dart';
import '../intelligence/federation/canonical_contributor.dart';

/// Canonical identity for an album or EP release enriched with editorial,
/// credit, and relational intelligence.
class CanonicalAlbum {
  final String id;
  final String title;
  final String artist;
  final String? coverArt;
  final int? year;
  final String? releaseDate;
  final String? recordLabel;
  final String releaseType; // 'Album', 'Single', 'EP', 'Soundtrack', 'Compilation'
  final int? trackCount;
  final String? albumStory;
  final List<String> canonicalTrackIds;
  final List<CanonicalContributor> credits;
  final List<String> producers;
  final List<String> songwriters;
  final List<String> relatedEditions;
  final Map<String, String> providerIds;
  final DataProvenance? provenance;
  final Map<String, dynamic> metadata;

  const CanonicalAlbum({
    required this.id,
    required this.title,
    required this.artist,
    this.coverArt,
    this.year,
    this.releaseDate,
    this.recordLabel,
    this.releaseType = 'Album',
    this.trackCount,
    this.albumStory,
    this.canonicalTrackIds = const [],
    this.credits = const [],
    this.producers = const [],
    this.songwriters = const [],
    this.relatedEditions = const [],
    this.providerIds = const {},
    this.provenance,
    this.metadata = const {},
  });

  CanonicalAlbum copyWith({
    String? id,
    String? title,
    String? artist,
    String? coverArt,
    int? year,
    String? releaseDate,
    String? recordLabel,
    String? releaseType,
    int? trackCount,
    String? albumStory,
    List<String>? canonicalTrackIds,
    List<CanonicalContributor>? credits,
    List<String>? producers,
    List<String>? songwriters,
    List<String>? relatedEditions,
    Map<String, String>? providerIds,
    DataProvenance? provenance,
    Map<String, dynamic>? metadata,
  }) {
    return CanonicalAlbum(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      coverArt: coverArt ?? this.coverArt,
      year: year ?? this.year,
      releaseDate: releaseDate ?? this.releaseDate,
      recordLabel: recordLabel ?? this.recordLabel,
      releaseType: releaseType ?? this.releaseType,
      trackCount: trackCount ?? this.trackCount,
      albumStory: albumStory ?? this.albumStory,
      canonicalTrackIds: canonicalTrackIds ?? this.canonicalTrackIds,
      credits: credits ?? this.credits,
      producers: producers ?? this.producers,
      songwriters: songwriters ?? this.songwriters,
      relatedEditions: relatedEditions ?? this.relatedEditions,
      providerIds: providerIds ?? this.providerIds,
      provenance: provenance ?? this.provenance,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'coverArt': coverArt,
    'year': year,
    'releaseDate': releaseDate,
    'recordLabel': recordLabel,
    'releaseType': releaseType,
    'trackCount': trackCount,
    'albumStory': albumStory,
    'canonicalTrackIds': canonicalTrackIds,
    'credits': credits.map((c) => c.toJson()).toList(),
    'producers': producers,
    'songwriters': songwriters,
    'relatedEditions': relatedEditions,
    'providerIds': providerIds,
    if (provenance != null) 'provenance': provenance!.toJson(),
    'metadata': metadata,
  };

  factory CanonicalAlbum.fromJson(Map<String, dynamic> json) {
    return CanonicalAlbum(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      coverArt: json['coverArt']?.toString(),
      year: json['year'] is int ? json['year'] as int : null,
      releaseDate: json['releaseDate']?.toString(),
      recordLabel: json['recordLabel']?.toString(),
      releaseType: json['releaseType']?.toString() ?? 'Album',
      trackCount: json['trackCount'] is int ? json['trackCount'] as int : null,
      albumStory: json['albumStory']?.toString(),
      canonicalTrackIds: (json['canonicalTrackIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      credits: (json['credits'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map((c) => CanonicalContributor.fromJson(c))
              .toList() ??
          [],
      producers: (json['producers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      songwriters: (json['songwriters'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      relatedEditions: (json['relatedEditions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      providerIds: (json['providerIds'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())) ?? {},
      provenance: json['provenance'] is Map<String, dynamic>
          ? DataProvenance.fromJson(json['provenance'] as Map<String, dynamic>)
          : null,
      metadata: json['metadata'] is Map<String, dynamic> ? json['metadata'] as Map<String, dynamic> : {},
    );
  }
}
