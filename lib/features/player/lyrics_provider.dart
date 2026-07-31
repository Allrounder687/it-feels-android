import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:it_feels_music/core/utils/error_reporter.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/lyrics_service.dart';

enum LyricsMode { synced, static }

@immutable
class LyricsState {
  final LyricsMode mode;
  final LyricsResult? lyricsResult;
  final bool lyricsNotFound;
  final bool isLoading;
  final String? loadedSongId;
  final int activeIndex;
  final int syncOffsetMs;
  final String fontFamily;

  const LyricsState({
    this.mode = LyricsMode.synced,
    this.lyricsResult,
    this.lyricsNotFound = false,
    this.isLoading = false,
    this.loadedSongId,
    this.activeIndex = -1,
    this.syncOffsetMs = 350,
    this.fontFamily = 'Plus Jakarta Sans',
  });

  LyricsResult get result => lyricsResult ?? LyricsResult();

  LyricsState copyWith({
    LyricsMode? mode,
    LyricsResult? lyricsResult,
    bool? lyricsNotFound,
    bool? isLoading,
    String? loadedSongId,
    int? activeIndex,
    int? syncOffsetMs,
    String? fontFamily,
  }) {
    return LyricsState(
      mode: mode ?? this.mode,
      lyricsResult: lyricsResult ?? this.lyricsResult,
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

  @override
  LyricsState build() {
    _lyricsService = LyricsService();
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

  Future<void> loadLyricsIfNeeded(Song song, Duration position) async {
    if (state.loadedSongId != song.id) {
      state = state.copyWith(
        loadedSongId: song.id,
        isLoading: true,
        lyricsResult: null,
        lyricsNotFound: false,
      );

      final res = await _lyricsService.fetchLyrics(song);
      state = state.copyWith(
        lyricsResult: res,
        isLoading: false,
      );
    }

    if (state.lyricsResult != null && state.lyricsResult!.hasSynced) {
      final newIndex = state.getActiveLineIndex(position);
      if (newIndex != state.activeIndex) {
        state = state.copyWith(activeIndex: newIndex);
        scrollToActiveIndex();
      }
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
    state = state.copyWith(
      isLoading: true,
      lyricsResult: null,
      lyricsNotFound: false,
    );

    final res = await _lyricsService.fetchLyrics(
      song,
      onError: (message) {
        if (context != null) {
          ErrorReporter.showError(context, message);
        }
      },
    );

    final notFound = res == null || (!res.hasStatic && !res.hasSynced);
    state = state.copyWith(
      isLoading: false,
      lyricsResult: res,
      lyricsNotFound: notFound,
    );
  }
}

typedef LyricsProvider = LyricsNotifier;
