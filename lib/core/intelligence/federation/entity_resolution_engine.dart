import 'package:string_similarity/string_similarity.dart';
import 'package:it_feels_music/core/utils/string_utils.dart';
import 'package:it_feels_music/core/utils/hinglish_transliterator.dart';
import 'package:it_feels_music/core/music_identity/canonical_track.dart';
import 'package:it_feels_music/core/music_identity/canonical_artist.dart';
import 'data_provenance.dart';

/// Result of an entity resolution attempt between disparate source representations.
class EntityMatchResult<T> {
  final bool matched;
  final double confidence; // 0.0 to 1.0
  final String matchReason;
  final T? canonicalEntity;
  final bool isAmbiguous;
  final DataProvenance? provenance;

  const EntityMatchResult({
    required this.matched,
    required this.confidence,
    required this.matchReason,
    this.canonicalEntity,
    this.isAmbiguous = false,
    this.provenance,
  });

  factory EntityMatchResult.exactMatch(T entity, String reason, {DataProvenance? provenance}) {
    return EntityMatchResult(
      matched: true,
      confidence: 1.0,
      matchReason: reason,
      canonicalEntity: entity,
      isAmbiguous: false,
      provenance: provenance,
    );
  }

  factory EntityMatchResult.fuzzyMatch(T entity, double confidence, String reason, {DataProvenance? provenance}) {
    return EntityMatchResult(
      matched: true,
      confidence: confidence,
      matchReason: reason,
      canonicalEntity: entity,
      isAmbiguous: confidence < 0.85,
      provenance: provenance,
    );
  }

  factory EntityMatchResult.noMatch(String reason) {
    return EntityMatchResult(
      matched: false,
      confidence: 0.0,
      matchReason: reason,
      canonicalEntity: null,
      isAmbiguous: false,
    );
  }
}

/// Advanced multi-vector entity resolution engine that matches tracks, artists, and albums
/// across heterogeneous providers while preventing false mergers of remixes, live cuts,
/// and regional transliterations.
class EntityResolutionEngine {
  static final EntityResolutionEngine _instance = EntityResolutionEngine._internal();
  factory EntityResolutionEngine() => _instance;
  EntityResolutionEngine._internal();

