import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/utils/track_validation_engine.dart';
import 'package:it_feels_music/core/intelligence/taste/user_taste_profile.dart';
import 'package:it_feels_music/core/intelligence/recommendations/recommendation_scorer.dart';
import 'package:it_feels_music/core/intelligence/recommendations/candidate_generator.dart';

/// 11-step recommendation pipeline that ingests candidates, applies negative exclusions,
/// deduplicates acoustic keys, enforces heuristic validation, scores multi-vectors,
/// and applies diversity penalties.
class RecommendationPipeline {
  final CandidateGenerator candidateGenerator;
  final RecommendationScorer scorer;

  RecommendationPipeline({
    CandidateGenerator? candidateGenerator,
    RecommendationScorer? scorer,
  })  : candidateGenerator = candidateGenerator ?? CandidateGenerator(),
        scorer = scorer ?? const RecommendationScorer();

  /// Runs the full 11-step recommendation pipeline.
  Future<List<ScoredTrack>> execute({
    Song? anchorSong,
    required UserTasteProfile profile,
    List<Song> existingQueue = const [],
    int targetCount = 20,
    int maxTracksPerArtist = 2,
    String? queryContext,
  }) async {
    // Step 1: Candidate Ingestion
    final rawCandidates = await candidateGenerator.generateCandidates(
      anchorSong: anchorSong,
      profile: profile,
      existingQueue: existingQueue,
    );

    return processCandidates(
      candidates: rawCandidates,
      profile: profile,
      targetCount: targetCount,
      maxTracksPerArtist: maxTracksPerArtist,
      queryContext: queryContext,
    );
  }

  /// Synchronously processes and ranks an existing batch of candidates through steps 2-11.
  List<ScoredTrack> processCandidates({
    required List<Song> candidates,
    required UserTasteProfile profile,
    int targetCount = 20,
    int maxTracksPerArtist = 2,
    String? queryContext,
  }) {
    if (candidates.isEmpty) return [];

    // Step 2 & 3: Exclusion Filtering & Content Quality Validation
    final qualityFiltered = TrackValidationEngine.filterAndRank(
      candidates.where((s) => !profile.isExcluded(
        artist: s.artist,
        genre: s.genre,
        trackId: s.id,
      )).toList(),
      queryContext: queryContext,
      minPassingScore: 35.0,
      preserveOriginalOrderIfValid: true,
    );

    // Step 4 & 5: Multi-Vector Scoring with Artist Occurrence Tracking
    final scoredList = <ScoredTrack>[];
    final artistOccurrences = <String, int>{};

    for (final song in qualityFiltered) {
      final scored = scorer.scoreCandidate(
        song: song,
        profile: profile,
        artistOccurrences: artistOccurrences,
      );

      if (scored != null) {
        scoredList.add(scored);
      }
    }

    // Step 6: Rank candidates by total score descending
    scoredList.sort((a, b) => b.totalScore.compareTo(a.totalScore));

    // Step 7: Artist & Album Diversity Enforcement (Max N tracks per artist)
    final diversified = <ScoredTrack>[];
    final finalArtistCounts = <String, int>{};

    for (final item in scoredList) {
      final cleanArtist = item.song.artist.toLowerCase().split(',').first.trim();
      final currentCount = finalArtistCounts[cleanArtist] ?? 0;

      if (currentCount < maxTracksPerArtist) {
        diversified.add(item);
        finalArtistCounts[cleanArtist] = currentCount + 1;
      }

      if (diversified.length >= targetCount) break;
    }

    return diversified;
  }
}
