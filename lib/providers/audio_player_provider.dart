import 'dart:math';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:vibration/vibration.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import '../core/theme/app_colors.dart';
import '../data/models/song_model.dart';
import '../data/services/audio_player_handler.dart';
import '../data/services/music_api_service.dart';
import '../services/storage_service.dart';
import '../services/room_service.dart';
import '../services/backend_api_service.dart';
import '../data/services/lyrics_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

enum AppThemeMode {
  dynamic,
  midnight,
  burgundy,
  amoled,
  materialYou,
  light,
}

class AudioPlayerProvider extends ChangeNotifier {
  final AudioPlayerHandler audioHandler;
  final MusicApiService apiService;
  final LyricsService _lyricsService = LyricsService();

  Song? _currentSong;
  List<Song> _queue = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isShuffle = false;
  bool _isRepeat = false;
  List<Song> _favoriteSongs = [];
  bool _hasSentTelemetryForCurrentSong = false;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  Color _themeBackgroundColor = AppColors.midnightBackground;
  Color _themeSurfaceColor = AppColors.midnightSurface;
  Color _themeAccentColor = AppColors.midnightPrimary;

  Color? _materialYouSurface;
  Color? _materialYouSurfaceContainer;
  Color? _materialYouPrimary;

  AppThemeMode _appThemeMode = AppThemeMode.dynamic;

  // Sleep Timer State
  Timer? _sleepTimer;
  DateTime? _sleepTimerEndTime;
  bool _sleepAfterCurrentTrack = false;

  // Pro Features & Haptics State
  bool _isDspEngineEnabled = false;
  bool _uiHapticsEnabled = true;
  bool _audioSyncHapticsEnabled = false;
  Timer? _audioSyncHapticTimer;

  // Listen Together State
  final RoomService _roomService = RoomService();
  String? _currentRoomId;
  bool _isHost = false;
  StreamSubscription<DatabaseEvent>? _roomSubscription;
  int _lastSyncedSecond = -1;

  String? get currentRoomId => _currentRoomId;
  bool get isHost => _isHost;
  bool get isInRoom => _currentRoomId != null;

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

      // Pro Features
      _isDspEngineEnabled = settings['dspEngine'] ?? false;
      _uiHapticsEnabled = settings['uiHaptics'] ?? true;
      _audioSyncHapticsEnabled = settings['audioSyncHaptics'] ?? false;
      _isAutoplayEnabled = settings['autoplay'] ?? true;
      _crossfadeDuration = settings['crossfade'] ?? 0.0;

      if (_isDspEngineEnabled) {
        await _enableDspEngine(equalizer, loudnessEnhancer);
      } else {
        await _disableDspEngine(equalizer, loudnessEnhancer);
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
    audioHandler.onToggleFavorite = () async {
      if (_currentSong != null) {
        toggleFavorite(_currentSong!);
      }
    };
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

  bool get isDspEngineEnabled => _isDspEngineEnabled;
  bool get uiHapticsEnabled => _uiHapticsEnabled;
  bool get audioSyncHapticsEnabled => _audioSyncHapticsEnabled;

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
    _saveMemory();
    notifyListeners();
  }

  void setMaterialYouColors(Color surface, Color surfaceContainer, Color primary) {
    _materialYouSurface = surface;
    _materialYouSurfaceContainer = surfaceContainer;
    _materialYouPrimary = primary;
    if (_appThemeMode == AppThemeMode.materialYou) {
      notifyListeners();
    }
  }

  Color get themeBackgroundColor {
    switch (_appThemeMode) {
      case AppThemeMode.dynamic:
        return _themeBackgroundColor;
      case AppThemeMode.materialYou:
        return _materialYouSurface ?? AppColors.midnightBackground;
      case AppThemeMode.midnight:
        return AppColors.midnightBackground;
      case AppThemeMode.burgundy:
        return AppColors.burgundyBackground;
      case AppThemeMode.amoled:
        return Colors.black;
      case AppThemeMode.light:
        return const Color(0xFFF0F2F5);
    }
  }

  Color get themeSurfaceColor {
    switch (_appThemeMode) {
      case AppThemeMode.dynamic:
        return _themeSurfaceColor;
      case AppThemeMode.materialYou:
        return _materialYouSurfaceContainer ?? AppColors.midnightSurface;
      case AppThemeMode.midnight:
        return AppColors.midnightSurface;
      case AppThemeMode.burgundy:
        return AppColors.burgundySurface;
      case AppThemeMode.amoled:
        return const Color(0xFF121212);
      case AppThemeMode.light:
        return Colors.white;
    }
  }

