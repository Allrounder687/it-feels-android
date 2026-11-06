import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/core/intelligence/feed/home_feed_engine.dart';
import 'package:it_feels_music/core/intelligence/feed/home_feed_models.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/home/home_provider.dart';
import 'package:it_feels_music/features/library/listening_history_provider.dart';

void main() {
  group('HomeFeedEngine Tests', () {
    test('composes feed with daily mixes and quick picks when history is present', () {
      final engine = HomeFeedEngine.instance;

      final historySong = Song(
        id: 'saavn:hist1',
        saavnId: 'hist1',
        title: 'Recent Song',
        artist: 'Test Artist',
        album: 'Test Album',
        duration: 180,
        coverArt: 'https://example.com/cover.jpg',
        addedAt: DateTime.now(),
      );

      final historyState = ListeningHistoryState(
        recentlyPlayed: [historySong],
      );

      const homeState = HomeState();

      final feed = engine.composeFeed(
        homeState: homeState,
        historyState: historyState,
        activeFilter: 'All',
      );

      expect(feed.sections, isNotEmpty);

      // Section 1 should be quickPicks ('Jump Back In')
      final quickPicks = feed.sections.firstWhere((s) => s.sectionType == FeedSectionType.quickPicks);
      expect(quickPicks.title, 'Jump Back In');
      expect(quickPicks.items.first.title, 'Recent Song');

      // Section 2 should be dailyMix ('Made For You')
      final dailyMix = feed.sections.firstWhere((s) => s.sectionType == FeedSectionType.dailyMix);
      expect(dailyMix.title, 'Made For You');
      expect(dailyMix.items.length, 6);
    });

    test('filters feed based on active genre selection', () {
      final engine = HomeFeedEngine.instance;

      final bSong = Song(
        id: 'saavn:bolly1',
        saavnId: 'bolly1',
        title: 'Bolly Song',
        artist: 'Arijit',
        album: 'Bolly Album',
        duration: 210,
        coverArt: 'https://example.com/b.jpg',
        addedAt: DateTime.now(),
      );

      final homeState = HomeState(
        bollywoodSongs: [bSong],
      );

      const historyState = ListeningHistoryState();

      final feed = engine.composeFeed(
        homeState: homeState,
        historyState: historyState,
        activeFilter: 'Bollywood',
      );

      // In Bollywood filter, Bollywood tracks must be present and dailyMix/quickPicks absent
      final bollySection = feed.sections.firstWhere((s) => s.id == 'sec_bollywood_tracks');
      expect(bollySection.items.first.title, 'Bolly Song');
      expect(feed.sections.any((s) => s.sectionType == FeedSectionType.dailyMix), isFalse);
    });
  });
}