  /// Resolves two track candidates to determine if they represent the same musical recording.
  EntityMatchResult<CanonicalTrack> matchTracks({
    required String queryTitle,
    required String queryArtist,
    int? queryDuration,
    String? queryIsrc,
    required List<CanonicalTrack> candidates,
  }) {
    // 1. Exact ISRC matching (highest authority)
    if (queryIsrc != null && queryIsrc.trim().isNotEmpty) {
      final cleanIsrc = queryIsrc.trim().toUpperCase();
      for (final candidate in candidates) {
        if (candidate.isrc != null && candidate.isrc!.toUpperCase() == cleanIsrc) {
          return EntityMatchResult.exactMatch(
            candidate,
            'ISRC exact match ($cleanIsrc)',
            provenance: candidate.provenance,
          );
        }
      }
    }

    final cleanTitle = StringUtils.cleanText(queryTitle);
    final cleanArtist = StringUtils.cleanText(queryArtist);
    final isRemixOrLive = _detectVersionVariant(queryTitle);

    double bestScore = 0.0;
    CanonicalTrack? bestCandidate;
    String bestReason = '';

    for (final candidate in candidates) {
      // Version guard: If query is live/remix/acoustic but candidate is not (or vice-versa), reject merger
      final candidateVariant = _detectVersionVariant(candidate.title);
      if (isRemixOrLive != candidateVariant) {
        continue;
      }

      // Title & Artist lexical & phonetic similarity
      final titleSim = StringSimilarity.compareTwoStrings(
        cleanTitle.toLowerCase(),
        candidate.title.toLowerCase(),
      );

      final transliteratedQuery = HinglishTransliterator.transliterate(cleanTitle).toLowerCase();
      final transliteratedCandidate = HinglishTransliterator.transliterate(candidate.title).toLowerCase();
      final transliteratedSim = StringSimilarity.compareTwoStrings(transliteratedQuery, transliteratedCandidate);
      final effectiveTitleSim = titleSim > transliteratedSim ? titleSim : transliteratedSim;

      final artistSim = StringSimilarity.compareTwoStrings(
        cleanArtist.toLowerCase(),
        candidate.artist.toLowerCase(),
      );

      // Duration tolerance penalty
      double durationScore = 1.0;
      if (queryDuration != null && queryDuration > 0 && candidate.duration > 0) {
        final diff = (queryDuration - candidate.duration).abs();
        if (diff > 25) {
          // Duration difference too large (likely different version or excerpt)
          continue;
        } else if (diff > 8) {
          durationScore = 0.85;
        } else if (diff > 3) {
          durationScore = 0.95;
        }
      }

      // Weighted harmonic confidence
      final compositeScore = (effectiveTitleSim * 0.50 + artistSim * 0.35 + durationScore * 0.15);

      if (compositeScore > bestScore) {
        bestScore = compositeScore;
        bestCandidate = candidate;
        bestReason = 'Composite similarity: title=${(effectiveTitleSim * 100).toInt()}%, artist=${(artistSim * 100).toInt()}%';
      }
    }

    if (bestCandidate != null && bestScore >= 0.78) {
      return EntityMatchResult.fuzzyMatch(
        bestCandidate,
        bestScore,
        bestReason,
        provenance: bestCandidate.provenance,
      );
    }

    return EntityMatchResult.noMatch('No candidate met confidence threshold >= 0.78 (best: ${(bestScore * 100).toInt()}%)');
  }

  /// Resolves an artist candidate against known CanonicalArtists.
  EntityMatchResult<CanonicalArtist> matchArtist({
    required String queryName,
    required List<CanonicalArtist> candidates,
  }) {
    final cleanQuery = StringUtils.cleanText(queryName).toLowerCase();
    final hinglishQuery = HinglishTransliterator.transliterate(cleanQuery).toLowerCase();

    for (final candidate in candidates) {
      final cleanCandidate = StringUtils.cleanText(candidate.name).toLowerCase();
      if (cleanCandidate == cleanQuery) {
        return EntityMatchResult.exactMatch(candidate, 'Exact artist name match');
      }

      // Check native / alternate names
      for (final alt in candidate.nativeNames) {
        if (alt.toLowerCase() == cleanQuery) {
          return EntityMatchResult.exactMatch(candidate, 'Matched native/alternate name ($alt)');
        }
      }

      // Lexical & transliteration similarity
      final sim = StringSimilarity.compareTwoStrings(cleanQuery, cleanCandidate);
      final hinglishSim = StringSimilarity.compareTwoStrings(
        hinglishQuery,
        HinglishTransliterator.transliterate(cleanCandidate).toLowerCase(),
      );
      final maxSim = sim > hinglishSim ? sim : hinglishSim;

      if (maxSim >= 0.88) {
        return EntityMatchResult.fuzzyMatch(candidate, maxSim, 'High artist name phonetic similarity (${(maxSim * 100).toInt()}%)');
      }
    }

    return EntityMatchResult.noMatch('No matching artist identified');
  }

  /// Detects acoustic variants to prevent merging studio cuts with live/remix recordings.
  String _detectVersionVariant(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('remix')) return 'remix';
    if (lower.contains('acoustic') || lower.contains('unplugged')) return 'acoustic';
    if (lower.contains('live')) return 'live';
    if (lower.contains('lofi') || lower.contains('lo-fi')) return 'lofi';
    if (lower.contains('instrumental') || lower.contains('karaoke')) return 'instrumental';
    if (lower.contains('reprise')) return 'reprise';
    return 'studio';
  }
}
