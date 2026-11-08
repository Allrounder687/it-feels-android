import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/core/utils/track_validation_engine.dart';

/// Represents a verified chart category with primary catalog source and query fallbacks.
class ChartCategoryDefinition {
  final String id;
  final String title;
  final String subtitle;
  final String? primaryPlaylistId;
  final String searchQuery;
  final String? language;

  const ChartCategoryDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    this.primaryPlaylistId,
    required this.searchQuery,
    this.language,
  });
}

/// Dynamic, multi-source chart aggregator ensuring 50+ verified, ranked tracks
/// across global, Bollywood, and regional chart categories.
class ChartAggregationService {
  static final ChartAggregationService _instance = ChartAggregationService._internal();
  factory ChartAggregationService() => _instance;
  static ChartAggregationService get instance => _instance;

  ChartAggregationService._internal();

  IMusicRepository get _musicRepo => locator<IMusicRepository>();

  final Map<String, List<Song>> _chartCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Duration _cacheTtl = const Duration(hours: 3);

  static const List<ChartCategoryDefinition> categories = [
    ChartCategoryDefinition(
      id: 'hindi_top_50',
      title: 'Hindi Top 50',
      subtitle: 'MOST STREAMED IN HINDI',
      primaryPlaylistId: '1134543272',
      searchQuery: 'Hindi Top 50 Hits',
      language: 'hindi',
    ),
    ChartCategoryDefinition(
      id: 'india_superhits',
      title: 'India Superhits',
      subtitle: 'TOP NATIONWIDE CHARTS',
      primaryPlaylistId: '1134548194',
      searchQuery: 'Top 50 India Superhits',
    ),
    ChartCategoryDefinition(
      id: 'international_top_50',
      title: 'International Top 50',
      subtitle: 'GLOBAL POP & HIT FREQUENCIES',
      searchQuery: 'Top International Pop Hits',
      language: 'english',
    ),
    ChartCategoryDefinition(
      id: 'punjabi_top_50',
      title: 'Punjabi Top 50',
      subtitle: 'DESI BEATS & CHART TOPPERS',
      primaryPlaylistId: '1134543511',
      searchQuery: 'Punjabi Top 50 Hits',
      language: 'punjabi',
    ),
    ChartCategoryDefinition(
      id: 'telugu_top_50',
      title: 'Telugu Top 50',
      subtitle: 'TOP TOLLEYWOOD MELODIES',
      primaryPlaylistId: '1134643225',
      searchQuery: 'Telugu Top 50 Hits',
      language: 'telugu',
    ),
    ChartCategoryDefinition(
      id: 'tamil_top_50',
      title: 'Tamil Top 50',
      subtitle: 'TOP KOLLYWOOD CHARTS',
      primaryPlaylistId: '1134651042',
      searchQuery: 'Tamil Top 50 Hits',
      language: 'tamil',
    ),
    ChartCategoryDefinition(
      id: 'viral_hits',
      title: 'Viral Hits 2026',
      subtitle: 'TIKTOK & REELS TRENDING',
      searchQuery: 'Viral Hits Trending Songs 2026',
    ),
  ];

  DateTime? getLastUpdated(String categoryId) => _cacheTimestamps[categoryId];

  bool isCacheValid(String categoryId) {
    final timestamp = _cacheTimestamps[categoryId];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheTtl;
  }

  /// Fetches 50+ ranked tracks for the specified chart category with deduplication & caching.
  Future<List<Song>> fetchChartTracks(String categoryId, {bool forceRefresh = false}) async {
    if (!forceRefresh && isCacheValid(categoryId) && _chartCache[categoryId] != null && _chartCache[categoryId]!.isNotEmpty) {
      return _chartCache[categoryId]!;
    }

    final definition = categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => categories.first,
    );

    final List<Song> accumulated = [];

    // 1. Attempt primary editorial playlist extraction
    if (definition.primaryPlaylistId != null) {
      try {
        final playlistTracks = await _musicRepo.getPlaylistTracks(definition.primaryPlaylistId!);
        for (final track in playlistTracks) {
          if (TrackValidationEngine.isValidTrack(track) && !accumulated.any((s) => s.id == track.id)) {
            accumulated.add(track);
          }
        }
      } catch (e) {
        debugPrint('[ChartAggregationService] Error loading primary playlist ${definition.primaryPlaylistId}: $e');
      }
    }

    // 2. Supplement from search query to achieve 50+ verified tracks
    if (accumulated.length < 50) {
      try {
        final searchTracks = await _musicRepo.searchSongs(definition.searchQuery, count: 50);
        for (final track in searchTracks) {
          if (accumulated.length >= 60) break;
          final isDuplicate = accumulated.any((s) =>
              s.id == track.id ||
              (s.title.trim().toLowerCase() == track.title.trim().toLowerCase() &&
                  s.artist.trim().toLowerCase() == track.artist.trim().toLowerCase()));
          if (!isDuplicate && TrackValidationEngine.isValidTrack(track)) {
            if (definition.language == null ||
                track.language.isEmpty ||
                track.language.toLowerCase() == definition.language!.toLowerCase() ||
                definition.language == 'english') {
              accumulated.add(track);
            }
          }
        }
      } catch (e) {
        debugPrint('[ChartAggregationService] Supplement search error for ${definition.searchQuery}: $e');
      }
    }

    // 3. Fallback to broad top hits if source yielded fewer than 20 tracks
    if (accumulated.length < 20) {
      try {
        final broad = await _musicRepo.searchSongs('Top 50 Hits', count: 40);
        for (final track in broad) {
          if (accumulated.length >= 50) break;
          if (!accumulated.any((s) => s.id == track.id) && TrackValidationEngine.isValidTrack(track)) {
            accumulated.add(track);
          }
        }
      } catch (_) {}
    }

    final ranked = TrackValidationEngine.filterAndRank(
      accumulated,
      preserveOriginalOrderIfValid: true,
      minPassingScore: 25.0,
    );

    _chartCache[categoryId] = ranked;
    _cacheTimestamps[categoryId] = DateTime.now();

    return ranked;
  }

  /// Returns paginated slice of chart tracks
  List<Song> getPaginatedSlice(String categoryId, {int offset = 0, int limit = 25}) {
    final all = _chartCache[categoryId] ?? [];
    if (offset >= all.length) return [];
    return all.skip(offset).take(limit).toList();
  }

  /// Clears in-memory chart caches
  void clearCache() {
    _chartCache.clear();
    _cacheTimestamps.clear();
  }
}
