import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/core/intelligence/events/listening_event.dart';
import 'package:it_feels_music/core/intelligence/events/listening_event_buffer.dart';
import 'package:it_feels_music/core/intelligence/analytics/music_dna_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ListeningEventBuffer.instance.clear();
  });

  group('Music DNA Analytics Service Tests', () {
    test('Computes authentic aggregate metrics from genuine on-device events', () async {
      final buffer = ListeningEventBuffer.instance;
      await buffer.init();

      // Seed mock listening events
      await buffer.recordEvent(ListeningEvent(
        eventId: 'e1',
        eventType: ListeningEventType.playbackCompleted,
        canonicalTrackId: 't1',
        trackTitle: 'Kesariya',
        artistName: 'Arijit Singh',
        genre: 'Bollywood',
        durationPlayedMs: 268000,
        totalDurationMs: 268000,
        completionRatio: 1.0,
        timestamp: DateTime(2026, 11, 1, 9, 30), // Morning, Weekday
        metadata: {'album': 'Brahmastra'},
      ));

      await buffer.recordEvent(ListeningEvent(
        eventId: 'e2',
        eventType: ListeningEventType.playbackCompleted,
        canonicalTrackId: 't2',
        trackTitle: 'Channa Mereya',
        artistName: 'Arijit Singh',
        genre: 'Bollywood',
        durationPlayedMs: 280000,
        totalDurationMs: 280000,
        completionRatio: 1.0,
        timestamp: DateTime(2026, 11, 1, 14, 0), // Afternoon, Weekday
        metadata: {'album': 'Ae Dil Hai Mushkil'},
      ));

      await buffer.recordEvent(ListeningEvent(
        eventId: 'e3',
        eventType: ListeningEventType.meaningfulPlayback,
        canonicalTrackId: 't3',
        trackTitle: 'Lover',
        artistName: 'Diljit Dosanjh',
        genre: 'Punjabi',
        durationPlayedMs: 190000,
        totalDurationMs: 190000,
        completionRatio: 0.9,
        timestamp: DateTime(2026, 11, 1, 23, 15), // Night, Weekday
        metadata: {'album': 'MoonChild Era'},
      ));

      final dnaService = MusicDnaService();
      final overview = await dnaService.computeDnaOverview();

      expect(overview.totalPlays, equals(3));
      expect(overview.uniqueArtistsCount, equals(2));
      expect(overview.uniqueAlbumsCount, equals(3));
      expect(overview.totalListeningMinutes, greaterThanOrEqualTo(12));

      // Top Artist should be Arijit Singh (2 plays)
      expect(overview.topArtists.first.key, equals('Arijit Singh'));
      expect(overview.topArtists.first.value, equals(2));

      // Time of Day distribution
      expect(overview.timeOfDayDistribution['Morning'], equals(1));
      expect(overview.timeOfDayDistribution['Afternoon'], equals(1));
      expect(overview.timeOfDayDistribution['Night'], equals(1));

      // Genre distribution
      expect(overview.genreBreakdown['Bollywood'], equals(2));
      expect(overview.genreBreakdown['Punjabi'], equals(1));
    });

    test('Computes personal relationship with a specific artist', () async {
      final buffer = ListeningEventBuffer.instance;
      await buffer.init();

      await buffer.recordEvent(ListeningEvent(
        eventId: 'e1',
        eventType: ListeningEventType.playbackCompleted,
        canonicalTrackId: 't1',
        trackTitle: 'Kesariya',
        artistName: 'Arijit Singh',
        completionRatio: 1.0,
        timestamp: DateTime(2026, 10, 1),
      ));

      await buffer.recordEvent(ListeningEvent(
        eventId: 'e2',
        eventType: ListeningEventType.playbackCompleted,
        canonicalTrackId: 't1',
        trackTitle: 'Kesariya',
        artistName: 'Arijit Singh',
        completionRatio: 1.0,
        timestamp: DateTime(2026, 11, 1),
      ));

      final dnaService = MusicDnaService();
      final rel = await dnaService.getArtistRelationship('Arijit Singh');

      expect(rel.totalPlays, equals(2));
      expect(rel.mostPlayedTracks.first.key, equals('Kesariya'));
      expect(rel.mostPlayedTracks.first.value, equals(2));
      expect(rel.firstRecordedPlay, isNotNull);
      expect(rel.averageCompletionRate, equals(1.0));
    });

    test('Computes personal track insights with completion percentage and skip ratio', () async {
      final buffer = ListeningEventBuffer.instance;
      await buffer.init();

      await buffer.recordEvent(ListeningEvent(
        eventId: 'e1',
        eventType: ListeningEventType.playbackCompleted,
        canonicalTrackId: 't1',
        trackTitle: 'Kesariya',
        artistName: 'Arijit Singh',
        completionRatio: 1.0,
        timestamp: DateTime.now(),
      ));

      await buffer.recordEvent(ListeningEvent(
        eventId: 'e2',
        eventType: ListeningEventType.playbackSkipped,
        canonicalTrackId: 't1',
        trackTitle: 'Kesariya',
        artistName: 'Arijit Singh',
        completionRatio: 0.2,
        timestamp: DateTime.now(),
      ));

      final dnaService = MusicDnaService();
      final insights = await dnaService.getTrackInsights('Kesariya');

      expect(insights.playCount, equals(1));
      expect(insights.skipCount, equals(1));
      expect(insights.completionPercentage, equals(60.0)); // (1.0 + 0.2) / 2 = 0.6
    });
  });
}
