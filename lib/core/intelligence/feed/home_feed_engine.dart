import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/core/intelligence/feed/home_feed_models.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/home/home_provider.dart';
import 'package:it_feels_music/features/library/listening_history_provider.dart';
import 'package:it_feels_music/core/intelligence/playlists/daily_mix_orchestrator.dart';
import 'package:it_feels_music/core/intelligence/catalogue/artwork_repair_service.dart';

/// Data-driven engine that composes, orders, and caches personalized feed sections.
class HomeFeedEngine {
  static const String _cacheKeyPrefix = 'home_feed_snapshot_v1_';
  static final HomeFeedEngine _instance = HomeFeedEngine._internal();
  factory HomeFeedEngine() => _instance;
  static HomeFeedEngine get instance => _instance;

  HomeFeedEngine._internal();

  /// Composes a complete HomeFeed based on active store state, history, and filter.
  HomeFeed composeFeed({
    HomeState? homeState,
    ListeningHistoryState? historyState,
    String activeFilter = 'All',
  }) {
    final hState = homeState ?? const HomeState();
    final histState = historyState ?? const ListeningHistoryState();
    final sections = <HomeFeedSection>[];

    // 1. Quick Picks / Jump Back In (High priority for returning users)
    if ((activeFilter == 'All' || activeFilter == 'For You') &&
        histState.recentlyPlayed.isNotEmpty) {
      sections.add(
        HomeFeedSection(
          id: 'sec_jump_back_in',
          sectionType: FeedSectionType.quickPicks,
          title: 'Jump Back In',
          subtitle: 'CONTINUE LISTENING',
          priority: 10,
          isPersonalized: true,
          items: histState.recentlyPlayed.take(12).map((song) {
            return FeedItem.fromSong(song);
          }).toList(),
        ),
      );
    }

    // 2. Made For You / Daily Clusters (Daily Mixes 1-6)
    if (activeFilter == 'All' || activeFilter == 'For You') {
      final mixItems = _buildDailyMixItems(hState);
      if (mixItems.isNotEmpty) {
        sections.add(
          HomeFeedSection(
            id: 'sec_made_for_you',
            sectionType: FeedSectionType.dailyMix,
            title: 'Made For You',
            subtitle: 'DAILY CLUSTERS',
            priority: 20,
            isPersonalized: true,
            items: mixItems,
          ),
        );
      }
    }

    // 3. For You Personalized Tracks
    if (activeFilter == 'For You' && hState.youSongs.isNotEmpty) {
      sections.add(
        HomeFeedSection(
          id: 'sec_for_you_tracks',
          sectionType: FeedSectionType.personalizedDiscovery,
          title: 'Recommended For You',
          subtitle: 'PERSONALIZED PICKS',
          priority: 25,
          isPersonalized: true,
          items: hState.youSongs.take(20).map((s) => FeedItem.fromSong(s)).toList(),
        ),
      );
    }

    // 4. Genre-Specific Multi-Shelf Feeds (Bollywood, Punjabi, International)
    if (activeFilter == 'Bollywood') {
      if (hState.bollywoodSongs.isNotEmpty) {
        sections.add(
          HomeFeedSection(
            id: 'sec_bollywood_tracks',
            sectionType: FeedSectionType.trackList,
            title: 'Bollywood Hits',
            subtitle: 'TOP HINDI ESSENTIALS',
            priority: 30,
            items: hState.bollywoodSongs.map((s) => FeedItem.fromSong(s)).toList(),
          ),
        );
      }
      if (hState.bollywoodPlaylists.isNotEmpty) {
        sections.add(
          HomeFeedSection(
            id: 'sec_bollywood_playlists',
            sectionType: FeedSectionType.playlistCarousel,
            title: 'Bollywood Playlists',
            subtitle: 'CURATED DESI COLLECTIONS',
            priority: 32,
            items: hState.bollywoodPlaylists.map((p) => FeedItem.fromPlaylist(p)).toList(),
          ),
        );
      }
      if (hState.bollywoodAlbums.isNotEmpty) {
        sections.add(
          HomeFeedSection(
            id: 'sec_bollywood_albums',
            sectionType: FeedSectionType.albumCarousel,
            title: 'Bollywood Soundtracks & Albums',
            subtitle: 'ORIGINAL SOUNDTRACKS',
            priority: 34,
            items: hState.bollywoodAlbums.map((p) => FeedItem.fromPlaylist(p)).toList(),
          ),
        );
      }
    } else if (activeFilter == 'International') {
      if (hState.hollywoodSongs.isNotEmpty) {
        sections.add(
          HomeFeedSection(
            id: 'sec_international_tracks',
            sectionType: FeedSectionType.trackList,
            title: 'Pop & International',
            subtitle: 'GLOBAL VIBES',
            priority: 30,
            items: hState.hollywoodSongs.map((s) => FeedItem.fromSong(s)).toList(),
          ),
        );
      }
      if (hState.hollywoodPlaylists.isNotEmpty) {
        sections.add(
          HomeFeedSection(
            id: 'sec_international_playlists',
            sectionType: FeedSectionType.playlistCarousel,
            title: 'Global Playlists',
            subtitle: 'WORLDWIDE SELECTIONS',
            priority: 32,
            items: hState.hollywoodPlaylists.map((p) => FeedItem.fromPlaylist(p)).toList(),
          ),
        );
      }
      if (hState.hollywoodAlbums.isNotEmpty) {
        sections.add(
          HomeFeedSection(
            id: 'sec_international_albums',
            sectionType: FeedSectionType.albumCarousel,
            title: 'International Masterpieces',
            subtitle: 'TOP CHARTER ALBUMS',
            priority: 34,
            items: hState.hollywoodAlbums.map((p) => FeedItem.fromPlaylist(p)).toList(),
          ),
        );
      }
    } else if (activeFilter == 'Punjabi') {
      if (hState.punjabiSongs.isNotEmpty) {
        sections.add(
          HomeFeedSection(
            id: 'sec_punjabi_tracks',
            sectionType: FeedSectionType.trackList,
            title: 'Punjabi Hits',
            subtitle: 'DESI BEATS & ANTHEMS',
            priority: 30,
            items: hState.punjabiSongs.map((s) => FeedItem.fromSong(s)).toList(),
          ),
        );
      }
      if (hState.punjabiPlaylists.isNotEmpty) {
        sections.add(
          HomeFeedSection(
            id: 'sec_punjabi_playlists',
            sectionType: FeedSectionType.playlistCarousel,
            title: 'Punjabi Playlists',
            subtitle: 'BHANGRA & DESI VIBES',
            priority: 32,
            items: hState.punjabiPlaylists.map((p) => FeedItem.fromPlaylist(p)).toList(),
          ),
        );
      }
      if (hState.punjabiAlbums.isNotEmpty) {
        sections.add(
          HomeFeedSection(
            id: 'sec_punjabi_albums',
            sectionType: FeedSectionType.albumCarousel,
            title: 'Essential Punjabi Albums',
            subtitle: 'ICONIC ALBUMS',
            priority: 34,
            items: hState.punjabiAlbums.map((p) => FeedItem.fromPlaylist(p)).toList(),
          ),
        );
      }
    }

    // 5. Trending Hits / Top Charts
    if ((activeFilter == 'All' || activeFilter == 'Charts') &&
        (hState.trendingSongs.isNotEmpty || hState.chartPlaylists.isNotEmpty)) {
      final chartItems = hState.chartPlaylists.isNotEmpty
          ? hState.chartPlaylists.take(8).map((p) => FeedItem.fromPlaylist(p)).toList()
          : hState.trendingSongs.take(8).map((s) => FeedItem.fromSong(s)).toList();

      sections.add(
        HomeFeedSection(
          id: 'sec_trending_hits',
          sectionType: FeedSectionType.trending,
          title: 'Trending Hits',
          subtitle: 'TOP CHARTS',
          priority: 40,
          items: chartItems,
        ),
      );
    }

    // 6. Featured Theme Playlists
    if ((activeFilter == 'All' || activeFilter == 'Acoustic') &&
        hState.topPlaylists.isNotEmpty) {
      sections.add(
        HomeFeedSection(
          id: 'sec_featured_playlists',
          sectionType: FeedSectionType.playlistCarousel,
          title: 'Featured Playlists',
          subtitle: 'CURATED SELECTIONS',
          priority: 50,
          items: hState.topPlaylists.take(10).map((p) => FeedItem.fromPlaylist(p)).toList(),
        ),
      );
    }

    // 7. Essential Masterpiece Albums
    if (activeFilter == 'All' && hState.topAlbums.isNotEmpty) {
      sections.add(
        HomeFeedSection(
          id: 'sec_essential_albums',
          sectionType: FeedSectionType.albumCarousel,
          title: 'Essential Albums',
          subtitle: 'MASTERPIECES',
          priority: 60,
          items: hState.topAlbums.take(8).map((p) => FeedItem.fromPlaylist(p)).toList(),
        ),
      );
    }

    // Sort sections deterministically by priority
    sections.sort((a, b) => a.priority.compareTo(b.priority));

    return HomeFeed(
      generatedAt: DateTime.now(),
      sections: sections,
      isFromCache: false,
    );
  }