  Color get themeAccentColor {
    switch (_appThemeMode) {
      case AppThemeMode.dynamic:
        return _themeAccentColor;
      case AppThemeMode.materialYou:
        return _materialYouPrimary ?? AppColors.midnightPrimary;
      case AppThemeMode.midnight:
        return AppColors.midnightPrimary;
      case AppThemeMode.burgundy:
        return AppColors.burgundyPrimary;
      case AppThemeMode.amoled:
        return Colors.white;
      case AppThemeMode.light:
        return const Color(0xFF3B82F6);
    }
  }

  Color get themeTextColor {
    return _appThemeMode == AppThemeMode.light ? Colors.black87 : Colors.white;
  }

  Color get themeMutedTextColor {
    return _appThemeMode == AppThemeMode.light ? Colors.black54 : Colors.white54;
  }

  Color get themeInvertedTextColor {
    return _appThemeMode == AppThemeMode.light ? Colors.white : Colors.black;
  }

  Color get themeCardColor {
    switch (_appThemeMode) {
      case AppThemeMode.light:
        return Colors.white;
      case AppThemeMode.amoled:
        return const Color(0xFF1A1A1A);
      case AppThemeMode.burgundy:
        return AppColors.burgundyCard;
      default:
        return AppColors.midnightCard;
    }
  }

  // --- Haptics ---
  Future<void> triggerHaptic({bool heavy = false}) async {
    if (!_uiHapticsEnabled) return;
    
    if (await Vibration.hasVibrator() ?? false) {
      if (heavy) {
        Vibration.vibrate(duration: 50, amplitude: 128);
      } else {
        Vibration.vibrate(duration: 20, amplitude: 64);
      }
    }
  }

  Future<void> setUiHaptics(bool enabled) async {
    _uiHapticsEnabled = enabled;
    _saveAudioSettings();
    notifyListeners();
  }

  Future<void> setAudioSyncHaptics(bool enabled) async {
    _audioSyncHapticsEnabled = enabled;
    _saveAudioSettings();
    if (_isPlaying && enabled) {
      _startAudioSyncHaptics();
    } else {
      _stopAudioSyncHaptics();
    }
    notifyListeners();
  }

