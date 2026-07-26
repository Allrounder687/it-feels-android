import 'dart:math';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:palette_generator/palette_generator.dart';
import '../core/theme/app_colors.dart';
import '../data/models/song_model.dart';
import '../data/services/audio_player_handler.dart';
import '../data/services/music_api_service.dart';
import '../services/storage_service.dart';

enum AppThemeMode {
  dynamic,
  midnight,
  burgundy,
  amoled,
}

class AudioPlayerProvider extends ChangeNotifier {
  final AudioPlayerHandler audioHandler;
  final MusicApiService apiService;

  Song? _currentSong;
  List<Song> _queue = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isShuffle = false;
  bool _isRepeat = false;
  List<Song> _favoriteSongs = [];

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  Color _themeBackgroundColor = AppColors.midnightBackground;
  Color _themeSurfaceColor = AppColors.midnightSurface;
  Color _themeAccentColor = AppColors.midnightPrimary;

  AppThemeMode _appThemeMode = AppThemeMode.dynamic;

  // Sleep Timer State
  Timer? _sleepTimer;
  DateTime? _sleepTimerEndTime;
  bool _sleepAfterCurrentTrack = false;

  AudioPlayerProvider({
    required this.audioHandler,
    required this.apiService,
  }) {
    _listenToEvents();
    _initMemory();
  }

  Future<void> _initMemory() async {
    // Load existing EQ & playback settings
    final audioSettings = await StorageService.loadAudioSettings();
    _applyAudioSettings(audioSettings);

    final state = await StorageService.loadPlaybackState();
    if (state != null) {
      final List<Song> savedQueue = state['queue'];
      final int savedIndex = state['currentIndex'];

      if (savedQueue.isNotEmpty && savedIndex >= 0 && savedIndex < savedQueue.length) {
        _queue = savedQueue;
        _currentIndex = savedIndex;
        _currentSong = _queue[_currentIndex];
        
        final mediaItems = _queue.map<MediaItem>((s) => MediaItem(
              id: s.id,
              title: s.title,
              artist: s.artist,
              artUri: Uri.tryParse(s.coverArt),
              duration: Duration(seconds: s.duration),
            )).toList();

        await audioHandler.updateQueue(mediaItems);
        await audioHandler.skipToQueueItem(_currentIndex);

        notifyListeners();
      }
    }
  }

  Future<void> _applyAudioSettings(Map<String, dynamic> settings) async {
    try {
      final equalizer = audioHandler.equalizer;
      final loudnessEnhancer = audioHandler.loudnessEnhancer;
      
      // Speed & Pitch
      final double speed = settings['speed'] ?? 1.0;
      final double pitch = settings['pitch'] ?? 1.0;
      await audioHandler.player.setSpeed(speed);
      await audioHandler.player.setPitch(pitch);

      // Loudness
      final double loudness = settings['loudness'] ?? 0.0;
      await loudnessEnhancer.setEnabled(loudness > 0.0);
      await loudnessEnhancer.setTargetGain(loudness);

      // EQ
      final List<double> eqBands = settings['eqBands'] ?? [];
      await equalizer.setEnabled(true);
      final params = await equalizer.parameters;
      for (int i = 0; i < params.bands.length; i++) {
        if (i < eqBands.length) {
          await params.bands[i].setGain(eqBands[i]);
        }
      }
    } catch (e) {
      debugPrint("Audio Enhancer initialization error: $e");
    }
  }

  void _saveMemory() {
    StorageService.savePlaybackState(_queue, _currentIndex);
  }

  void _listenToEvents() {
    audioHandler.onSkipNext = () => skipToNext();
    audioHandler.onSkipPrevious = () => skipToPrevious();
    _listenToAudioState();
    _loadFavorites();
  }

  Song? get currentSong => _currentSong;
  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get isShuffle => _isShuffle;
  bool get isRepeat => _isRepeat;
  Duration get position => _position;
  Duration get duration => _duration;
  List<Song> get favoriteSongs => _favoriteSongs;
  AppThemeMode get appThemeMode => _appThemeMode;

  bool get isSleepTimerActive => _sleepTimer != null && _sleepTimer!.isActive;
  Duration? get sleepTimerRemaining => _sleepTimerEndTime != null ? _sleepTimerEndTime!.difference(DateTime.now()) : null;
  bool get sleepAfterCurrentTrack => _sleepAfterCurrentTrack;

  void startSleepTimer(Duration duration) {
    cancelSleepTimer();
    _sleepTimerEndTime = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      audioHandler.pause();
      cancelSleepTimer();
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndTime = null;
    _sleepAfterCurrentTrack = false;
    notifyListeners();
  }

