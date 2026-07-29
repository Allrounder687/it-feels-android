import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../core/utils/error_reporter.dart';
import '../data/models/song_model.dart';
import '../data/services/lyrics_service.dart';

enum LyricsMode { synced, static }

class LyricsProvider extends ChangeNotifier {
  final LyricsService lyricsService;

  LyricsMode _mode = LyricsMode.synced;
  LyricsResult? _lyricsResult;
  bool _lyricsNotFound = false;
  bool _isLoading = false;

  String? _loadedSongId;
  int _activeIndex = -1;
  final ItemScrollController _itemScrollController = ItemScrollController();

  LyricsProvider({required this.lyricsService});

  LyricsMode get mode => _mode;
  LyricsResult get result => _lyricsResult ?? LyricsResult();
  LyricsResult? get lyricsResult => _lyricsResult;
  bool get isLoading => _isLoading;
  bool get lyricsNotFound => _lyricsNotFound;
  int get activeIndex => _activeIndex;
  ItemScrollController get itemScrollController => _itemScrollController;

  void setMode(LyricsMode newMode) {
    _mode = newMode;
    notifyListeners();
  }

  Future<void> loadLyricsIfNeeded(Song song, Duration position) async {
    if (_loadedSongId != song.id) {
      _loadedSongId = song.id;
      _isLoading = true;
      _lyricsResult = null;
      notifyListeners();

      _lyricsResult = await lyricsService.fetchLyrics(song);
      _isLoading = false;
      notifyListeners();
    }

    if (_lyricsResult != null && _lyricsResult!.hasSynced) {
      final newIndex = getActiveLineIndex(position);
      if (newIndex != _activeIndex) {
        _activeIndex = newIndex;
        notifyListeners();

        // Autoscroll to active line
        if (_itemScrollController.isAttached && _activeIndex >= 0) {
          _itemScrollController.scrollTo(
            index: _activeIndex,
            alignment: 0.5,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        }
      }
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
    for (int i = lines.length - 1; i >= 0; i--) {
      if (position >= lines[i].time) {
        return i;
      }
    }
    return 0;
  }

  @override
  void dispose() {
    super.dispose();
  }
}
