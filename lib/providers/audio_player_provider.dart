import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import '../core/theme/app_colors.dart';
import '../data/models/song_model.dart';
import '../data/services/audio_player_handler.dart';
import '../data/services/jiosaavn_api_service.dart';
import '../services/storage_service.dart';

/// `AudioPlayerProvider` is a [ChangeNotifier] that manages the overall audio playback state
/// of the application. It acts as the central hub for music playback, queue management,
/// user preferences (like favorites, shuffle, repeat), and dynamic theme color extraction
/// based on the current song's cover art.
///
/// This provider orchestrates interactions between the UI, the [AudioPlayerHandler]
/// for low-level audio control, the [JioSaavnApiService] for resolving stream URLs,
/// and the [StorageService] for persisting user data like favorite songs.
///
/// It exposes various getters to reflect the current state (e.g., [currentSong], [isPlaying],
/// [position], [themeBackgroundColor]) and methods to control playback (e.g., [playSong],
/// [togglePlayPause], [seek], [skipToNext]) and preferences.
class AudioPlayerProvider extends ChangeNotifier {
  /// Handles the actual audio playback controls (play, pause, seek) and manages
  /// the underlying `just_audio` and `audio_service` instances.
  final AudioPlayerHandler audioHandler;

  /// Service for interacting with the JioSaavn API, primarily used here to
  /// resolve stream URLs for songs.
  final JioSaavnApiService apiService;

  /// The currently playing or paused song.
  Song? _currentSong;

  /// The list of songs currently in the playback queue.
  List<Song> _queue = [];

  /// The index of the [currentSong] within the [_queue].
  int _currentIndex = -1;

  /// Indicates whether the audio is currently playing.
  bool _isPlaying = false;

  /// Indicates if a song is currently being loaded (e.g., stream URL resolution).
  bool _isLoading = false;

  /// Indicates if shuffle mode is enabled for the queue.
  bool _isShuffle = false;

  /// Indicates if repeat mode is enabled for the current song or queue.
  bool _isRepeat = false;

  /// List of songs marked as favorites by the user.
  List<Song> _favoriteSongs = [];

  /// The current playback position of the [currentSong].
  Duration _position = Duration.zero;

  /// The total duration of the [currentSong].
  Duration _duration = Duration.zero;

  /// Background color extracted from the [currentSong]'s cover art,
  /// adjusted for dark theme.
  Color _themeBackgroundColor = AppColors.burgundyBackground;

  /// Surface color extracted from the [currentSong]'s cover art,
  /// adjusted for dark theme.
  Color _themeSurfaceColor = AppColors.burgundySurface;

  /// Accent color extracted from the [currentSong]'s cover art.
  Color _themeAccentColor = AppColors.burgundyAccent;

  /// Constructs an [AudioPlayerProvider] requiring an [AudioPlayerHandler]
  /// for audio control and a [JioSaavnApiService] for stream resolution.
  ///
  /// Initializes listeners for audio state changes and loads previously saved
  /// favorite songs.
  AudioPlayerProvider({
    required this.audioHandler,
    required this.apiService,
  }) {
    _listenToAudioState();
    _loadFavorites();
  }

  /// Getter for the currently playing or paused song.
  Song? get currentSong => _currentSong;

  /// Getter for the current playback queue.
  List<Song> get queue => _queue;

  /// Getter for the index of the [currentSong] in the [_queue].
  int get currentIndex => _currentIndex;

  /// Getter for the playback status.
  bool get isPlaying => _isPlaying;

  /// Getter for the loading status.
  bool get isLoading => _isLoading;

  /// Getter for the shuffle mode status.
  bool get isShuffle => _isShuffle;

  /// Getter for the repeat mode status.
  bool get isRepeat => _isRepeat;

  /// Getter for the current playback position.
  Duration get position => _position;

  /// Getter for the total duration of the current song.
  Duration get duration => _duration;

  /// Getter for the list of favorite songs.
  List<Song> get favoriteSongs => _favoriteSongs;

