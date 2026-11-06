import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/core/intelligence/events/listening_event.dart';
import 'package:it_feels_music/core/intelligence/taste/user_taste_profile.dart';
import 'package:it_feels_music/core/intelligence/taste/taste_decay_engine.dart';
import 'package:it_feels_music/core/intelligence/taste/taste_profile_service.dart';

void main() {
  group('Music Taste Intelligence & Decay Engine Tests', () {
    test('TasteDecayEngine calculates time-decayed affinity accurately', () {
      final now = DateTime(2026, 6, 1, 12, 0);

      // Event 1: Recent completion (today)
      final recentEvent = ListeningEvent(
        eventId: 'e1',
        eventType: ListeningEventType.playbackCompleted,
        canonicalTrackId: 'ct_1',
        trackTitle: 'O Maahi',
        artistName: 'Arijit Singh',
        artists: ['Arijit Singh', 'Pritam'],
        genre: 'Bollywood',
        completionRatio: 1.0,
        timestamp: now,
      );

      // Event 2: Older completion from 21 days ago (1 half-life short term)
      final olderEvent = ListeningEvent(
        eventId: 'e2',
        eventType: ListeningEventType.playbackCompleted,
        canonicalTrackId: 'ct_2',
        trackTitle: 'Starboy',
        artistName: 'The Weeknd',
        artists: ['The Weeknd'],
        genre: 'Pop',
        completionRatio: 1.0,
        timestamp: now.subtract(const Duration(days: 21)),
      );

      final profile = TasteDecayEngine.calculateProfile(
        events: [recentEvent, olderEvent],
        currentTime: now,
      );

      // Arijit Singh should have normalized 1.0 short-term affinity (most recent & high score)
      expect(profile.shortTermArtistAffinities['arijit singh'], 1.0);

      // The Weeknd (21 days ago) short-term affinity decayed by approximately 50%
      final weekndShort = profile.shortTermArtistAffinities['the weeknd']!;
      expect(weekndShort, closeTo(0.50, 0.05));

      // Pop vs Bollywood genres
      expect(profile.shortTermGenreAffinities['bollywood'], 1.0);
      expect(profile.shortTermGenreAffinities['pop']!, closeTo(0.50, 0.05));
    });

    test('TasteProfileService manages artist, genre, and track exclusions', () async {
      final service = TasteProfileService.instance;
      await service.reset();

      expect(service.profile.isExcluded(artist: 'Some Singer'), isFalse);

      await service.excludeArtist('Bad Singer');
      expect(service.profile.isExcluded(artist: 'Bad Singer'), isTrue);
      expect(service.profile.isExcluded(artist: 'bad singer'), isTrue); // case-insensitive

      await service.excludeGenre('Heavy Metal');
      expect(service.profile.isExcluded(genre: 'Heavy Metal'), isTrue);

      await service.excludeTrack('ct_disliked_123');
      expect(service.profile.isExcluded(trackId: 'ct_disliked_123'), isTrue);

      // Unexclude
      await service.unexcludeArtist('Bad Singer');
      expect(service.profile.isExcluded(artist: 'Bad Singer'), isFalse);
    });

    test('UserTasteProfile blends short and long term affinities', () {
      final profile = UserTasteProfile(
        shortTermArtistAffinities: {'arijit singh': 0.8},
        longTermArtistAffinities: {'arijit singh': 1.0},
        lastCalculatedAt: DateTime.now(),
      );

      // 0.8 * 0.70 + 1.0 * 0.30 = 0.56 + 0.30 = 0.86
      final blended = profile.getBlendedArtistAffinity('Arijit Singh');
      expect(blended, closeTo(0.86, 0.01));
    });
  });
}
