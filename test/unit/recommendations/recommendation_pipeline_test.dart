import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/intelligence/taste/user_taste_profile.dart';
import 'package:it_feels_music/core/intelligence/taste/taste_profile_service.dart';
import 'package:it_feels_music/core/intelligence/recommendations/recommendation_pipeline.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TasteProfileService.instance.reset();
  });

  group('Advanced Discovery Engine & Recommendation Pipeline Tests', () {
    final pipeline = RecommendationPipeline();

    final testSongs = [
      Song(
        id: 's1',
        saavnId: 's1',
        title: 'Tum Hi Ho',
        artist: 'Arijit Singh',
        album: 'Aashiqui 2',
        duration: 262,
        coverArt: 'https://example.com/art.jpg',
        genre: 'Bollywood',
        year: 2013,
        addedAt: DateTime(2024, 1, 1),
      ),
      Song(
        id: 's2',
        saavnId: 's2',
        title: 'Lover',
        artist: 'Diljit Dosanjh',
        album: 'MoonChild Era',
        duration: 195,
        coverArt: 'https://example.com/art.jpg',
        genre: 'Punjabi',
        year: 2021,
        addedAt: DateTime(2024, 1, 1),
      ),
      Song(
        id: 's3',
        saavnId: 's3',
        title: 'Pasoori',
        artist: 'Ali Sethi, Shae Gill',
        album: 'Coke Studio Season 14',
        duration: 224,
        coverArt: 'https://example.com/art.jpg',
        genre: 'Indie',
        year: 2022,
        addedAt: DateTime(2024, 1, 1),
      ),
    ];

    test('Ranks candidates with category-tailored explanations across distinct categories', () {
      final profile = UserTasteProfile(
        shortTermArtistAffinities: {'arijit singh': 0.85, 'diljit dosanjh': 0.50},
        shortTermGenreAffinities: {'bollywood': 0.80, 'punjabi': 0.60},
        lastCalculatedAt: DateTime.now(),
      );

      final results = pipeline.processCandidates(
        candidates: testSongs,
        profile: profile,
        targetCount: 3,
        category: RecommendationCategory.discoverWeekly,
      );

      expect(results.isNotEmpty, isTrue);
      expect(results.first.song.artist, contains('Arijit Singh'));
      expect(results.first.explanation, contains('Fresh weekly discovery'));
    });

    test('Enforces hard exclusion when user provides hideArtist feedback', () async {
      final profile = UserTasteProfile(
        shortTermArtistAffinities: {'arijit singh': 0.90},
        lastCalculatedAt: DateTime.now(),
      );

      await pipeline.applyFeedback(
        song: testSongs[0],
        feedback: RecommendationFeedback.hideArtist,
        profile: profile,
      );

      final updatedProfile = TasteProfileService.instance.profile;
      expect(updatedProfile.excludedArtists, contains('arijit singh'));

      final afterHide = pipeline.processCandidates(
        candidates: testSongs,
        profile: updatedProfile,
      );

      expect(afterHide.any((st) => st.song.artist.contains('Arijit Singh')), isFalse);
    });

    test('Enforces 24-hour snooze suppression when user snoozes a track', () async {
      final profile = UserTasteProfile.initial();

      await pipeline.applyFeedback(
        song: testSongs[1], // Diljit - Lover
        feedback: RecommendationFeedback.snooze,
        profile: profile,
      );

      final afterSnooze = pipeline.processCandidates(
        candidates: testSongs,
        profile: profile,
      );

      expect(afterSnooze.any((st) => st.song.id == 's2'), isFalse);
    });
  });
}
