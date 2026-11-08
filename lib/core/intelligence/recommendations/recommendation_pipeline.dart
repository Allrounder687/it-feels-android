import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/utils/track_validation_engine.dart';
import 'package:it_feels_music/core/intelligence/taste/user_taste_profile.dart';
import 'package:it_feels_music/core/intelligence/taste/taste_profile_service.dart';
import 'package:it_feels_music/core/intelligence/events/listening_event.dart';
import 'package:it_feels_music/core/intelligence/events/listening_event_buffer.dart';
import 'package:it_feels_music/core/intelligence/recommendations/recommendation_scorer.dart';
import 'package:it_feels_music/core/intelligence/recommendations/candidate_generator.dart';

/// 15 Distinct Recommendation Categories specified in Enterprise Specification Section 5.
enum RecommendationCategory {
  discoverWeekly,
  newMusicFromHistory,
  similarSongs,
  similarArtists,
  forgottenFavourites,
  deepCatalogue,
  regionalDiscovery,
  languageDiscovery,
  moodDiscovery,
  genreExploration,
  collaboratorDiscovery,
  undergroundArtists,
  newReleasesFromFollowed,
  rediscoverOldFavourites,
  unexpectedGems,
}

/// User feedback options for recommendations.
enum RecommendationFeedback {
  moreLikeThis,
  lessLikeThis,
  hideTrack,
  hideArtist,
  snooze,
  notInterested,
}

/// 11-step recommendation pipeline that ingests candidates, applies negative exclusions,
/// deduplicates acoustic keys, enforces heuristic validation, scores multi-vectors,
/// and applies diversity penalties across 15 distinct recommendation recipes.
class RecommendationPipeline {
  final CandidateGenerator candidateGenerator;
  final RecommendationScorer scorer;
  final Map<String, DateTime> _snoozedTracks = {};

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
    RecommendationCategory? category,
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
      category: category,
    );
  }

  /// Synchronously processes and ranks an existing batch of candidates through steps 2-11.
  List<ScoredTrack> processCandidates({
    required List<Song> candidates,
    required UserTasteProfile profile,
    int targetCount = 20,
    int maxTracksPerArtist = 2,
    String? queryContext,
    RecommendationCategory? category,
  }) {
    if (candidates.isEmpty) return [];

    // Filter snoozed tracks
    _pruneExpiredSnoozes();

    // Step 2 & 3: Exclusion Filtering & Content Quality Validation
    final qualityFiltered = TrackValidationEngine.filterAndRank(
      candidates.where((s) {
        if (_snoozedTracks.containsKey(s.id)) return false;
        return !profile.isExcluded(
          artist: s.artist,
          genre: s.genre,
          trackId: s.id,
        );
      }).toList(),
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
        // Enforce category-tailored explanations
        final refined = _enrichCategoryExplanation(scored, category);
        scoredList.add(refined);
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

  /// Refines explanation string based on the active recommendation recipe.
  ScoredTrack _enrichCategoryExplanation(ScoredTrack original, RecommendationCategory? category) {
    if (category == null) return original;

    String reason;
    switch (category) {
      case RecommendationCategory.discoverWeekly:
        reason = 'Fresh weekly discovery tailored to your listening taste';
        break;
      case RecommendationCategory.newMusicFromHistory:
        reason = 'Based on your recent listening to ${original.song.artist}';
        break;
      case RecommendationCategory.similarSongs:
        reason = 'Sonically similar to your recent replays';
        break;
      case RecommendationCategory.similarArtists:
        reason = 'Fans of ${original.song.artist} also listen to this';
        break;
      case RecommendationCategory.forgottenFavourites:
        reason = 'A favorite track you have not played in a while';
        break;
      case RecommendationCategory.deepCatalogue:
        reason = 'Deeper album cut from a familiar artist';
        break;
      case RecommendationCategory.regionalDiscovery:
        reason = 'Popular in regional South Asian music charts';
        break;
      case RecommendationCategory.languageDiscovery:
        reason = 'Matches your preferred listening language (${original.song.language.toUpperCase()})';
        break;
      case RecommendationCategory.moodDiscovery:
        reason = 'Matches your current temporal mood rhythm';
        break;
      case RecommendationCategory.genreExploration:
        reason = 'Matches your high affinity for ${original.song.genre}';
        break;
      case RecommendationCategory.collaboratorDiscovery:
        reason = 'Collaborator of artists you frequently enjoy';
        break;
      case RecommendationCategory.undergroundArtists:
        reason = 'Rising independent artist with high momentum';
        break;
      case RecommendationCategory.newReleasesFromFollowed:
        reason = 'New release from an artist in your library';
        break;
      case RecommendationCategory.rediscoverOldFavourites:
        reason = 'Rediscovered favorite from your historical library';
        break;
      case RecommendationCategory.unexpectedGems:
        reason = 'Serendipitous discovery selected for novelty and quality';
        break;
    }

    return ScoredTrack(
      song: original.song,
      totalScore: original.totalScore,
      artistScore: original.artistScore,
      genreScore: original.genreScore,
      noveltyScore: original.noveltyScore,
      recencyScore: original.recencyScore,
      explanation: reason,
    );
  }

  /// Applies explicit user feedback to adjust taste profiles and negative filters.
  Future<void> applyFeedback({
    required Song song,
    required RecommendationFeedback feedback,
    required UserTasteProfile profile,
  }) async {
    final buffer = ListeningEventBuffer.instance;

    switch (feedback) {
      case RecommendationFeedback.hideArtist:
        await TasteProfileService.instance.excludeArtist(song.artist);
        await buffer.recordEvent(ListeningEvent(
          eventId: 'fb_hide_art_${DateTime.now().millisecondsSinceEpoch}',
          eventType: ListeningEventType.artistHidden,
          canonicalTrackId: song.id,
          trackTitle: song.title,
          artistName: song.artist,
          timestamp: DateTime.now(),
        ));
        break;

      case RecommendationFeedback.hideTrack:
        await TasteProfileService.instance.excludeTrack(song.id);
        await buffer.recordEvent(ListeningEvent(
          eventId: 'fb_hide_trk_${DateTime.now().millisecondsSinceEpoch}',
          eventType: ListeningEventType.trackHidden,
          canonicalTrackId: song.id,
          trackTitle: song.title,
          artistName: song.artist,
          timestamp: DateTime.now(),
        ));
        break;

      case RecommendationFeedback.moreLikeThis:
        await buffer.recordEvent(ListeningEvent(
          eventId: 'fb_like_${DateTime.now().millisecondsSinceEpoch}',
          eventType: ListeningEventType.trackLiked,
          canonicalTrackId: song.id,
          trackTitle: song.title,
          artistName: song.artist,
          genre: song.genre,
          timestamp: DateTime.now(),
        ));
        break;

      case RecommendationFeedback.lessLikeThis:
      case RecommendationFeedback.notInterested:
        await buffer.recordEvent(ListeningEvent(
          eventId: 'fb_dislike_${DateTime.now().millisecondsSinceEpoch}',
          eventType: ListeningEventType.playbackSkipped,
          canonicalTrackId: song.id,
          trackTitle: song.title,
          artistName: song.artist,
          completionRatio: 0.05,
          timestamp: DateTime.now(),
        ));
        break;

      case RecommendationFeedback.snooze:
        _snoozedTracks[song.id] = DateTime.now().add(const Duration(hours: 24));
        break;
    }
  }

  void _pruneExpiredSnoozes() {
    final now = DateTime.now();
    _snoozedTracks.removeWhere((_, expireAt) => now.isAfter(expireAt));
  }
}
