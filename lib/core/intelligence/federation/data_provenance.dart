/// Data Provenance metadata tracking the exact origin, confidence level,
/// licensing terms, and verification timestamp of enriched music data.
class DataProvenance {
  final String provider; // e.g. 'musicbrainz', 'wikidata', 'lastfm', 'coverartarchive', 'listenbrainz', 'lrclib', 'saavn'
  final String sourceId; // e.g. MBID, QID, PID
  final DateTime retrievedAt;
  final double confidence; // 0.0 to 1.0
  final String attribution;
  final String license; // e.g. 'CC0 1.0', 'CC BY-NC-SA 4.0', 'ODbL', 'Proprietary API'
  final String? sourceUrl;
  final Duration refreshTtl;

  const DataProvenance({
    required this.provider,
    required this.sourceId,
    required this.retrievedAt,
    this.confidence = 1.0,
    required this.attribution,
    this.license = 'Open Access',
    this.sourceUrl,
    this.refreshTtl = const Duration(days: 7),
  });

  bool get isExpired => DateTime.now().isAfter(retrievedAt.add(refreshTtl));

  DataProvenance copyWith({
    String? provider,
    String? sourceId,
    DateTime? retrievedAt,
    double? confidence,
    String? attribution,
    String? license,
    String? sourceUrl,
    Duration? refreshTtl,
  }) {
    return DataProvenance(
      provider: provider ?? this.provider,
      sourceId: sourceId ?? this.sourceId,
      retrievedAt: retrievedAt ?? this.retrievedAt,
      confidence: confidence ?? this.confidence,
      attribution: attribution ?? this.attribution,
      license: license ?? this.license,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      refreshTtl: refreshTtl ?? this.refreshTtl,
    );
  }

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'sourceId': sourceId,
    'retrievedAt': retrievedAt.toIso8601String(),
    'confidence': confidence,
    'attribution': attribution,
    'license': license,
    if (sourceUrl != null) 'sourceUrl': sourceUrl,
    'refreshTtlMs': refreshTtl.inMilliseconds,
  };

  factory DataProvenance.fromJson(Map<String, dynamic> json) {
    return DataProvenance(
      provider: json['provider']?.toString() ?? 'saavn',
      sourceId: json['sourceId']?.toString() ?? '',
      retrievedAt: json['retrievedAt'] != null
          ? DateTime.tryParse(json['retrievedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      confidence: (json['confidence'] is num) ? (json['confidence'] as num).toDouble() : 1.0,
      attribution: json['attribution']?.toString() ?? 'IT Feels Primary Music Catalog',
      license: json['license']?.toString() ?? 'Catalog License',
      sourceUrl: json['sourceUrl']?.toString(),
      refreshTtl: Duration(
        milliseconds: json['refreshTtlMs'] is int ? json['refreshTtlMs'] as int : 604800000,
      ),
    );
  }

  /// Preset for verified primary catalogue data (JioSaavn / Addon)
  factory DataProvenance.primaryCatalogue(String id, {String? url}) {
    return DataProvenance(
      provider: 'saavn',
      sourceId: id,
      retrievedAt: DateTime.now(),
      confidence: 1.0,
      attribution: 'JioSaavn Public Music Catalog',
      license: 'Proprietary Content API',
      sourceUrl: url,
      refreshTtl: const Duration(days: 3),
    );
  }

  /// Preset for MusicBrainz structured metadata
  factory DataProvenance.musicBrainz(String mbid) {
    return DataProvenance(
      provider: 'musicbrainz',
      sourceId: mbid,
      retrievedAt: DateTime.now(),
      confidence: 0.95,
      attribution: 'MusicBrainz (MetaBrainz Foundation)',
      license: 'CC0 / Open Data',
      sourceUrl: 'https://musicbrainz.org/release-group/$mbid',
      refreshTtl: const Duration(days: 14),
    );
  }

  /// Preset for Wikidata encyclopedic intelligence
  factory DataProvenance.wikidata(String qid) {
    return DataProvenance(
      provider: 'wikidata',
      sourceId: qid,
      retrievedAt: DateTime.now(),
      confidence: 0.90,
      attribution: 'Wikidata (Wikimedia Foundation)',
      license: 'CC0 1.0 Universal',
      sourceUrl: 'https://www.wikidata.org/wiki/$qid',
      refreshTtl: const Duration(days: 30),
    );
  }

  /// Preset for Last.fm social/tag discovery
  factory DataProvenance.lastFm(String name) {
    return DataProvenance(
      provider: 'lastfm',
      sourceId: name,
      retrievedAt: DateTime.now(),
      confidence: 0.85,
      attribution: 'Last.fm Music Community',
      license: 'Last.fm Non-Commercial API Terms',
      sourceUrl: 'https://www.last.fm/music/${Uri.encodeComponent(name)}',
      refreshTtl: const Duration(days: 7),
    );
  }

  /// Preset for Cover Art Archive
  factory DataProvenance.coverArtArchive(String releaseMbid) {
    return DataProvenance(
      provider: 'coverartarchive',
      sourceId: releaseMbid,
      retrievedAt: DateTime.now(),
      confidence: 0.95,
      attribution: 'Cover Art Archive (Internet Archive & MetaBrainz)',
      license: 'Public Domain / CC0',
      sourceUrl: 'https://coverartarchive.org/release/$releaseMbid',
      refreshTtl: const Duration(days: 30),
    );
  }
}
