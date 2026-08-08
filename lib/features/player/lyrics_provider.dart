import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:it_feels_music/core/utils/error_reporter.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/lyrics_service.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/services/audio_engine_service.dart';
import 'dart:async';

enum LyricsMode { synced, static }

@immutable
class LyricsState {
  final LyricsMode mode;
  final Map<String, LyricsResult> availableLyrics;
  final String? activeProvider;
  final bool lyricsNotFound;
  final bool isLoading;
  final String? loadedSongId;
  final int activeIndex;
  final int syncOffsetMs;
  final String fontFamily;

  const LyricsState({
    this.mode = LyricsMode.synced,
    this.availableLyrics = const {},
    this.activeProvider,
    this.lyricsNotFound = false,
    this.isLoading = false,
    this.loadedSongId,
    this.activeIndex = -1,
    this.syncOffsetMs = 350,
    this.fontFamily = 'Plus Jakarta Sans',
  });

  LyricsResult get result => activeProvider != null
      ? availableLyrics[activeProvider]!
      : LyricsResult();

  LyricsResult? get lyricsResult =>
      activeProvider != null ? availableLyrics[activeProvider] : null;

  LyricsState copyWith({
    LyricsMode? mode,
    Map<String, LyricsResult>? availableLyrics,
    String? activeProvider,
    bool? lyricsNotFound,
    bool? isLoading,
    String? loadedSongId,
    int? activeIndex,
    int? syncOffsetMs,
    String? fontFamily,
  }) {
    return LyricsState(
      mode: mode ?? this.mode,
      availableLyrics: availableLyrics ?? this.availableLyrics,
      activeProvider: activeProvider != null
          ? (activeProvider.isEmpty ? null : activeProvider)
          : this.activeProvider,
      lyricsNotFound: lyricsNotFound ?? this.lyricsNotFound,
      isLoading: isLoading ?? this.isLoading,
      loadedSongId: loadedSongId ?? this.loadedSongId,
      activeIndex: activeIndex ?? this.activeIndex,
      syncOffsetMs: syncOffsetMs ?? this.syncOffsetMs,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }

  int getActiveLineIndex(Duration position) {
    if (lyricsResult == null || !lyricsResult!.hasSynced) return -1;
    final lines = lyricsResult!.syncedLyrics;
    final adjustedPosition = position + Duration(milliseconds: syncOffsetMs);

    for (int i = lines.length - 1; i >= 0; i--) {
      if (adjustedPosition >= lines[i].time) {
        return i;
      }
    }
    return 0;
  }
}

class LyricsNotifier extends Notifier<LyricsState> {
  final ItemScrollController itemScrollController = ItemScrollController();
  late final LyricsService _lyricsService;
  Timer? _timeoutTimer;

  @override
  LyricsState build() {
    _lyricsService = LyricsService();
    final engine = locator<AudioEngineService>();
    engine.positionStream.listen((position) {
      if (state.lyricsResult != null && state.lyricsResult!.hasSynced) {
        final newIndex = state.getActiveLineIndex(position);
        if (newIndex != state.activeIndex) {
          state = state.copyWith(activeIndex: newIndex);
          scrollToActiveIndex();
        }
      }
    });
    return const LyricsState();
  }

  static const List<String> availableFonts = [
    'Plus Jakarta Sans',
    'Syne',
    'Space Grotesk',
    'Outfit',
  ];

  void setMode(LyricsMode newMode) {
    state = state.copyWith(mode: newMode);
  }

  void cycleFont() {
    final currentIndex = availableFonts.indexOf(state.fontFamily);
    final nextIndex = (currentIndex + 1) % availableFonts.length;
    state = state.copyWith(fontFamily: availableFonts[nextIndex]);
  }

  void setFontFamily(String font) {
    state = state.copyWith(fontFamily: font);
  }

  void adjustSyncOffset(int deltaMs) {
    final newOffset = (state.syncOffsetMs + deltaMs).clamp(-2000, 2000);
    state = state.copyWith(syncOffsetMs: newOffset);
  }

  void resetSyncOffset() {
    state = state.copyWith(syncOffsetMs: 350);
  }

  void switchProvider(String providerName) {
    if (state.availableLyrics.containsKey(providerName)) {
      state = state.copyWith(activeProvider: providerName, activeIndex: -1);
      scrollToActiveIndex(force: true);
    }
  }

  Future<void> loadLyricsIfNeeded(Song song) async {
    if (state.loadedSongId != song.id) {
      _timeoutTimer?.cancel();
      state = state.copyWith(
        loadedSongId: song.id,
        isLoading: true,
        availableLyrics: {},
        activeProvider: "",
        lyricsNotFound: false,
      );

      // Clear the activeProvider by passing "" to copyWith (handled in copyWith logic)
      state = LyricsState(
        loadedSongId: song.id,
        isLoading: true,
        availableLyrics: const {},
        activeProvider: null,
        lyricsNotFound: false,
        fontFamily: state.fontFamily,
        syncOffsetMs: state.syncOffsetMs,
      );

      _lyricsService.fetchLyrics(
        song,
        onResult: (res) {
          // Ensure we are still on the same song
          if (state.loadedSongId != song.id) return;

          final newMap = Map<String, LyricsResult>.from(state.availableLyrics);
          newMap[res.source] = res;

          String? newActive = state.activeProvider;
          newActive ??= res.source;

          state = state.copyWith(
            availableLyrics: newMap,
            activeProvider: newActive,
            isLoading: false,
            lyricsNotFound: false,
          );
        },
      );

      _timeoutTimer = Timer(const Duration(seconds: 5), () {
        if (state.loadedSongId == song.id && state.availableLyrics.isEmpty) {
          state = state.copyWith(isLoading: false, lyricsNotFound: true);
        }
      });
    }
  }

  void scrollToActiveIndex({bool force = false}) {
    if (itemScrollController.isAttached && state.activeIndex >= 0) {
      itemScrollController.scrollTo(
        index: state.activeIndex,
        alignment: 0.5,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> fetchLyrics(Song song, {BuildContext? context}) async {
    _timeoutTimer?.cancel();
    state = LyricsState(
      loadedSongId: song.id,
      isLoading: true,
      availableLyrics: const {},
      activeProvider: null,
      lyricsNotFound: false,
      fontFamily: state.fontFamily,
      syncOffsetMs: state.syncOffsetMs,
    );

    _lyricsService.fetchLyrics(
      song,
      onError: (message) {
        if (context != null) {
          ErrorReporter.showError(context, message);
        }
      },
      onResult: (res) {
        if (state.loadedSongId != song.id) return;

        final newMap = Map<String, LyricsResult>.from(state.availableLyrics);
        newMap[res.source] = res;

        String? newActive = state.activeProvider;
        newActive ??= res.source;

        state = state.copyWith(
          availableLyrics: newMap,
          activeProvider: newActive,
          isLoading: false,
          lyricsNotFound: false,
        );
      },
    );

    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (state.loadedSongId == song.id && state.availableLyrics.isEmpty) {
        state = state.copyWith(isLoading: false, lyricsNotFound: true);
      }
    });
  }
}

typedef LyricsProvider = LyricsNotifier;
