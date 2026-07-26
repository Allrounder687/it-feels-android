import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:palette_generator/palette_generator.dart';
import '../core/theme/app_colors.dart';
import '../data/models/song_model.dart';
import '../data/services/audio_player_handler.dart';
import '../data/services/jiosaavn_api_service.dart';
import '../services/storage_service.dart';

class AudioPlayerProvider extends ChangeNotifier {
  final AudioPlayerHandler audioHandler;
  final JioSaavnApiService apiService;

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

  Color _themeBackgroundColor = AppColors.burgundyBackground;
  Color _themeSurfaceColor = AppColors.burgundySurface;
  Color _themeAccentColor = AppColors.burgundyAccent;

  AudioPlayerProvider({
    required this.audioHandler,
    required this.apiService,
  }) {
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

  Color get themeBackgroundColor => _themeBackgroundColor;
  Color get themeSurfaceColor => _themeSurfaceColor;
  Color get themeAccentColor => _themeAccentColor;

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
        if (_isRepeat) {
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
    } else {
      // If no explicit queue provided, manage existing queue smart
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
    }

    _isLoading = true;
    notifyListeners();

    _extractPalette(song.coverArt);

    final streamUrl = await apiService.getStreamUrl(song);
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
    notifyListeners();
  }

  void playNext(Song song) {
    if (_currentIndex >= 0 && _currentIndex < _queue.length) {
      _queue.insert(_currentIndex + 1, song);
    } else {
      _queue.add(song);
    }
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
