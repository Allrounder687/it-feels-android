import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/intelligence/feed/home_feed_models.dart';
import 'package:it_feels_music/core/intelligence/feed/home_feed_engine.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/home/home_provider.dart';
import 'package:it_feels_music/features/library/listening_history_provider.dart';

class HomeFeedState {
  final HomeFeed? feed;
  final bool isLoading;
  final String? error;
  final String activeFilter;

  const HomeFeedState({
    this.feed,
    this.isLoading = false,
    this.error,
    this.activeFilter = 'All',
  });

  HomeFeedState copyWith({
    HomeFeed? feed,
    bool? isLoading,
    String? error,
    String? activeFilter,
  }) {
    return HomeFeedState(
      feed: feed ?? this.feed,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }
}

class HomeFeedNotifier extends StateNotifier<HomeFeedState> {
  final Ref ref;
  final HomeFeedEngine _engine = HomeFeedEngine.instance;

  HomeFeedNotifier(this.ref) : super(const HomeFeedState()) {
    _init();
  }

  Future<void> _init() async {
    // 1. Instantly hydrate cached snapshot for instant zero-lag rendering
    final cached = await _engine.readCachedSnapshot(filter: state.activeFilter);
    if (cached != null) {
      state = state.copyWith(feed: cached);
    }

    // 2. Reactively compose feed when underlying HomeState or History changes
    ref.listen<HomeState>(homeProvider, (_, nextHomeState) {
      _recompose(homeState: nextHomeState);
    });

    ref.listen<ListeningHistoryState>(listeningHistoryProvider, (_, nextHistory) {
      _recompose(historyState: nextHistory);
    });

    // 3. Initial composition
    _recompose();
  }

  void _recompose({HomeState? homeState, ListeningHistoryState? historyState}) {
    final currentHome = homeState ?? ref.read(homeProvider);
    final currentHistory = historyState ?? ref.read(listeningHistoryProvider);

    final composed = _engine.composeFeed(
      homeState: currentHome,
      historyState: currentHistory,
      activeFilter: state.activeFilter,
    );

    state = state.copyWith(feed: composed, isLoading: false);
    _engine.cacheSnapshot(composed, filter: state.activeFilter);
  }

  void setFilter(String filter) {
    if (state.activeFilter == filter) return;
    state = state.copyWith(activeFilter: filter);

    final homeNotifier = ref.read(homeProvider.notifier);
    final homeState = ref.read(homeProvider);

    switch (filter) {
      case 'Bollywood':
        if (homeState.bollywoodSongs.isEmpty) {
          homeNotifier.fetchBollywoodSongs();
        }
        break;
      case 'International':
        if (homeState.hollywoodSongs.isEmpty) {
          homeNotifier.fetchHollywoodSongs();
        }
        break;
      case 'Punjabi':
        if (homeState.punjabiSongs.isEmpty) {
          homeNotifier.fetchPunjabiSongs();
        }
        break;
      case 'Charts':
        if (homeState.chartPlaylists.isEmpty) {
          homeNotifier.fetchCharts();
        }
        break;
      case 'For You':
        if (homeState.youPlaylists.isEmpty) {
          final history = ref.read(listeningHistoryProvider);
          homeNotifier.fetchYouSongs(history.recentlyPlayed.map((s) => s.artist).toSet().toList());
        }
        break;
    }

    _recompose();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await ref.read(homeProvider.notifier).selectCategory('Music');
    await ref.read(homeProvider.notifier).fetchCharts();
    _recompose();
  }
}

final homeFeedProvider = StateNotifierProvider<HomeFeedNotifier, HomeFeedState>((ref) {
  return HomeFeedNotifier(ref);
});
