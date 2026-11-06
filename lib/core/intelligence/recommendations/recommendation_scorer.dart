import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/intelligence/taste/user_taste_profile.dart';

/// Evaluated recommendation result with score decomposition and human-readable explanation.
class ScoredTrack {
  final Song song;
  final double totalScore;
  final double artistScore;
  final double genreScore;
  final double noveltyScore;
  final double recencyScore;
  final String explanation;

  const ScoredTrack({
    required this.song,
    required this.totalScore,
    this.artistScore = 0.0,
    this.genreScore = 0.0,
    this.noveltyScore = 0.0,
    this.recencyScore = 0.0,
    required this.explanation,
  });

  @override
  String toString() =>
      'ScoredTrack(${song.title} by ${song.artist}, score: ${totalScore.toStringAsFixed(2)}, why: "$explanation")';
}

/// Evaluates recommendation candidate tracks using the multi-vector scoring equation (Section 5.3):
/// Score(T) = w_a * A_artist + w_g * A_genre + w_m * M_mood + w_r * R_recency + w_n * N_novelty - P_repetition
class RecommendationScorer {
  final double weightArtist;
  final double weightGenre;
  final double weightMood;
  final double weightRecency;
  final double weightNovelty;
  final double repetitionPenalty;

  const RecommendationScorer({
    this.weightArtist = 0.35,
    this.weightGenre = 0.25,
    this.weightMood = 0.15,
    this.weightRecency = 0.10,
    this.weightNovelty = 0.15,
    this.repetitionPenalty = 0.50,
  });

  /// Scores candidate song against user taste profile and current list state.
  ScoredTrack? scoreCandidate({
    required Song song,
    required UserTasteProfile profile,
    Map<String, int> artistOccurrences = const {},
    String? moodContext,
  }) {
    // 1. Hard Exclusions Check
    if (profile.isExcluded(
      artist: song.artist,
      genre: song.genre,
      trackId: song.id,
    )) {
      return null; // Excluded by user negative preference
    }

    // 2. Artist Affinity Vector
    final cleanArtist = song.artist.toLowerCase();
    final artistAffinity = profile.getBlendedArtistAffinity(cleanArtist);
    final aScore = (artistAffinity > 0 ? artistAffinity : 0.0) * weightArtist;

    // 3. Genre Affinity Vector
    final cleanGenre = song.genre.toLowerCase();
    final genreAffinity = profile.getBlendedGenreAffinity(cleanGenre);
    final gScore = (genreAffinity > 0 ? genreAffinity : 0.0) * weightGenre;

    // 4. Recency Vector (tracks from recent years get slight recency lift)
    double rScore = 0.0;
    if (song.year >= 2023) {
      rScore = 1.0 * weightRecency;
    } else if (song.year >= 2018) {
      rScore = 0.6 * weightRecency;
    } else {
      rScore = 0.3 * weightRecency;
    }

    // 5. Novelty / Discovery Bonus
    // Novelty is higher when artist affinity is moderate or low, scaled by noveltyTolerance
    final isFamiliar = artistAffinity >= 0.60;
    final noveltyFactor = isFamiliar ? 0.20 : 0.90;
    final nScore = noveltyFactor * profile.noveltyTolerance * weightNovelty;

    // 6. Repetition Penalty
    final priorCount = artistOccurrences[cleanArtist] ?? 0;
    final penalty = priorCount * repetitionPenalty;

    final total = aScore + gScore + rScore + nScore - penalty;

    // Generate human explanation
    String explanation;
    if (artistAffinity >= 0.70) {
      explanation = 'Because you listen to ${song.artist}';
    } else if (genreAffinity >= 0.60) {
      explanation = 'Top pick in ${song.genre}';
    } else if (song.year >= 2024) {
      explanation = 'Fresh release in ${song.genre}';
    } else if (noveltyFactor > 0.70) {
      explanation = 'Discovery matched to your taste';
    } else {
      explanation = 'Recommended based on your activity';
    }

    return ScoredTrack(
      song: song,
      totalScore: total,
      artistScore: aScore,
      genreScore: gScore,
      noveltyScore: nScore,
      recencyScore: rScore,
      explanation: explanation,
    );
  }
}
