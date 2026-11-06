import 'package:flutter/foundation.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/core/intelligence/taste/user_taste_profile.dart';

/// Aggregates multi-source candidate tracks from history, taste profile seeds, and repository recommendations.
class CandidateGenerator {
  final IMusicRepository? _injectedRepo;

  CandidateGenerator({IMusicRepository? musicRepo}) : _injectedRepo = musicRepo;

  IMusicRepository get _musicRepo => _injectedRepo ?? locator<IMusicRepository>();

  /// Generates a diverse pool of candidate tracks for recommendation scoring.
  Future<List<Song>> generateCandidates({
    Song? anchorSong,
    required UserTasteProfile profile,
    List<Song> existingQueue = const [],
    int maxCandidates = 50,
  }) async {
    final candidatePool = <Song>[];
    final seenIds = existingQueue.map((s) => s.id).toSet();

    // 1. Anchor Track Recommendations (if provided, e.g. Autoplay or Radio)
    if (anchorSong != null) {
      try {
        final recos = await _musicRepo.getRecommendedSongs(anchorSong);
        for (final s in recos) {
          if (seenIds.add(s.id)) {
            candidatePool.add(s);
          }
        }
      } catch (e) {
        debugPrint('[CandidateGenerator] Anchor recommendations error: $e');
      }
    }

    // 2. High-Affinity Artist Seeds from Taste Profile
    final topArtists = profile.shortTermArtistAffinities.entries
        .where((e) => e.value >= 0.35 && !profile.excludedArtists.contains(e.key))
        .map((e) => e.key)
        .take(3)
        .toList();

    for (final artist in topArtists) {
      try {
        final artistSongs = await _musicRepo.searchSongs(artist, count: 10);
        for (final s in artistSongs) {
          if (seenIds.add(s.id)) {
            candidatePool.add(s);
          }
        }
      } catch (e) {
        debugPrint('[CandidateGenerator] Artist seed error for $artist: $e');
      }
    }

    // 3. Top Genre Exploration Seeds
    final topGenres = profile.shortTermGenreAffinities.entries
        .where((e) => e.value >= 0.40 && !profile.excludedGenres.contains(e.key))
        .map((e) => e.key)
        .take(2)
        .toList();

    for (final genre in topGenres) {
      try {
        final genreSongs = await _musicRepo.searchSongs('$genre hits', count: 10);
        for (final s in genreSongs) {
          if (seenIds.add(s.id)) {
            candidatePool.add(s);
          }
        }
      } catch (e) {
        debugPrint('[CandidateGenerator] Genre seed error for $genre: $e');
      }
    }

    return candidatePool.take(maxCandidates).toList();
  }
}
