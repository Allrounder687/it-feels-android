import 'dart:math';
import 'package:it_feels_music/core/intelligence/events/listening_event.dart';
import 'package:it_feels_music/core/intelligence/taste/user_taste_profile.dart';

/// Implements mathematical time-decayed affinity calculations (Section 5.2).
///
/// Formula:
///   A_entity(t) = sum_{i=1}^N w(e_i) * exp(-lambda * (t - t_i))
///
/// Where:
///   lambda = ln(2) / t_{1/2}
///   t_{1/2} = 21 days for short-term affinity
///   t_{1/2} = 180 days for long-term loyalty
class TasteDecayEngine {
  static const double ln2 = 0.69314718056;
  static const double halfLifeShortDays = 21.0;
  static const double halfLifeLongDays = 180.0;

  static const double lambdaShort = ln2 / halfLifeShortDays;
  static const double lambdaLong = ln2 / halfLifeLongDays;

  TasteDecayEngine._();

  /// Computes an updated UserTasteProfile from a collection of raw ListeningEvents.
  static UserTasteProfile calculateProfile({
    required List<ListeningEvent> events,
    UserTasteProfile? existingProfile,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();

    final Map<String, double> shortArtists = {};
    final Map<String, double> longArtists = {};
    final Map<String, double> shortGenres = {};
    final Map<String, double> longGenres = {};

    for (final event in events) {
      final elapsedDays = max(0.0, now.difference(event.timestamp).inSeconds / 86400.0);
      final weight = event.engagementScore;

      final decayShort = exp(-lambdaShort * elapsedDays);
      final decayLong = exp(-lambdaLong * elapsedDays);

      final valShort = weight * decayShort;
      final valLong = weight * decayLong;

      // Process artists
      final artistList = event.artists.isNotEmpty
          ? event.artists
          : [event.artistName];

      for (final rawArtist in artistList) {
        final cleanArtist = rawArtist.trim().toLowerCase();
        if (cleanArtist.isEmpty || cleanArtist == 'unknown artist') continue;

        shortArtists[cleanArtist] = (shortArtists[cleanArtist] ?? 0.0) + valShort;
        longArtists[cleanArtist] = (longArtists[cleanArtist] ?? 0.0) + valLong;
      }

      // Process genres
      final cleanGenre = event.genre.trim().toLowerCase();
      if (cleanGenre.isNotEmpty && cleanGenre != 'unknown') {
        shortGenres[cleanGenre] = (shortGenres[cleanGenre] ?? 0.0) + valShort;
        longGenres[cleanGenre] = (longGenres[cleanGenre] ?? 0.0) + valLong;
      }
    }

    // Normalize maps to [0.0, 1.0] scale relative to highest positive affinity
    final normShortArtists = _normalizeMap(shortArtists);
    final normLongArtists = _normalizeMap(longArtists);
    final normShortGenres = _normalizeMap(shortGenres);
    final normLongGenres = _normalizeMap(longGenres);

    final existing = existingProfile ?? UserTasteProfile.initial();

    return UserTasteProfile(
      shortTermArtistAffinities: normShortArtists,
      longTermArtistAffinities: normLongArtists,
      shortTermGenreAffinities: normShortGenres,
      longTermGenreAffinities: normLongGenres,
      excludedArtists: existing.excludedArtists,
      excludedGenres: existing.excludedGenres,
      excludedTrackIds: existing.excludedTrackIds,
      noveltyTolerance: existing.noveltyTolerance,
      lastCalculatedAt: now,
      totalEventsProcessed: events.length,
    );
  }

  /// Normalizes values to [0.0, 1.0] scale, clamping negatives to 0.0.
  static Map<String, double> _normalizeMap(Map<String, double> raw) {
    if (raw.isEmpty) return {};

    double maxVal = 0.0;
    for (final v in raw.values) {
      if (v > maxVal) maxVal = v;
    }

    if (maxVal <= 0.0) return {};

    final Map<String, double> normalized = {};
    raw.forEach((k, v) {
      if (v > 0.0) {
        normalized[k] = double.parse((v / maxVal).clamp(0.0, 1.0).toStringAsFixed(4));
      }
    });

    return normalized;
  }
}