  void setSleepAfterCurrentTrack() {
    cancelSleepTimer();
    _sleepAfterCurrentTrack = true;
    notifyListeners();
  }

  void setAppThemeMode(AppThemeMode mode) {
    _appThemeMode = mode;
    notifyListeners();
  }

  Color get themeBackgroundColor {
    switch (_appThemeMode) {
      case AppThemeMode.dynamic:
        return _themeBackgroundColor;
      case AppThemeMode.midnight:
        return AppColors.midnightBackground;
      case AppThemeMode.burgundy:
        return AppColors.burgundyBackground;
      case AppThemeMode.amoled:
        return Colors.black;
    }
  }

  Color get themeSurfaceColor {
    switch (_appThemeMode) {
      case AppThemeMode.dynamic:
        return _themeSurfaceColor;
      case AppThemeMode.midnight:
        return AppColors.midnightSurface;
      case AppThemeMode.burgundy:
        return AppColors.burgundySurface;
      case AppThemeMode.amoled:
        return const Color(0xFF121212);
    }
  }

  Color get themeAccentColor {
    switch (_appThemeMode) {
      case AppThemeMode.dynamic:
        return _themeAccentColor;
      case AppThemeMode.midnight:
        return AppColors.midnightPrimary;
      case AppThemeMode.burgundy:
        return AppColors.burgundyPrimary;
      case AppThemeMode.amoled:
        return Colors.white;
    }
  }

  // --- Audio Pro Features ---
  AndroidEqualizer get equalizer => audioHandler.equalizer;
  AndroidLoudnessEnhancer get loudnessEnhancer => audioHandler.loudnessEnhancer;
  
  double get playbackSpeed => audioHandler.player.speed;
  double get playbackPitch => audioHandler.player.pitch;
  
  Future<void> setEqBandGain(int bandIndex, double gain) async {
    try {
      final params = await equalizer.parameters;
      await params.bands[bandIndex].setGain(gain);
      _saveAudioSettings();
      notifyListeners();
    } catch (e) {
      debugPrint("Error setting EQ gain: $e");
    }
  }

