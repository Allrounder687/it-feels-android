/// Multi-vector user music taste profile separating short-term and long-term affinities,
/// tracking explicit exclusions, and tuning novelty preferences.
class UserTasteProfile {
  final Map<String, double> shortTermArtistAffinities; // t_half = 21 days
  final Map<String, double> longTermArtistAffinities;  // t_half = 180 days
  final Map<String, double> shortTermGenreAffinities;
  final Map<String, double> longTermGenreAffinities;
  final Set<String> excludedArtists;                  // Hard exclusion
  final Set<String> excludedGenres;                   // Hard exclusion
  final Set<String> excludedTrackIds;                 // Disliked / hidden tracks
  final double noveltyTolerance;                      // 0.0 (strictly familiar) to 1.0 (maximum discovery)
  final DateTime lastCalculatedAt;
  final int totalEventsProcessed;

  const UserTasteProfile({
    this.shortTermArtistAffinities = const {},
    this.longTermArtistAffinities = const {},
    this.shortTermGenreAffinities = const {},
    this.longTermGenreAffinities = const {},
    this.excludedArtists = const {},
    this.excludedGenres = const {},
    this.excludedTrackIds = const {},
    this.noveltyTolerance = 0.50,
    required this.lastCalculatedAt,
    this.totalEventsProcessed = 0,
  });

  /// Factory creating an initial blank/cold-start profile.
  factory UserTasteProfile.initial() {
    return UserTasteProfile(
      lastCalculatedAt: DateTime.now(),
    );
  }

  /// Blended artist affinity giving 70% weight to short-term dynamic momentum and 30% to long-term loyalty.
  double getBlendedArtistAffinity(String artist) {
    if (excludedArtists.contains(artist.trim().toLowerCase())) return -1.0;
    final clean = artist.trim().toLowerCase();
    final shortA = shortTermArtistAffinities[clean] ?? 0.0;
    final longA = longTermArtistAffinities[clean] ?? 0.0;
    return (shortA * 0.70) + (longA * 0.30);
  }

  /// Blended genre affinity.
  double getBlendedGenreAffinity(String genre) {
    if (excludedGenres.contains(genre.trim().toLowerCase())) return -1.0;
    final clean = genre.trim().toLowerCase();
    final shortG = shortTermGenreAffinities[clean] ?? 0.0;
    final longG = longTermGenreAffinities[clean] ?? 0.0;
    return (shortG * 0.65) + (longG * 0.35);
  }

  /// Whether an entity is strictly excluded by user preference.
  bool isExcluded({String? artist, String? genre, String? trackId}) {
    if (artist != null && excludedArtists.contains(artist.trim().toLowerCase())) return true;
    if (genre != null && excludedGenres.contains(genre.trim().toLowerCase())) return true;
    if (trackId != null && excludedTrackIds.contains(trackId.trim())) return true;
    return false;
  }

  UserTasteProfile copyWith({
    Map<String, double>? shortTermArtistAffinities,
    Map<String, double>? longTermArtistAffinities,
    Map<String, double>? shortTermGenreAffinities,
    Map<String, double>? longTermGenreAffinities,
    Set<String>? excludedArtists,
    Set<String>? excludedGenres,
    Set<String>? excludedTrackIds,
    double? noveltyTolerance,
    DateTime? lastCalculatedAt,
    int? totalEventsProcessed,
  }) {
    return UserTasteProfile(
      shortTermArtistAffinities: shortTermArtistAffinities ?? this.shortTermArtistAffinities,
      longTermArtistAffinities: longTermArtistAffinities ?? this.longTermArtistAffinities,
      shortTermGenreAffinities: shortTermGenreAffinities ?? this.shortTermGenreAffinities,
      longTermGenreAffinities: longTermGenreAffinities ?? this.longTermGenreAffinities,
      excludedArtists: excludedArtists ?? this.excludedArtists,
      excludedGenres: excludedGenres ?? this.excludedGenres,
      excludedTrackIds: excludedTrackIds ?? this.excludedTrackIds,
      noveltyTolerance: noveltyTolerance ?? this.noveltyTolerance,
      lastCalculatedAt: lastCalculatedAt ?? this.lastCalculatedAt,
      totalEventsProcessed: totalEventsProcessed ?? this.totalEventsProcessed,
    );
  }

  Map<String, dynamic> toJson() => {
    'shortTermArtistAffinities': shortTermArtistAffinities,
    'longTermArtistAffinities': longTermArtistAffinities,
    'shortTermGenreAffinities': shortTermGenreAffinities,
    'longTermGenreAffinities': longTermGenreAffinities,
    'excludedArtists': excludedArtists.toList(),
    'excludedGenres': excludedGenres.toList(),
    'excludedTrackIds': excludedTrackIds.toList(),
    'noveltyTolerance': noveltyTolerance,
    'lastCalculatedAt': lastCalculatedAt.toIso8601String(),
    'totalEventsProcessed': totalEventsProcessed,
  };

  factory UserTasteProfile.fromJson(Map<String, dynamic> json) {
    Map<String, double> parseMap(dynamic source) {
      if (source is Map<String, dynamic>) {
        return source.map((k, v) => MapEntry(k, (v is num) ? v.toDouble() : 0.0));
      }
      return {};
    }

    Set<String> parseSet(dynamic source) {
      if (source is List<dynamic>) {
        return source.map((e) => e.toString().toLowerCase().trim()).toSet();
      }
      return {};
    }

    return UserTasteProfile(
      shortTermArtistAffinities: parseMap(json['shortTermArtistAffinities']),
      longTermArtistAffinities: parseMap(json['longTermArtistAffinities']),
      shortTermGenreAffinities: parseMap(json['shortTermGenreAffinities']),
      longTermGenreAffinities: parseMap(json['longTermGenreAffinities']),
      excludedArtists: parseSet(json['excludedArtists']),
      excludedGenres: parseSet(json['excludedGenres']),
      excludedTrackIds: parseSet(json['excludedTrackIds']),
      noveltyTolerance: (json['noveltyTolerance'] is num) ? (json['noveltyTolerance'] as num).toDouble() : 0.50,
      lastCalculatedAt: json['lastCalculatedAt'] != null
          ? DateTime.tryParse(json['lastCalculatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      totalEventsProcessed: json['totalEventsProcessed'] is int ? json['totalEventsProcessed'] as int : 0,
    );
  }
}
