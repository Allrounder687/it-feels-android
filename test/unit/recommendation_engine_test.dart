import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/intelligence/taste/user_taste_profile.dart';
import 'package:it_feels_music/core/intelligence/recommendations/recommendation_scorer.dart';
import 'package:it_feels_music/core/intelligence/recommendations/recommendation_pipeline.dart';

void main() {
  group('Recommendation Engine & Pipeline Tests', () {
    final profile = UserTasteProfile(
      shortTermArtistAffinities: {'arijit singh': 1.0, 'pritam': 0.8},
      shortTermGenreAffinities: {'bollywood': 1.0, 'pop': 0.6},
      excludedArtists: {'bad singer'},
      excludedTrackIds: {'disliked_track_1'},
      noveltyTolerance: 0.5,
      lastCalculatedAt: DateTime.now(),
    );

    test('RecommendationScorer boosts tracks matching artist and genre preferences', () {
      const scorer = RecommendationScorer();

      final arijitSong = Song(
        id: 's1',
        saavnId: 's1',
        title: 'Chaleya',
        artist: 'Arijit Singh',
        album: 'Jawan',
        duration: 200,
        coverArt: '',
        genre: 'Bollywood',
        year: 2023,
        addedAt: DateTime.now(),
      );

      final unknownSong = Song(
        id: 's2',
        saavnId: 's2',
        title: 'Random Track',
        artist: 'Unknown Band',
        album: 'Album X',
        duration: 200,
        coverArt: '',
        genre: 'Jazz',
        year: 2010,
        addedAt: DateTime.now(),
      );

      final scoredArijit = scorer.scoreCandidate(song: arijitSong, profile: profile);
      final scoredUnknown = scorer.scoreCandidate(song: unknownSong, profile: profile);

      expect(scoredArijit, isNotNull);
      expect(scoredUnknown, isNotNull);
      expect(scoredArijit!.totalScore, greaterThan(scoredUnknown!.totalScore));
      expect(scoredArijit.explanation, contains('Arijit Singh'));
    });

    test('RecommendationScorer returns null for excluded artists or tracks', () {
      const scorer = RecommendationScorer();

      final excludedArtistSong = Song(
        id: 's3',
        saavnId: 's3',
        title: 'Song by Bad Singer',
        artist: 'Bad Singer',
        album: 'Album',
        duration: 200,
        coverArt: '',
        addedAt: DateTime.now(),
      );

      final excludedIdSong = Song(
        id: 'disliked_track_1',
        saavnId: 'disliked_track_1',
        title: 'Disliked Track',
        artist: 'Arijit Singh',
        album: 'Album',
        duration: 200,
        coverArt: '',
        addedAt: DateTime.now(),
      );

      expect(scorer.scoreCandidate(song: excludedArtistSong, profile: profile), isNull);
      expect(scorer.scoreCandidate(song: excludedIdSong, profile: profile), isNull);
    });

    test('RecommendationPipeline enforces artist diversity caps', () {
      final pipeline = RecommendationPipeline();

      // Create 5 songs by Arijit Singh
      final songs = List.generate(5, (i) {
        return Song(
          id: 'arijit_$i',
          saavnId: 'arijit_$i',
          title: 'Arijit Song $i',
          artist: 'Arijit Singh',
          album: 'Album $i',
          duration: 200,
          coverArt: '',
          genre: 'Bollywood',
          year: 2023,
          addedAt: DateTime.now(),
        );
      });

      // Add 2 songs by Pritam
      songs.addAll(List.generate(2, (i) {
        return Song(
          id: 'pritam_$i',
          saavnId: 'pritam_$i',
          title: 'Pritam Song $i',
          artist: 'Pritam',
          album: 'Album P$i',
          duration: 210,
          coverArt: '',
          genre: 'Bollywood',
          year: 2023,
          addedAt: DateTime.now(),
        );
      }));

      final results = pipeline.processCandidates(
        candidates: songs,
        profile: profile,
        targetCount: 10,
        maxTracksPerArtist: 2,
      );

      // Even though there are 5 Arijit songs, only 2 should be in results due to diversity cap
      final arijitCount = results.where((r) => r.song.artist.toLowerCase().contains('arijit')).length;
      expect(arijitCount, 2);
    });
  });
}
