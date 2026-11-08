import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/intelligence/charts/chart_aggregation_service.dart';

@immutable
class ChartFeedState {
  final String activeCategory;
  final List<Song> allTracks;
  final List<Song> visibleTracks;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final DateTime? lastUpdated;

  const ChartFeedState({
    this.activeCategory = 'hindi_top_50',
    this.allTracks = const [],
    this.visibleTracks = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.lastUpdated,
  });

  bool get hasMore => visibleTracks.length < allTracks.length;

  ChartFeedState copyWith({
    String? activeCategory,
    List<Song>? allTracks,
    List<Song>? visibleTracks,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    DateTime? lastUpdated,
  }) {
    return ChartFeedState(
      activeCategory: activeCategory ?? this.activeCategory,
      allTracks: allTracks ?? this.allTracks,
      visibleTracks: visibleTracks ?? this.visibleTracks,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class ChartFeedNotifier extends Notifier<ChartFeedState> {
  final ChartAggregationService _service = ChartAggregationService.instance;
  static const int _pageSize = 25;

  @override
  ChartFeedState build() {
    Future.microtask(() => loadCategory('hindi_top_50'));
    return const ChartFeedState(isLoading: true);
  }

  Future<void> loadCategory(String categoryId, {bool forceRefresh = false}) async {
    if (state.activeCategory == categoryId && state.allTracks.isNotEmpty && !forceRefresh) {
      return;
    }

    state = state.copyWith(
      activeCategory: categoryId,
      isLoading: true,
      error: null,
    );

    try {
      final tracks = await _service.fetchChartTracks(categoryId, forceRefresh: forceRefresh);
      final initialSlice = tracks.take(_pageSize).toList();
      state = state.copyWith(
        allTracks: tracks,
        visibleTracks: initialSlice,
        isLoading: false,
        lastUpdated: _service.getLastUpdated(categoryId) ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('[ChartFeedNotifier] Error loading chart $categoryId: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Unable to load charts. Please check connection.',
      );
    }
  }

  void loadMore() {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    final currentCount = state.visibleTracks.length;
    final nextSlice = state.allTracks.skip(currentCount).take(_pageSize).toList();

    state = state.copyWith(
      visibleTracks: [...state.visibleTracks, ...nextSlice],
      isLoadingMore: false,
    );
  }

  Future<void> refresh() async {
    await loadCategory(state.activeCategory, forceRefresh: true);
  }
}

final chartFeedProvider = NotifierProvider<ChartFeedNotifier, ChartFeedState>(ChartFeedNotifier.new);