  void _startAudioSyncHaptics() {
    _audioSyncHapticTimer?.cancel();
    // Simulate beats for audio-sync haptics (Mocked until native FFT is available)
    _audioSyncHapticTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) async {
      if (_isPlaying && _audioSyncHapticsEnabled && (await Vibration.hasVibrator() ?? false)) {
        Vibration.vibrate(duration: 15, amplitude: 40); // Subtle beat pulse
      } else {
        timer.cancel();
      }
    });
  }

  void _stopAudioSyncHaptics() {
    _audioSyncHapticTimer?.cancel();
  }

  // --- Audio Pro Features ---
  AndroidEqualizer get equalizer => audioHandler.equalizer;
  AndroidLoudnessEnhancer get loudnessEnhancer => audioHandler.loudnessEnhancer;
  
  double get playbackSpeed => audioHandler.player.speed;
  double get playbackPitch => audioHandler.player.pitch;

  Future<void> setDspEngine(bool enabled) async {
    _isDspEngineEnabled = enabled;
    if (enabled) {
      await _enableDspEngine(equalizer, loudnessEnhancer);
    } else {
      await _disableDspEngine(equalizer, loudnessEnhancer);
    }
    _saveAudioSettings();
    notifyListeners();
  }

  Future<void> _enableDspEngine(AndroidEqualizer eq, AndroidLoudnessEnhancer le) async {
    try {
      if (Platform.isAndroid) {
        await le.setEnabled(true);
        await le.setTargetGain(0.4); // Premium punch

        await eq.setEnabled(true);
        final params = await eq.parameters;
        // Apply a "V-Shape" premium EQ curve
        if (params.bands.length >= 5) {
          await params.bands[0].setGain(params.maxDecibels * 0.5); // Bass
          await params.bands[1].setGain(params.maxDecibels * 0.2); // Mid-bass
          await params.bands[2].setGain(0);                        // Mids
          await params.bands[3].setGain(params.maxDecibels * 0.3); // Mid-highs
          await params.bands[4].setGain(params.maxDecibels * 0.6); // Treble
        }
      }
    } catch (e) {
      debugPrint("Error enabling DSP: $e");
    }
  }

  Future<void> _disableDspEngine(AndroidEqualizer eq, AndroidLoudnessEnhancer le) async {
    try {
      if (Platform.isAndroid) {
        await le.setEnabled(false);
        await le.setTargetGain(0.0);
        await eq.setEnabled(false);
      }
    } catch (e) {
      debugPrint("Error disabling DSP: $e");
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

  double _crossfadeDuration = 0.0;
  double get crossfadeDuration => _crossfadeDuration;

  void setCrossfadeDuration(double duration) {
    _crossfadeDuration = duration;
    _saveAudioSettings();
    notifyListeners();
  }

  Future<void> _saveAudioSettings() async {
    try {
      await StorageService.saveAudioSettings(
        dspEngine: _isDspEngineEnabled,
        uiHaptics: _uiHapticsEnabled,
        audioSyncHaptics: _audioSyncHapticsEnabled,
        speed: playbackSpeed,
        pitch: playbackPitch,
        autoplay: _isAutoplayEnabled,
        crossfade: _crossfadeDuration,
      );
    } catch (e) {
      debugPrint("Error saving Audio Settings: $e");
    }
  }

  bool isFavorite(String songId) {
    return _favoriteSongs.any((s) => s.id == songId);
  }

  void toggleFavorite(Song song) {
    triggerHaptic();
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

  bool _isAutoplayEnabled = true; // Auto queue songs by default
  bool get isAutoplayEnabled => _isAutoplayEnabled;

  void toggleAutoplay() {
    _isAutoplayEnabled = !_isAutoplayEnabled;
    _saveAudioSettings();
    notifyListeners();
  }

  void _listenToAudioState() {
    audioHandler.player.playerStateStream.listen((state) async {
      _isPlaying = state.playing;
      
      if (_isPlaying && _audioSyncHapticsEnabled) {
        _startAudioSyncHaptics();
      } else {
        _stopAudioSyncHaptics();
      }

      if (state.processingState == ProcessingState.completed) {
        if (_sleepAfterCurrentTrack) {
          _sleepAfterCurrentTrack = false;
          await audioHandler.pause();
        } else if (_isRepeat) {
          await seek(Duration.zero);
          await audioHandler.play();
        } else if (_queue.isNotEmpty && _isHost == false || (_isHost && _currentRoomId != null) || _currentRoomId == null) {
           // Wait, if guest, don't auto-skip. Let host control it.
           if (_currentRoomId != null && !_isHost) return;
           
          if (_currentIndex == _queue.length - 1 && _isAutoplayEnabled) {
            // Reached the end of the queue, fetch similar songs!
            final current = _queue[_currentIndex];
            final recommendations = await apiService.getRecommendedSongs(current);
            if (recommendations.isNotEmpty) {
              // Filter out songs already in the queue
              final newSongs = recommendations.where((s) => !_queue.any((q) => q.id == s.id)).toList();
              if (newSongs.isNotEmpty) {
                _queue.addAll(newSongs.take(10));
                _saveMemory();
                notifyListeners();
              }
            }
          }
          await skipToNext();
        }
      }
      
      // Sync to room if host
      if (_currentRoomId != null && _isHost && _currentSong != null) {
        _roomService.updateRoomState(_currentRoomId!, _currentSong!.id, _position, _isPlaying);
      }
      notifyListeners();
    });

    audioHandler.player.positionStream.listen((pos) {
      _position = pos;
      
      // Telemetry: Fire event if song has played for 30 seconds naturally
      if (!_hasSentTelemetryForCurrentSong && _currentSong != null && pos.inSeconds >= 30) {
        _hasSentTelemetryForCurrentSong = true;
        BackendApiService.sendTelemetryPlay(_currentSong!);
      }

      // Sync Host position every 5 seconds
      if (_currentRoomId != null && _isHost && _currentSong != null && _isPlaying && pos.inSeconds % 5 == 0 && _lastSyncedSecond != pos.inSeconds) {
        _lastSyncedSecond = pos.inSeconds;
        _roomService.updateRoomState(_currentRoomId!, _currentSong!.id, pos, _isPlaying);
      }

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
    _hasSentTelemetryForCurrentSong = false;
    _preloadQueueLyrics();

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

    if (downloadedSong != null && downloadedSong.encryptedMediaUrl != null) {
      String localPath = downloadedSong.encryptedMediaUrl!;
      if (!File(localPath).existsSync() && Platform.isIOS) {
        // iOS app sandbox GUID changes on rebuilds/updates. Resolve dynamically:
        final dir = await getApplicationDocumentsDirectory();
        final fileName = localPath.split('/').last;
        localPath = '${dir.path}/downloaded_music/$fileName';
      }
      
      if (File(localPath).existsSync()) {
        streamUrl = localPath;
        debugPrint('[AudioPlayerProvider] Playing downloaded file for ${song.title}');
      }
    }
    
    if (streamUrl == null) {
      streamUrl = await apiService.getStreamUrl(song);
    }
    
    _isLoading = false;

    if (streamUrl != null) {
      await audioHandler.playSong(song, streamUrl);
    } else {
      debugPrint('[AudioPlayerProvider] Failed to resolve stream for ${song.title}');
    }

    _updateHomeWidget();
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_currentSong == null) return;
    triggerHaptic(heavy: true);

    // If the app was relaunched and queue restored, the audio source might be empty.
    if (audioHandler.player.audioSource == null) {
      await playSong(_currentSong!, queue: _queue, index: _currentIndex);
      return;
    }

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
    triggerHaptic();

    if (_crossfadeDuration > 0 && _isPlaying) {
      await _fadeOut();
    }

    int nextIndex;
    if (_isShuffle && _queue.length > 1) {
      final rng = Random();
      nextIndex = rng.nextInt(_queue.length);
      while (nextIndex == _currentIndex) {
        nextIndex = rng.nextInt(_queue.length);
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
    triggerHaptic();
    
    if (_crossfadeDuration > 0 && _isPlaying) {
      await _fadeOut();
    }

    int prevIndex = _currentIndex - 1;
    if (prevIndex < 0) {
      prevIndex = _queue.length - 1;
    }
    await playSong(_queue[prevIndex], queue: _queue, index: prevIndex);
  }

  Future<void> _fadeOut() async {
    final fadeTime = _crossfadeDuration.toInt();
    final step = 1.0 / (fadeTime * 10);
    double vol = 1.0;
    for (int i = 0; i < fadeTime * 10; i++) {
      vol -= step;
      if (vol < 0) vol = 0;
      await audioHandler.player.setVolume(vol);
      await Future.delayed(const Duration(milliseconds: 100));
    }
    await audioHandler.player.setVolume(1.0); // Reset for next song
  }

  void addToQueue(Song song) {
    _queue.add(song);
    _saveMemory();
    notifyListeners();
  }

  void addSongsToQueue(List<Song> songs) {
    _queue.addAll(songs);
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
      final PaletteGenerator palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
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

  Future<void> _updateHomeWidget() async {
    try {
      await HomeWidget.saveWidgetData<String>('title', _currentSong?.title ?? 'No Song Playing');
      await HomeWidget.saveWidgetData<String>('artist', _currentSong?.artist ?? 'It Feels Music');
      await HomeWidget.updateWidget(name: 'MusicWidgetProvider');
    } catch (e) {
      debugPrint('Error updating home widget: $e');
    }
  }

  // --- Listen Together Room Controls ---
  Future<String?> startBroadcasting(String uid) async {
    if (_currentSong == null) return null;
    final roomId = await _roomService.createRoom(uid, _currentSong!, _position, _isPlaying);
    _currentRoomId = roomId;
    _isHost = true;
    notifyListeners();
    return roomId;
  }

  Future<void> joinSession(String roomId) async {
    _currentRoomId = roomId;
    _isHost = false;
    notifyListeners();
    
    _roomSubscription?.cancel();
    _roomSubscription = _roomService.listenToRoom(roomId).listen((event) async {
      if (event.snapshot.value == null) {
        leaveSession(); // Room closed
        return;
      }
      
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final songId = data['songId']?.toString();
      final isPlaying = data['isPlaying'] as bool? ?? false;
      final positionMs = data['positionMs'] as int? ?? 0;
      
      // If song changed
      if (songId != null && (_currentSong == null || _currentSong!.id != songId)) {
        // Find in local queue or fetch from network (mock fetching for now by checking queue)
        final inQueue = _queue.cast<Song?>().firstWhere((s) => s?.id == songId, orElse: () => null);
        if (inQueue != null) {
          await playSong(inQueue, queue: _queue);
        } else {
          // If we had apiService.getSongById we'd call it here
          // For now, construct a dummy to sync playback if not in queue
          final dummy = Song(
            id: songId, 
            saavnId: data['saavnId'] ?? songId,
            title: data['title'] ?? 'Host Track', 
            artist: data['artist'] ?? 'Unknown',
            album: data['coverArt'] ?? 'Unknown',
            coverArt: data['coverArt'] ?? '', 
            duration: 0, 
            addedAt: DateTime.now()
          );
          await playSong(dummy);
        }
      }
      
      // Sync Position if drift is > 2 seconds
      final diff = (_position.inMilliseconds - positionMs).abs();
      if (diff > 2000) {
        await seek(Duration(milliseconds: positionMs));
      }
      
      // Sync Playback State
      if (isPlaying != _isPlaying) {
        if (isPlaying) {
          await audioHandler.play();
        } else {
          await audioHandler.pause();
        }
      }
    });
  }

  void leaveSession() {
    if (_isHost && _currentRoomId != null) {
      _roomService.endRoom(_currentRoomId!);
    }
    _roomSubscription?.cancel();
    _currentRoomId = null;
    _isHost = false;
    notifyListeners();
  }

  void _preloadQueueLyrics() {
    if (_currentSong != null) {
      _lyricsService.preloadLyrics(_currentSong!);
    }
    if (_queue.isNotEmpty && _currentIndex >= 0) {
      if (_currentIndex + 1 < _queue.length) {
        _lyricsService.preloadLyrics(_queue[_currentIndex + 1]);
      }
      if (_currentIndex + 2 < _queue.length) {
        _lyricsService.preloadLyrics(_queue[_currentIndex + 2]);
      }
    }
  }
}