  /// Builds standardized Daily Mixes (Mix 1 to 6) with resilient fallback cover art.
  List<FeedItem> _buildDailyMixItems(HomeState homeState) {
    final orchestrator = DailyMixOrchestrator();
    final artworkRepair = ArtworkRepairService();
    final mixes = orchestrator.getAllMixes();
    final items = <FeedItem>[];

    for (int i = 0; i < mixes.length; i++) {
      final mix = mixes[i];
      final cover = (mix.coverArt != null && mix.coverArt!.isNotEmpty)
          ? mix.coverArt!
          : artworkRepair.getDailyMixCover(mix.id, songs: mix.tracks);

      final playlist = Playlist(
        id: mix.id,
        title: mix.title,
        subtitle: mix.subtitle,
        image: cover,
        songCount: mix.tracks.isNotEmpty ? mix.tracks.length : 20,
        songs: mix.tracks.isNotEmpty ? mix.tracks : null,
      );

      items.add(
        FeedItem(
          id: mix.id,
          title: mix.title,
          subtitle: mix.subtitle,
          imageUrl: cover,
          itemType: 'playlist',
          playlist: playlist,
          customData: {'badge': 'MIX ${i + 1}'},
        ),
      );
    }
    return items;
  }

  /// Caches a feed snapshot to local storage for instant stale-while-revalidate startup.
  Future<void> cacheSnapshot(HomeFeed feed, {String filter = 'All'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_cacheKeyPrefix$filter';
      final jsonStr = jsonEncode(feed.toJson());
      await prefs.setString(key, jsonStr);
    } catch (e) {
      debugPrint('[HomeFeedEngine] Failed to cache snapshot: $e');
    }
  }

  /// Reads a cached snapshot for instant rendering during cold starts or offline states.
  Future<HomeFeed?> readCachedSnapshot({String filter = 'All'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_cacheKeyPrefix$filter';
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final feed = HomeFeed.fromJson(decoded);
        return HomeFeed(
          version: feed.version,
          generatedAt: feed.generatedAt,
          sections: feed.sections,
          isFromCache: true,
          metadata: feed.metadata,
        );
      }
    } catch (e) {
      debugPrint('[HomeFeedEngine] Failed to read snapshot: $e');
    }
    return null;
  }
}