  Future<void> setLoudnessGain(double gain) async {
    try {
      await loudnessEnhancer.setEnabled(gain > 0.0);
      await loudnessEnhancer.setTargetGain(gain);
      _saveAudioSettings();
      notifyListeners();
    } catch (e) {
      debugPrint("Error setting Loudness gain: $e");
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    try {
      await audioHandler.player.setSpeed(speed);
      _saveAudioSettings();
      notifyListeners();
    } catch (e) {
      debugPrint("Error setting Speed: $e");
    }
  }

  Future<void> setPlaybackPitch(double pitch) async {
    try {
      await audioHandler.player.setPitch(pitch);
      _saveAudioSettings();
      notifyListeners();
    } catch (e) {
      debugPrint("Error setting Pitch: $e");
    }
  }

  Future<void> _saveAudioSettings() async {
    try {
      final params = await equalizer.parameters;
      final eqBands = params.bands.map((b) => b.gain).toList();
      
      await StorageService.saveAudioSettings(
        eqBands: eqBands,
        loudness: loudnessEnhancer.targetGain,
        speed: playbackSpeed,
        pitch: playbackPitch,
      );
    } catch (e) {
      debugPrint("Error saving Audio Settings: $e");
    }
  }

  bool isFavorite(String songId) {
    return _favoriteSongs.any((s) => s.id == songId);
  }

  void toggleFavorite(Song song) {
    if (isFavorite(song.id)) {
      _favoriteSongs.removeWhere((s) => s.id == song.id);
    } else {
      _favoriteSongs.add(song);
    }
    StorageService.saveFavorites(_favoriteSongs);
    notifyListeners();
  }

  Future<void> _loadFavorites() async {
    _favoriteSongs = await StorageService.loadFavorites();
    notifyListeners();
  }

  void _listenToAudioState() {
    audioHandler.player.playerStateStream.listen((state) async {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        if (_sleepAfterCurrentTrack) {
          _sleepAfterCurrentTrack = false;
          await audioHandler.pause();
        } else if (_isRepeat) {
          await seek(Duration.zero);
          await audioHandler.play();
        } else if (_queue.isNotEmpty) {
          await skipToNext();
        }
      }
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

  Future<void> playSong(Song song, {List<Song>? queue, int index = 0, BuildContext? context}) async {
    _currentSong = song;

    if (queue != null && queue.isNotEmpty) {
      _queue = List.from(queue);
      _currentIndex = index >= 0 && index < _queue.length ? index : 0;
      _saveMemory();
    } else {
      final existingIndex = _queue.indexWhere((s) => s.id == song.id || (s.title == song.title && s.artist == song.artist));
      if (existingIndex != -1) {
        _currentIndex = existingIndex;
      } else {
        if (_queue.isEmpty) {
          _queue = [song];
          _currentIndex = 0;
        } else {
          final insertPos = _currentIndex >= 0 && _currentIndex < _queue.length ? _currentIndex + 1 : _queue.length;
          _queue.insert(insertPos, song);
          _currentIndex = insertPos;
        }
      }
      _saveMemory();
    }

    _isLoading = true;
    notifyListeners();

    _extractPalette(song.coverArt);

    String? streamUrl;
    final downloads = await StorageService.loadDownloads();
    final downloadedSong = downloads.cast<Song?>().firstWhere((s) => s?.id == song.id, orElse: () => null);

    if (downloadedSong != null && downloadedSong.encryptedMediaUrl != null && File(downloadedSong.encryptedMediaUrl!).existsSync()) {
      streamUrl = downloadedSong.encryptedMediaUrl;
      debugPrint('[AudioPlayerProvider] Playing downloaded file for ${song.title}');
    } else {
      streamUrl = await apiService.getStreamUrl(song);
    }
    
    _isLoading = false;

    if (streamUrl != null) {
      await audioHandler.playSong(song, streamUrl);
    } else {
      debugPrint('[AudioPlayerProvider] Failed to resolve stream for ${song.title}');
    }

    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_currentSong == null) return;
    if (_isPlaying) {
      await audioHandler.pause();
    } else {
      await audioHandler.play();
    }
    _saveMemory();
  }

  Future<void> seek(Duration pos) async {
    await audioHandler.seek(pos);
  }

  Future<void> skipToNext([BuildContext? context]) async {
    if (_queue.isEmpty) return;
    int nextIndex;
    if (_isShuffle && _queue.length > 1) {
      final rng = Random();
      nextIndex = rng.nextInt(_queue.length);
      if (nextIndex == _currentIndex && _queue.length > 1) {
        nextIndex = (nextIndex + 1) % _queue.length;
      }
    } else {
      nextIndex = _currentIndex + 1;
      if (nextIndex >= _queue.length) {
        nextIndex = 0;
      }
    }
    await playSong(_queue[nextIndex], queue: _queue, index: nextIndex);
  }

  Future<void> skipToPrevious([BuildContext? context]) async {
    if (_queue.isEmpty) return;
    int prevIndex = _currentIndex - 1;
    if (prevIndex < 0) {
      prevIndex = _queue.length - 1;
    }
    await playSong(_queue[prevIndex], queue: _queue, index: prevIndex);
  }

  void addToQueue(Song song) {
    _queue.add(song);
    _saveMemory();
    notifyListeners();
  }

  void playNext(Song song) {
    if (_currentIndex >= 0 && _currentIndex < _queue.length) {
      _queue.insert(_currentIndex + 1, song);
    } else {
      _queue.add(song);
    }
    _saveMemory();
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex < 0 || oldIndex >= _queue.length || newIndex < 0 || newIndex > _queue.length) return;

    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);
    
    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }
    _saveMemory();
    notifyListeners();
  }

  Future<void> seekForward({int seconds = 10}) async {
    final target = _position + Duration(seconds: seconds);
    final clamped = target > _duration ? _duration : target;
    await seek(clamped);
  }

  Future<void> seekBackward({int seconds = 10}) async {
    final target = _position - Duration(seconds: seconds);
    final clamped = target < Duration.zero ? Duration.zero : target;
    await seek(clamped);
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void toggleRepeat() {
    _isRepeat = !_isRepeat;
    notifyListeners();
  }

  Future<void> _extractPalette(String imageUrl) async {
    if (imageUrl.isEmpty) return;
    try {
      ImageProvider provider = imageUrl.startsWith('http') 
          ? NetworkImage(imageUrl) as ImageProvider
          : FileImage(File(imageUrl));
      final palette = await PaletteGenerator.fromImageProvider(
        ResizeImage(provider, width: 100, height: 100),
        maximumColorCount: 6,
      );

      final dominant = palette.dominantColor?.color ?? AppColors.burgundyBackground;
      final darkMuted = palette.darkMutedColor?.color ?? AppColors.burgundySurface;
      final lightVibrant = palette.lightVibrantColor?.color ?? AppColors.burgundyAccent;

      _themeBackgroundColor = HSLColor.fromColor(dominant).withLightness(0.12).toColor();
      _themeSurfaceColor = HSLColor.fromColor(darkMuted).withLightness(0.18).toColor();
      _themeAccentColor = lightVibrant;

      notifyListeners();
    } catch (e) {
      debugPrint('[AudioPlayerProvider] Palette extraction error: $e');
    }
  }
}
