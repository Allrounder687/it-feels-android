import 'package:flutter/material.dart';
import '../core/utils/error_reporter.dart'; // Import ErrorReporter
import '../data/models/song_model.dart';
import '../data/services/lyrics_service.dart';

/// Enum representing the two display modes for lyrics.
/// - [synced]: For timestamped, auto-scrolling lyrics.
/// - [static]: For a plain block of text lyrics.
enum LyricsMode { synced, static }

/// `LyricsProvider` is a [ChangeNotifier] that handles the fetching, state management,
/// and display logic for song lyrics.
///
/// It orchestrates interactions with the [LyricsService] to retrieve both
/// synchronized ([LyricLine]) and static (plain text) lyrics. It also manages
/// the current display [mode] ([synced] or [static]) and a loading state.
///
/// This provider is consumed by UI components (like `LyricsView`) to display
/// lyrics and highlight the current line in real-time based on the song's playback position.
class LyricsProvider extends ChangeNotifier {
  /// Service for fetching lyrics from underlying APIs (e.g., LRCLIB, JioSaavn static).
  final LyricsService lyricsService;

  /// The current display mode for the lyrics ([synced] or [static]).
  LyricsMode _mode = LyricsMode.synced;

  /// The result of the last lyrics fetch, containing either synced lyrics,
  /// static lyrics, or both.
  LyricsResult? _lyricsResult;

  /// Indicates if lyrics were fetched successfully or not found.
  bool _lyricsNotFound = false;

  /// Indicates if lyrics are currently being fetched.
  bool _isLoading = false;

  /// Constructs a [LyricsProvider] requiring a [LyricsService].
  LyricsProvider({required this.lyricsService});

  /// Getter for the current lyrics display mode.
  LyricsMode get mode => _mode;

  /// Getter for the last fetched lyrics result.
  LyricsResult? get lyricsResult => _lyricsResult;

  /// Getter for the lyrics loading status.
  bool get isLoading => _isLoading;

  /// Getter to check if lyrics were not found after an attempt to fetch.
  bool get lyricsNotFound => _lyricsNotFound;

  /// Sets the lyrics display mode to a [newMode] and notifies listeners.
  /// This allows the UI to switch between synced and static views.
  void setMode(LyricsMode newMode) {
    _mode = newMode;
    notifyListeners();
  }

  /// Fetches lyrics for a given [song].
  ///
  /// **IMPORTANT:** This method now requires a [BuildContext] to display
  /// user-facing error messages via [ErrorReporter].
  ///
  /// Data Flow:
  /// 1. Sets [_isLoading] to `true`, clears any previous [_lyricsResult], and resets [_lyricsNotFound].
  /// 2. Notifies listeners to show a loading state in the UI.
  /// 3. Calls [lyricsService.fetchLyrics] to get the lyrics from the API,
  ///    passing [ErrorReporter.showError] as the `onError` callback.
  /// 4. Stores the result in [_lyricsResult].
  /// 5. Sets [_lyricsNotFound] to `true` if no lyrics (neither static nor synced) are found.
  /// 6. Sets [_isLoading] to `false` and notifies listeners again to display the
  ///    fetched lyrics or an appropriate "no lyrics" message.
  Future<void> fetchLyrics(BuildContext context, Song song) async { // Added BuildContext
    _isLoading = true;
    _lyricsResult = null;
    _lyricsNotFound = false; // Reset before fetching
    notifyListeners(); // Show loading indicator

    _lyricsResult = await lyricsService.fetchLyrics(
      song,
      onError: (message) => ErrorReporter.showError(context, message),
    );
    _isLoading = false;

    // Determine if lyrics were genuinely not found
    if (_lyricsResult == null || (!_lyricsResult!.hasStatic && !_lyricsResult!.hasSynced)) {
      _lyricsNotFound = true;
    }

    notifyListeners(); // Show lyrics or "not found" message
  }

  /// Calculates the index of the currently active lyric line for synchronized lyrics
  /// based on the song's current playback [position].
  ///
  /// This method is crucial for real-time highlighting in the UI.
  ///
  /// Logic:
  /// - Iterates backwards through the `syncedLyrics` list.
  /// - Returns the index of the first line whose timestamp is less than or equal to the [position].
  /// - Returns `0` if no line has been passed yet but lyrics exist.
  /// - Returns `-1` if there are no synced lyrics.
  int getActiveLineIndex(Duration position) {
    if (_lyricsResult == null || !_lyricsResult!.hasSynced) return -1;
    final lines = _lyricsResult!.syncedLyrics;
    for (int i = lines.length - 1; i >= 0; i--) {
      if (position >= lines[i].time) {
        return i; // Found the currently active line
      }
    }
    // If the song has started but is before the first lyric timestamp, show the first line.
    return 0;
  }
}
