import 'package:it_feels_music/core/utils/error_reporter.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:it_feels_music/core/utils/error_reporter.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/lyrics_service.dart';

enum LyricsMode { synced, static }

class LyricsProvider extends ChangeNotifier {
  final LyricsService lyricsService;

  LyricsMode _mode = LyricsMode.synced;
  LyricsResult? _lyricsResult;
  bool _lyricsNotFound = false;
  bool _isLoading = false;

  String? _loadedSongId;
  int _activeIndex = -1;
  int _syncOffsetMs = 350; // Default +350ms compensation for audio buffer latency
  String _fontFamily = 'Plus Jakarta Sans'; // Sleek modern lyrics font
  final ItemScrollController _itemScrollController = ItemScrollController();

  LyricsProvider({required this.lyricsService});

  LyricsMode get mode => _mode;
  LyricsResult get result => _lyricsResult ?? LyricsResult();
  LyricsResult? get lyricsResult => _lyricsResult;
  bool get isLoading => _isLoading;
  bool get lyricsNotFound => _lyricsNotFound;
  int get activeIndex => _activeIndex;
  int get syncOffsetMs => _syncOffsetMs;
  String get fontFamily => _fontFamily;
  ItemScrollController get itemScrollController => _itemScrollController;

  void setMode(LyricsMode newMode) {
    _mode = newMode;
    notifyListeners();
  }

  static const List<String> availableFonts = [
    'Plus Jakarta Sans',
    'Syne',
    'Space Grotesk',
    'Outfit',
  ];

  void cycleFont() {
    final currentIndex = availableFonts.indexOf(_fontFamily);
    final nextIndex = (currentIndex + 1) % availableFonts.length;
    _fontFamily = availableFonts[nextIndex];
    notifyListeners();
  }

  void setFontFamily(String font) {
    _fontFamily = font;
    notifyListeners();
  }

  void adjustSyncOffset(int deltaMs) {
    _syncOffsetMs = (_syncOffsetMs + deltaMs).clamp(-2000, 2000);
    notifyListeners();
  }

  void resetSyncOffset() {
    _syncOffsetMs = 350;
    notifyListeners();
  }

  Future<void> loadLyricsIfNeeded(Song song, Duration position) async {
    if (_loadedSongId != song.id) {
      _loadedSongId = song.id;
      _isLoading = true;
      _lyricsResult = null;
      _lyricsNotFound = false;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });

      _lyricsResult = await lyricsService.fetchLyrics(song);
      _isLoading = false;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }

    if (_lyricsResult != null && _lyricsResult!.hasSynced) {
      final newIndex = getActiveLineIndex(position);
      if (newIndex != _activeIndex) {
        _activeIndex = newIndex;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
          scrollToActiveIndex();
        });
      }
    }
  }

  void scrollToActiveIndex({bool force = false}) {
    if (_itemScrollController.isAttached && _activeIndex >= 0) {
      _itemScrollController.scrollTo(
        index: _activeIndex,
        alignment: 0.5,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> fetchLyrics(Song song, {BuildContext? context}) async {
    _isLoading = true;
    _lyricsResult = null;
    _lyricsNotFound = false;
    notifyListeners();

    _lyricsResult = await lyricsService.fetchLyrics(
      song,
      onError: (message) {
        if (context != null) {
          ErrorReporter.showError(context, message);
        }
      },
    );
    _isLoading = false;

    if (_lyricsResult == null || (!_lyricsResult!.hasStatic && !_lyricsResult!.hasSynced)) {
      _lyricsNotFound = true;
    }

    notifyListeners();
  }

  int getActiveLineIndex(Duration position) {
    if (_lyricsResult == null || !_lyricsResult!.hasSynced) return -1;
    final lines = _lyricsResult!.syncedLyrics;
    
    // Apply sync offset compensation to eliminate audio buffer latency lag
    final adjustedPosition = position + Duration(milliseconds: _syncOffsetMs);

    for (int i = lines.length - 1; i >= 0; i--) {
      if (adjustedPosition >= lines[i].time) {
        return i;
      }
    }
    return 0;
  }

}