  /// Getter for the dynamically determined theme background color.
  Color get themeBackgroundColor => _themeBackgroundColor;

  /// Getter for the dynamically determined theme surface color.
  Color get themeSurfaceColor => _themeSurfaceColor;

  /// Getter for the dynamically determined theme accent color.
  Color get themeAccentColor => _themeAccentColor;

  /// Checks if a song with the given [songId] is currently in the favorite songs list.
  bool isFavorite(String songId) {
    return _favoriteSongs.any((s) => s.id == songId);
  }

  /// Toggles the favorite status of a [song].
  /// If the song is already a favorite, it's removed; otherwise, it's added.
  /// The updated list is then saved via [StorageService] and listeners are notified.
  void toggleFavorite(Song song) {
    if (isFavorite(song.id)) {
      _favoriteSongs.removeWhere((s) => s.id == song.id);
    } else {
      _favoriteSongs.add(song);
    }
    StorageService.saveFavorites(_favoriteSongs); // Persist changes
    notifyListeners();
  }

  /// Loads favorite songs from persistent storage using [StorageService]
  /// and updates the [_favoriteSongs] list.
  Future<void> _loadFavorites() async {
    _favoriteSongs = await StorageService.loadFavorites();
    notifyListeners();
  }

  /// Sets up listeners for various audio player state streams from the [audioHandler].
  ///
  /// It listens to:
  /// - [playerStateStream] for changes in playing/paused status.
  /// - [positionStream] for continuous updates of the current playback position.
  /// - [durationStream] for updates to the total duration of the current media.
  /// Notifies listeners on each relevant state change.
  void _listenToAudioState() {
    audioHandler.player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
    });

    audioHandler.player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    audioHandler.player.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });
  }

  /// Plays a given [song].
  ///
  /// Optionally updates the playback [queue] and sets the [index] of the
  /// [currentSong] within that queue.
  ///
  /// Data Flow:
  /// 1. Sets the [currentSong], updates [_queue] and [_currentIndex].
  /// 2. Sets [_isLoading] to `true` and notifies listeners to show loading state in UI.
  /// 3. Initiates dynamic palette extraction from the song's [coverArt].
  /// 4. Calls [apiService.getStreamUrl] to resolve the playable stream URL. This
  ///    might involve API calls and decryption.
  /// 5. Once the stream URL is obtained (or fails), sets [_isLoading] to `false`.
  /// 6. If a valid [streamUrl] is available, it commands the [audioHandler] to
  ///    play the song.
  /// 7. Notifies listeners again to update UI elements like play/pause buttons,
  ///    song details, and theme colors.
  Future<void> playSong(Song song, {List<Song>? queue, int index = 0}) async {
    _currentSong = song;
    if (queue != null) {
      _queue = List.from(queue);
      _currentIndex = index;
    } else {
      // If no queue is provided, play the single song and make it the only item in a new queue.
      _queue = [song];
      _currentIndex = 0;
    }

    _isLoading = true;
    notifyListeners(); // Notify UI that loading has started

    // Trigger palette extraction in the background
    _extractPalette(song.coverArt);

    // Resolve stream URL, potentially involving API call and decryption
    final streamUrl = await apiService.getStreamUrl(song);
    _isLoading = false; // Loading finished, regardless of success or failure

    if (streamUrl != null) {
      // Command the audio handler to play the resolved stream
      await audioHandler.playSong(song, streamUrl);
    } else {
      debugPrint('[AudioPlayerProvider] Failed to resolve stream for ${song.title}');
      // Handle scenario where stream resolution fails, e.g., show a toast or error message
    }

    notifyListeners(); // Notify UI about loading state, current song, and potentially theme changes
  }

  /// Toggles the playback state between playing and paused.
  /// Requires a [currentSong] to be set.
  Future<void> togglePlayPause() async {
    if (_currentSong == null) return; // Cannot play/pause if no song is selected
    if (_isPlaying) {
      await audioHandler.pause();
    } else {
      await audioHandler.play();
    }
  }

  /// Seeks to a specific [position] in the current song's playback.
  Future<void> seek(Duration pos) async {
    await audioHandler.seek(pos);
  }

  /// Skips to the next song in the playback queue.
  /// If at the end of the queue, it wraps around to the beginning.
  ///
  /// Data Flow:
  /// 1. Calculates the index of the next song based on the current queue and [_currentIndex].
  ///    (Currently, shuffle logic is not integrated here but would typically affect next index calculation).
  /// 2. Calls [playSong] with the next song, effectively triggering a full song load and playback.
  Future<void> skipToNext() async {
    if (_queue.isEmpty || _currentIndex < 0) return;
    int nextIndex = _currentIndex + 1;
    if (nextIndex >= _queue.length) {
      nextIndex = 0; // Loop back to the start
    }
    // Play the next song, passing the entire queue to maintain context
    await playSong(_queue[nextIndex], queue: _queue, index: nextIndex);
  }

  /// Skips to the previous song in the playback queue.
  /// If at the beginning of the queue, it wraps around to the end.
  ///
  /// Data Flow:
  /// 1. Calculates the index of the previous song based on the current queue and [_currentIndex].
  /// 2. Calls [playSong] with the previous song.
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty || _currentIndex < 0) return;
    int prevIndex = _currentIndex - 1;
    if (prevIndex < 0) {
      prevIndex = _queue.length - 1; // Loop back to the end
    }
    // Play the previous song, passing the entire queue to maintain context
    await playSong(_queue[prevIndex], queue: _queue, index: prevIndex);
  }

  /// Toggles the shuffle mode on or off.
  /// Currently, this only updates the [_isShuffle] flag. The actual
  /// queue reordering logic based on shuffle would typically be implemented
  /// when [skipToNext]/[skipToPrevious] are called, or when the queue is loaded.
  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  /// Toggles the repeat mode (e.g., repeat current song, repeat queue, no repeat).
  /// Currently, this only updates the [_isRepeat] flag. The actual
  /// playback logic based on repeat would typically be implemented in the
  /// [AudioPlayerHandler] or in the logic determining the next song.
  void toggleRepeat() {
    _isRepeat = !_isRepeat;
    notifyListeners();
  }

  /// Extracts dominant colors from the provided [imageUrl] (typically the song's cover art)
  /// and updates the theme colors ([_themeBackgroundColor], [_themeSurfaceColor],
  /// [_themeAccentColor]).
  ///
  /// Data Flow:
  /// 1. Uses `PaletteGenerator.fromImageProvider` to asynchronously extract colors.
  /// 2. Derives background and surface colors from dominant/darkMuted colors,
  ///    adjusting lightness for a consistent dark theme aesthetic.
  /// 3. Sets the accent color from a vibrant color in the palette.
  /// 4. Notifies listeners to trigger UI rebuilds that depend on these theme colors.
  /// 5. Falls back to default burgundy colors on error or if no colors can be extracted.
  Future<void> _extractPalette(String imageUrl) async {
    if (imageUrl.isEmpty) return;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
        maximumColorCount: 8, // Limit color search for performance
      );

      // Extract colors, with fallbacks to ensure colors are always defined
      final dominant = palette.dominantColor?.color ?? AppColors.burgundyBackground;
      final darkMuted = palette.darkMutedColor?.color ?? AppColors.burgundySurface;
      final lightVibrant = palette.lightVibrantColor?.color ?? AppColors.burgundyAccent;

      // Adjust derived colors for a cohesive dark theme look
      _themeBackgroundColor = HSLColor.fromColor(dominant).withLightness(0.12).toColor();
      _themeSurfaceColor = HSLColor.fromColor(darkMuted).withLightness(0.18).toColor();
      _themeAccentColor = lightVibrant;

      notifyListeners(); // Update UI with new theme colors
    } catch (e) {
      debugPrint('[AudioPlayerProvider] Palette extraction error: $e');
      // On error, colors will remain their previous value or initial default
    }
  }
}
