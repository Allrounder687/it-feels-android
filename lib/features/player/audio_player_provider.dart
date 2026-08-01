import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:vibration/vibration.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/audio_player_handler.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/services/storage_service.dart';
import 'package:it_feels_music/features/social/room_service.dart';
import 'package:it_feels_music/features/social/social_service.dart';
import 'package:it_feels_music/services/backend_api_service.dart';
import 'package:it_feels_music/data/services/lyrics_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:it_feels_music/services/notification_service.dart';
import 'package:it_feels_music/features/cast/cast_service.dart' as it_feels_music_cast_service;
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

enum AppThemeMode {
  dynamic,
  midnight,
  burgundy,
  amoled,
  materialYou,
  light,
}

enum AudioVibe {
  normal,
  slowedReverb,
  nightcore,
}

@immutable
class AudioPlayerState {
  final Song? currentSong;
  final List<Song> queue;
  final int currentIndex;
  final bool isPlaying;
  final bool isLoading;
  final bool isShuffle;
  final bool isRepeat;
  final List<Song> favoriteSongs;
  final bool hasSentTelemetryForCurrentSong;
  final Duration position;
  final Duration duration;
  final Color extractedBackgroundColor;
  final Color extractedSurfaceColor;
  final Color extractedAccentColor;
  final Color? materialYouSurface;
  final Color? materialYouSurfaceContainer;
  final Color? materialYouPrimary;
  final AppThemeMode appThemeMode;

  // Sleep Timer
  final DateTime? sleepTimerEndTime;
  final bool isSleepTimerActive;
  final bool sleepAfterCurrentTrack;

  // Pro Features & Haptics
  final bool isDspEngineEnabled;
  final bool uiHapticsEnabled;
  final bool audioSyncHapticsEnabled;

  // Listen Together
  final String? currentRoomId;
  final bool isHost;

  // Autoplay & Crossfade
  final bool isAutoplayEnabled;
  final double crossfadeDuration;
  final double playbackSpeed;
  final double playbackPitch;
  final AudioVibe currentVibe;
  final bool hasScrobbledForCurrentSong;

  const AudioPlayerState({
    this.currentSong,
    this.queue = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.isLoading = false,
    this.isShuffle = false,
    this.isRepeat = false,
    this.favoriteSongs = const [],
    this.hasSentTelemetryForCurrentSong = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.extractedBackgroundColor = AppColors.midnightBackground,
    this.extractedSurfaceColor = AppColors.midnightSurface,
    this.extractedAccentColor = AppColors.midnightPrimary,
    this.materialYouSurface,
    this.materialYouSurfaceContainer,
    this.materialYouPrimary,
    this.appThemeMode = AppThemeMode.dynamic,
    this.sleepTimerEndTime,
    this.isSleepTimerActive = false,
    this.sleepAfterCurrentTrack = false,
    this.isDspEngineEnabled = false,
    this.uiHapticsEnabled = true,
    this.audioSyncHapticsEnabled = false,
    this.currentRoomId,
    this.isHost = false,
    this.isAutoplayEnabled = true,
    this.crossfadeDuration = 0.0,
    this.playbackSpeed = 1.0,
    this.playbackPitch = 1.0,
    this.currentVibe = AudioVibe.normal,
    this.hasScrobbledForCurrentSong = false,
  });

  bool get isInRoom => currentRoomId != null;
  Duration? get sleepTimerRemaining => sleepTimerEndTime?.difference(DateTime.now());

  bool isFavorite(String songId) {
    return favoriteSongs.any((s) => s.id == songId);
  }

  Color get themeBackgroundColor {
    switch (appThemeMode) {
      case AppThemeMode.dynamic:
        return extractedBackgroundColor;
      case AppThemeMode.materialYou:
        return materialYouSurface ?? AppColors.midnightBackground;
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
    switch (appThemeMode) {
      case AppThemeMode.dynamic:
        return extractedSurfaceColor;
      case AppThemeMode.materialYou:
        return materialYouSurfaceContainer ?? AppColors.midnightSurface;
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
    switch (appThemeMode) {
      case AppThemeMode.dynamic:
        return extractedAccentColor;
      case AppThemeMode.materialYou:
        return materialYouPrimary ?? AppColors.midnightPrimary;
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
    return appThemeMode == AppThemeMode.light ? Colors.black87 : Colors.white;
  }

  Color get themeMutedTextColor {
    return appThemeMode == AppThemeMode.light ? Colors.black54 : Colors.white54;
  }

  Color get themeInvertedTextColor {
    return appThemeMode == AppThemeMode.light ? Colors.white : Colors.black;
  }

  Color get themeCardColor {
    switch (appThemeMode) {
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

  Color get themePillColor {
    switch (appThemeMode) {
      case AppThemeMode.light:
        return const Color(0xFF2563EB);
      case AppThemeMode.burgundy:
        return AppColors.burgundyPill;
      default:
        return AppColors.midnightPill;
    }
  }

  Color get themeUnselectedPillColor {
    switch (appThemeMode) {
      case AppThemeMode.light:
        return const Color(0xFFE2E8F0);
      case AppThemeMode.burgundy:
        return AppColors.burgundyPill.withValues(alpha: 0.5);
      default:
        return AppColors.midnightPill.withValues(alpha: 0.5);
    }
  }

  Color get themeUnselectedPillTextColor {
    switch (appThemeMode) {
      case AppThemeMode.light:
        return const Color(0xFF334155);
      default:
        return Colors.white70;
    }
  }

  Color get themeNavPillColor {
    switch (appThemeMode) {
      case AppThemeMode.light:
        return const Color(0xFF2563EB);
      case AppThemeMode.burgundy:
        return AppColors.burgundyPrimary;
      default:
        return AppColors.midnightPrimary;
    }
  }

  Color get themeNavPillTextColor {
    switch (appThemeMode) {
      case AppThemeMode.light:
        return Colors.white;
      default:
        return Colors.black;
    }
  }

  AudioPlayerState copyWith({
    Song? currentSong,
    bool clearCurrentSong = false,
    List<Song>? queue,
    int? currentIndex,
    bool? isPlaying,
    bool? isLoading,
    bool? isShuffle,
    bool? isRepeat,
    List<Song>? favoriteSongs,
    bool? hasSentTelemetryForCurrentSong,
    Duration? position,
    Duration? duration,
    Color? themeBackgroundColor,
    Color? themeSurfaceColor,
    Color? themeAccentColor,
    Color? materialYouSurface,
    Color? materialYouSurfaceContainer,
    Color? materialYouPrimary,
    AppThemeMode? appThemeMode,
    DateTime? sleepTimerEndTime,
    bool clearSleepTimerEndTime = false,
    bool? isSleepTimerActive,
    bool? sleepAfterCurrentTrack,
    bool? isDspEngineEnabled,
    bool? uiHapticsEnabled,
    bool? audioSyncHapticsEnabled,
    String? currentRoomId,
    bool clearCurrentRoomId = false,
    bool? isHost,
    bool? isAutoplayEnabled,
    double? crossfadeDuration,
    double? playbackSpeed,
    double? playbackPitch,
    AudioVibe? currentVibe,
    bool? hasScrobbledForCurrentSong,
  }) {
    return AudioPlayerState(
      currentSong: clearCurrentSong ? null : (currentSong ?? this.currentSong),
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      isShuffle: isShuffle ?? this.isShuffle,
      isRepeat: isRepeat ?? this.isRepeat,
      favoriteSongs: favoriteSongs ?? this.favoriteSongs,
      hasSentTelemetryForCurrentSong: hasSentTelemetryForCurrentSong ?? this.hasSentTelemetryForCurrentSong,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      extractedBackgroundColor: themeBackgroundColor ?? this.extractedBackgroundColor,
      extractedSurfaceColor: themeSurfaceColor ?? this.extractedSurfaceColor,
      extractedAccentColor: themeAccentColor ?? this.extractedAccentColor,
      materialYouSurface: materialYouSurface ?? this.materialYouSurface,
      materialYouSurfaceContainer: materialYouSurfaceContainer ?? this.materialYouSurfaceContainer,
      materialYouPrimary: materialYouPrimary ?? this.materialYouPrimary,
      appThemeMode: appThemeMode ?? this.appThemeMode,
      sleepTimerEndTime: clearSleepTimerEndTime ? null : (sleepTimerEndTime ?? this.sleepTimerEndTime),
      isSleepTimerActive: isSleepTimerActive ?? this.isSleepTimerActive,
      sleepAfterCurrentTrack: sleepAfterCurrentTrack ?? this.sleepAfterCurrentTrack,
      isDspEngineEnabled: isDspEngineEnabled ?? this.isDspEngineEnabled,
      uiHapticsEnabled: uiHapticsEnabled ?? this.uiHapticsEnabled,
      audioSyncHapticsEnabled: audioSyncHapticsEnabled ?? this.audioSyncHapticsEnabled,
      currentRoomId: clearCurrentRoomId ? null : (currentRoomId ?? this.currentRoomId),
      isHost: isHost ?? this.isHost,
      isAutoplayEnabled: isAutoplayEnabled ?? this.isAutoplayEnabled,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      playbackPitch: playbackPitch ?? this.playbackPitch,
      currentVibe: currentVibe ?? this.currentVibe,
      hasScrobbledForCurrentSong: hasScrobbledForCurrentSong ?? this.hasScrobbledForCurrentSong,
    );
  }
}

class AudioPlayerNotifier extends Notifier<AudioPlayerState> {
  late AudioPlayerHandler audioHandler;
  late MusicApiService apiService;
  final LyricsService _lyricsService = LyricsService();
  final RoomService _roomService = locator<RoomService>();

  Timer? _sleepTimer;
  Timer? _audioSyncHapticTimer;
  StreamSubscription<DatabaseEvent>? _roomSubscription;
  StreamSubscription<DatabaseEvent>? _joinRequestSubscription;
  int _lastSyncedSecond = -1;
  bool _hasShownEmailVerification = false;

  AudioPlayerNotifier([AudioPlayerHandler? handler, MusicApiService? api]) {
    if (handler != null) audioHandler = handler;
    if (api != null) apiService = api;
  }

  @override
  AudioPlayerState build() {
    if (!tryInitServices()) {
      // Lazy init via ServiceLocator
      try {
        audioHandler = locator<AudioPlayerHandler>();
      } catch (_) {}
      try {
        apiService = locator<MusicApiService>();
      } catch (_) {}
    }

    _listenToEvents();
    _initMemory();

    ref.onDispose(() {
      _sleepTimer?.cancel();
      _audioSyncHapticTimer?.cancel();
      _roomSubscription?.cancel();
      _joinRequestSubscription?.cancel();
    });

    return const AudioPlayerState();
  }

  bool tryInitServices() {
    return (tryGetHandler() && tryGetApi());
  }

  bool tryGetHandler() {
    try {
      audioHandler;
      return true;
    } catch (_) {
      return false;
    }
  }

  bool tryGetApi() {
    try {
      apiService;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _initMemory() async {
    final audioSettings = await StorageService.loadAudioSettings();
    _applyAudioSettings(audioSettings);

    final pState = await StorageService.loadPlaybackState();
    if (pState != null) {
      final List<Song> savedQueue = pState['queue'];
      final int savedIndex = pState['currentIndex'];
      final int savedPosition = pState['positionSeconds'];

      if (savedQueue.isNotEmpty && savedIndex >= 0 && savedIndex < savedQueue.length) {
        final current = savedQueue[savedIndex];
        state = state.copyWith(
          queue: savedQueue,
          currentIndex: savedIndex,
          currentSong: current,
          position: Duration(seconds: savedPosition),
          duration: Duration(seconds: current.duration),
        );

        final mediaItems = savedQueue.map<MediaItem>((s) => MediaItem(
              id: s.id,
              title: s.title,
              artist: s.artist,
              artUri: Uri.tryParse(s.coverArt),
              duration: Duration(seconds: s.duration),
            )).toList();

        await audioHandler.updateQueue(mediaItems);
        await audioHandler.skipToQueueItem(savedIndex);
        if (savedPosition > 0) {
          await audioHandler.seek(Duration(seconds: savedPosition));
        }
      }
    }
  }

  Future<void> _applyAudioSettings(Map<String, dynamic> settings) async {
    try {
      final equalizer = audioHandler.equalizer;
      final loudnessEnhancer = audioHandler.loudnessEnhancer;
      
      final double speed = settings['speed'] ?? 1.0;
      final double pitch = settings['pitch'] ?? 1.0;
      await audioHandler.player.setSpeed(speed);
      await audioHandler.player.setPitch(pitch);

      final dsp = settings['dspEngine'] ?? false;
      final uiH = settings['uiHaptics'] ?? true;
      final audH = settings['audioSyncHaptics'] ?? false;
      final autoP = settings['autoplay'] ?? true;
      final crossF = settings['crossfade'] ?? 0.0;

      state = state.copyWith(
        isDspEngineEnabled: dsp,
        uiHapticsEnabled: uiH,
        audioSyncHapticsEnabled: audH,
        isAutoplayEnabled: autoP,
        crossfadeDuration: crossF,
      );

      if (dsp) {
        await _enableDspEngine(equalizer, loudnessEnhancer);
      } else {
        await _disableDspEngine(equalizer, loudnessEnhancer);
      }
    } catch (e) {
      debugPrint("Audio Enhancer initialization error: $e");
    }
  }

  void _saveMemory() {
    StorageService.savePlaybackState(
      state.queue, 
      state.currentIndex, 
      positionSeconds: state.position.inSeconds,
    );
    _syncQueueToFirebase();
  }

  void _syncQueueToFirebase() {
    locator<SocialService>().syncQueue(state.queue.take(50).toList());
  }

  void _listenToEvents() {
    audioHandler.onSkipNext = () => skipToNext();
    audioHandler.onSkipPrevious = () => skipToPrevious();
    audioHandler.onToggleFavorite = () async {
      if (state.currentSong != null) {
        toggleFavorite(state.currentSong!);
      }
    };
    _listenToAudioState();
    _loadFavorites();
  }

  void startSleepTimer(Duration duration) {
    cancelSleepTimer();
    final endTime = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      audioHandler.pause();
      cancelSleepTimer();
    });
    state = state.copyWith(
      sleepTimerEndTime: endTime,
      isSleepTimerActive: true,
      sleepAfterCurrentTrack: false,
    );
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    state = state.copyWith(
      clearSleepTimerEndTime: true,
      isSleepTimerActive: false,
      sleepAfterCurrentTrack: false,
    );
  }

  void setSleepAfterCurrentTrack() {
    cancelSleepTimer();
    state = state.copyWith(sleepAfterCurrentTrack: true);
  }

  void setAppThemeMode(AppThemeMode mode) {
    state = state.copyWith(appThemeMode: mode);
    _saveMemory();
  }

  void setMaterialYouColors(Color surface, Color surfaceContainer, Color primary) {
    state = state.copyWith(
      materialYouSurface: surface,
      materialYouSurfaceContainer: surfaceContainer,
      materialYouPrimary: primary,
    );
  }

  Future<void> triggerHaptic({bool heavy = false}) async {
    if (!state.uiHapticsEnabled) return;
    
    if (await Vibration.hasVibrator() ?? false) {
      if (heavy) {
        Vibration.vibrate(duration: 50, amplitude: 128);
      } else {
        Vibration.vibrate(duration: 20, amplitude: 64);
      }
    }
  }

  Future<void> setUiHaptics(bool enabled) async {
    state = state.copyWith(uiHapticsEnabled: enabled);
    _saveAudioSettings();
  }

  Future<void> setAudioSyncHaptics(bool enabled) async {
    state = state.copyWith(audioSyncHapticsEnabled: enabled);
    _saveAudioSettings();
    if (state.isPlaying && enabled) {
      _startAudioSyncHaptics();
    } else {
      _stopAudioSyncHaptics();
    }
  }

  void _startAudioSyncHaptics() {
    _audioSyncHapticTimer?.cancel();
    _audioSyncHapticTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) async {
      if (state.isPlaying && state.audioSyncHapticsEnabled && (await Vibration.hasVibrator() ?? false)) {
        Vibration.vibrate(duration: 15, amplitude: 40);
      } else {
        timer.cancel();
      }
    });
  }

  void _stopAudioSyncHaptics() {
    _audioSyncHapticTimer?.cancel();
  }

  AndroidEqualizer get equalizer => audioHandler.equalizer;
  AndroidLoudnessEnhancer get loudnessEnhancer => audioHandler.loudnessEnhancer;
  
  double get playbackSpeed => audioHandler.player.speed;
  double get playbackPitch => audioHandler.player.pitch;

  Future<void> setDspEngine(bool enabled) async {
    state = state.copyWith(isDspEngineEnabled: enabled);
    if (enabled) {
      await _enableDspEngine(equalizer, loudnessEnhancer);
    } else {
      await _disableDspEngine(equalizer, loudnessEnhancer);
    }
    _saveAudioSettings();
  }

  Future<void> _enableDspEngine(AndroidEqualizer eq, AndroidLoudnessEnhancer le) async {
    try {
      if (Platform.isAndroid) {
        await le.setEnabled(true);
        await le.setTargetGain(0.4);

        await eq.setEnabled(true);
        final params = await eq.parameters;
        if (params.bands.length >= 5) {
          await params.bands[0].setGain(params.maxDecibels * 0.5);
          await params.bands[1].setGain(params.maxDecibels * 0.2);
          await params.bands[2].setGain(0);
          await params.bands[3].setGain(params.maxDecibels * 0.3);
          await params.bands[4].setGain(params.maxDecibels * 0.6);
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
      state = state.copyWith(playbackSpeed: speed);
      _saveAudioSettings();
    } catch (e) {
      debugPrint("Error setting Speed: $e");
    }
  }

  Future<void> setPlaybackPitch(double pitch) async {
    try {
      await audioHandler.player.setPitch(pitch);
      state = state.copyWith(playbackPitch: pitch);
      _saveAudioSettings();
    } catch (e) {
      debugPrint("Error setting Pitch: $e");
    }
  }

  void setCrossfadeDuration(double duration) {
    state = state.copyWith(crossfadeDuration: duration);
    _saveAudioSettings();
  }

  Future<void> _saveAudioSettings() async {
    try {
      await StorageService.saveAudioSettings(
        dspEngine: state.isDspEngineEnabled,
        uiHaptics: state.uiHapticsEnabled,
        audioSyncHaptics: state.audioSyncHapticsEnabled,
        speed: playbackSpeed,
        pitch: playbackPitch,
        autoplay: state.isAutoplayEnabled,
        crossfade: state.crossfadeDuration,
      );
    } catch (e) {
      debugPrint("Error saving Audio Settings: $e");
    }
  }

  Future<void> setAudioVibe(AudioVibe vibe) async {
    state = state.copyWith(currentVibe: vibe);
    
    switch (vibe) {
      case AudioVibe.normal:
        await setPlaybackSpeed(1.0);
        await setPlaybackPitch(1.0);
        await setDspEngine(false);
        break;
      case AudioVibe.slowedReverb:
        await setPlaybackSpeed(0.85);
        await setPlaybackPitch(0.85);
        await setDspEngine(true);
        // Additional heavy bass EQ logic is handled inside setDspEngine
        break;
      case AudioVibe.nightcore:
        await setPlaybackSpeed(1.25);
        await setPlaybackPitch(1.3);
        await setDspEngine(false);
        break;
    }
    triggerHaptic(heavy: true);
  }

  void toggleFavorite(Song song) {
    triggerHaptic();
    final list = List<Song>.from(state.favoriteSongs);
    if (state.isFavorite(song.id)) {
      list.removeWhere((s) => s.id == song.id);
    } else {
      list.add(song);
    }
    state = state.copyWith(favoriteSongs: list);
    StorageService.saveFavorites(list);
  }

  Future<void> _loadFavorites() async {
    final favs = await StorageService.loadFavorites();
    state = state.copyWith(favoriteSongs: favs);
  }

  void toggleAutoplay() {
    state = state.copyWith(isAutoplayEnabled: !state.isAutoplayEnabled);
    _saveAudioSettings();
  }

  void _listenToAudioState() {
    audioHandler.player.playerStateStream.listen((pState) async {
      final isPlaying = pState.playing;
      state = state.copyWith(isPlaying: isPlaying);
      locator<SocialService>().updatePresence(state.currentSong, isPlaying, roomId: state.currentRoomId);

      if (isPlaying && state.audioSyncHapticsEnabled) {
        _startAudioSyncHaptics();
      } else {
        _stopAudioSyncHaptics();
      }

      if (pState.processingState == ProcessingState.completed) {
        if (state.sleepAfterCurrentTrack) {
          state = state.copyWith(sleepAfterCurrentTrack: false);
          await audioHandler.pause();
        } else if (state.isRepeat) {
          await seek(Duration.zero);
          await audioHandler.play();
        } else if (state.queue.isNotEmpty && state.isHost == false || (state.isHost && state.currentRoomId != null) || state.currentRoomId == null) {
          if (state.currentRoomId != null && !state.isHost) return;
           
          if (state.currentIndex == state.queue.length - 1 && state.isAutoplayEnabled) {
            final current = state.queue[state.currentIndex];
            final recommendations = await apiService.getRecommendedSongs(current);
            if (recommendations.isNotEmpty) {
              final newSongs = recommendations.where((s) => !state.queue.any((q) => q.id == s.id)).toList();
              if (newSongs.isNotEmpty) {
                final updatedQ = List<Song>.from(state.queue)..addAll(newSongs.take(10));
                state = state.copyWith(queue: updatedQ);
                _saveMemory();
              }
            }
          }
          await skipToNext();
        }
      }
      
      if (state.currentRoomId != null && state.isHost && state.currentSong != null) {
        _roomService.updateRoomState(state.currentRoomId!, state.currentSong!, state.position, state.isPlaying);
      }
    });

    audioHandler.player.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
      
      if (!state.hasSentTelemetryForCurrentSong && state.currentSong != null && pos.inSeconds >= 30) {
        state = state.copyWith(hasSentTelemetryForCurrentSong: true);
        BackendApiService.sendTelemetryPlay(state.currentSong!);
      }

      if (!state.hasScrobbledForCurrentSong && state.currentSong != null) {
        final durationInSeconds = state.duration.inSeconds;
        final halfway = durationInSeconds > 0 ? durationInSeconds / 2 : double.infinity;
        final fourMinutes = 240.0;
        if (pos.inSeconds >= halfway || pos.inSeconds >= fourMinutes) {
          state = state.copyWith(hasScrobbledForCurrentSong: true);
          try {
            locator<LastfmService>().scrobble(state.currentSong!, DateTime.now());
          } catch (_) {}
        }
      }

      if (state.currentRoomId != null && state.isHost && state.currentSong != null && state.isPlaying && pos.inSeconds % 5 == 0 && _lastSyncedSecond != pos.inSeconds) {
        _lastSyncedSecond = pos.inSeconds;
        _roomService.updateRoomState(state.currentRoomId!, state.currentSong!, pos, state.isPlaying);
      }
    });

    audioHandler.player.durationStream.listen((dur) {
      if (dur != null) {
        state = state.copyWith(duration: dur);
      }
    });
  }

  Future<void> playSong(Song song, {List<Song>? queue, int index = 0, BuildContext? context}) async {
    state = state.copyWith(
      currentSong: song,
      hasSentTelemetryForCurrentSong: false,
      hasScrobbledForCurrentSong: false,
    );
    
    try {
      locator<LastfmService>().updateNowPlaying(song);
    } catch (_) {}

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null && !user.emailVerified && !_hasShownEmailVerification) {
      _hasShownEmailVerification = true;
      rootScaffoldMessengerKey.currentState?.clearSnackBars();
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Please verify your email to unlock exclusive features.', style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.midnightPrimary,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'Send Link',
            textColor: Colors.white,
            onPressed: () {
               user.sendEmailVerification();
            },
          ),
        ),
      );
    }

    _preloadQueueLyricsAndMedia();

    List<Song> newQueue = List.from(state.queue);
    int newIndex = state.currentIndex;

    if (queue != null && queue.isNotEmpty) {
      newQueue = List.from(queue);
      final foundIndex = newQueue.indexWhere((s) => s.id == song.id || (s.title.toLowerCase() == song.title.toLowerCase() && s.artist.toLowerCase() == song.artist.toLowerCase()));
      if (foundIndex != -1) {
        newIndex = foundIndex;
      } else {
        newIndex = index >= 0 && index < newQueue.length ? index : 0;
      }
    } else {
      final existingIndex = newQueue.indexWhere((s) => s.id == song.id || (s.title.toLowerCase() == song.title.toLowerCase() && s.artist.toLowerCase() == song.artist.toLowerCase()));
      if (existingIndex != -1) {
        newIndex = existingIndex;
      } else {
        if (newQueue.isEmpty) {
          newQueue = [song];
          newIndex = 0;
        } else {
          final insertPos = newIndex >= 0 && newIndex < newQueue.length ? newIndex + 1 : newQueue.length;
          newQueue.insert(insertPos, song);
          newIndex = insertPos;
        }
      }
    }

    state = state.copyWith(
      queue: newQueue,
      currentIndex: newIndex,
      isLoading: true,
    );
    _saveMemory();

    _extractPalette(song.coverArt);

    String? streamUrl;
    final downloads = await StorageService.loadDownloads();
    final downloadedSong = downloads.cast<Song?>().firstWhere((s) => s?.id == song.id, orElse: () => null);

    if (downloadedSong != null && downloadedSong.encryptedMediaUrl != null) {
      String localPath = downloadedSong.encryptedMediaUrl!;
      if (!File(localPath).existsSync() && Platform.isIOS) {
        final dir = await getApplicationDocumentsDirectory();
        final fileName = localPath.split('/').last;
        localPath = '${dir.path}/downloaded_music/$fileName';
      }
      
      if (File(localPath).existsSync()) {
        streamUrl = localPath;
        debugPrint('[AudioPlayerNotifier] Playing downloaded file for ${song.title}');
      }
    }
    
    streamUrl ??= await apiService.getStreamUrl(song);
    
    state = state.copyWith(isLoading: false);

    if (streamUrl != null) {
      if (locator<it_feels_music_cast_service.CastService>().isConnected) {
        await audioHandler.pause(); // Ensure local is paused
        await locator<it_feels_music_cast_service.CastService>().loadMedia(song, streamUrl, Duration.zero, true);
      } else {
        await audioHandler.playSong(song, streamUrl);
      }
      locator<SocialService>().updatePresence(song, true, roomId: state.currentRoomId);
    } else {
      debugPrint('[AudioPlayerNotifier] Failed to resolve stream for ${song.title}');
    }

    _updateHomeWidget();
  }

  Future<void> play() async {
    if (locator<it_feels_music_cast_service.CastService>().isConnected) {
      await locator<it_feels_music_cast_service.CastService>().play();
    } else {
      await audioHandler.play();
    }
    locator<SocialService>().updatePresence(state.currentSong, true, roomId: state.currentRoomId);
  }

  Future<void> pause() async {
    if (locator<it_feels_music_cast_service.CastService>().isConnected) {
      await locator<it_feels_music_cast_service.CastService>().pause();
    } else {
      await audioHandler.pause();
    }
    locator<SocialService>().updatePresence(state.currentSong, false, roomId: state.currentRoomId);
  }

  Future<void> togglePlayPause() async {
    if (state.currentSong == null) return;
    triggerHaptic(heavy: true);

    if (audioHandler.player.audioSource == null) {
      await playSong(state.currentSong!, queue: state.queue, index: state.currentIndex);
      return;
    }

    if (state.isPlaying) {
      if (locator<it_feels_music_cast_service.CastService>().isConnected) {
        await locator<it_feels_music_cast_service.CastService>().pause();
      } else {
        await audioHandler.pause();
      }
      locator<SocialService>().updatePresence(state.currentSong, false, roomId: state.currentRoomId);
    } else {
      if (locator<it_feels_music_cast_service.CastService>().isConnected) {
        await locator<it_feels_music_cast_service.CastService>().play();
      } else {
        await audioHandler.play();
      }
      locator<SocialService>().updatePresence(state.currentSong, true, roomId: state.currentRoomId);
    }
    _saveMemory();
  }

  Future<void> seek(Duration pos) async {
    if (locator<it_feels_music_cast_service.CastService>().isConnected) {
      await locator<it_feels_music_cast_service.CastService>().seek(pos);
    } else {
      await audioHandler.seek(pos);
    }
  }

  Future<void> skipToNext([BuildContext? context]) async {
    if (state.queue.isEmpty) return;
    triggerHaptic();

    if (state.crossfadeDuration > 0 && state.isPlaying) {
      await _fadeOut();
    }

    int nextIndex;
    if (state.isShuffle && state.queue.length > 1) {
      final rng = Random();
      nextIndex = rng.nextInt(state.queue.length);
      while (nextIndex == state.currentIndex) {
        nextIndex = rng.nextInt(state.queue.length);
      }
    } else {
      nextIndex = state.currentIndex + 1;
      if (nextIndex >= state.queue.length) {
        nextIndex = 0;
      }
    }
    await playSong(state.queue[nextIndex], queue: state.queue, index: nextIndex);
  }

  Future<void> skipToPrevious([BuildContext? context]) async {
    if (state.queue.isEmpty) return;
    triggerHaptic();
    
    if (state.crossfadeDuration > 0 && state.isPlaying) {
      await _fadeOut();
    }

    int prevIndex = state.currentIndex - 1;
    if (prevIndex < 0) {
      prevIndex = state.queue.length - 1;
    }
    await playSong(state.queue[prevIndex], queue: state.queue, index: prevIndex);
  }

  Future<void> _fadeOut() async {
    final fadeTime = state.crossfadeDuration.toInt();
    final step = 1.0 / (fadeTime * 10);
    double vol = 1.0;
    for (int i = 0; i < fadeTime * 10; i++) {
      vol -= step;
      if (vol < 0) vol = 0;
      await audioHandler.player.setVolume(vol);
      await Future.delayed(const Duration(milliseconds: 100));
    }
    await audioHandler.player.setVolume(1.0);
  }

  void addToQueue(Song song) {
    final updated = List<Song>.from(state.queue)..add(song);
    state = state.copyWith(queue: updated);
    _saveMemory();
  }

  void addSongsToQueue(List<Song> songs) {
    final updated = List<Song>.from(state.queue)..addAll(songs);
    state = state.copyWith(queue: updated);
    _saveMemory();
  }

  void playNext(Song song) {
    final updated = List<Song>.from(state.queue);
    if (state.currentIndex >= 0 && state.currentIndex < updated.length) {
      updated.insert(state.currentIndex + 1, song);
    } else {
      updated.add(song);
    }
    state = state.copyWith(queue: updated);
    _saveMemory();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex < 0 || oldIndex >= state.queue.length || newIndex < 0 || newIndex > state.queue.length) return;

    final updated = List<Song>.from(state.queue);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    
    int curIndex = state.currentIndex;
    if (curIndex == oldIndex) {
      curIndex = newIndex;
    } else if (oldIndex < curIndex && newIndex >= curIndex) {
      curIndex--;
    } else if (oldIndex > curIndex && newIndex <= curIndex) {
      curIndex++;
    }

    state = state.copyWith(queue: updated, currentIndex: curIndex);
    _saveMemory();
  }

  Future<void> seekForward({int seconds = 10}) async {
    final target = state.position + Duration(seconds: seconds);
    final clamped = target > state.duration ? state.duration : target;
    await seek(clamped);
  }

  Future<void> seekBackward({int seconds = 10}) async {
    final target = state.position - Duration(seconds: seconds);
    final clamped = target < Duration.zero ? Duration.zero : target;
    await seek(clamped);
  }

  void toggleShuffle() {
    state = state.copyWith(isShuffle: !state.isShuffle);
  }

  void toggleRepeat() {
    state = state.copyWith(isRepeat: !state.isRepeat);
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

      final bg = HSLColor.fromColor(dominant).withLightness(0.12).toColor();
      final surf = HSLColor.fromColor(darkMuted).withLightness(0.18).toColor();
      final acc = lightVibrant;

      state = state.copyWith(
        themeBackgroundColor: bg,
        themeSurfaceColor: surf,
        themeAccentColor: acc,
      );
    } catch (e) {
      debugPrint('[AudioPlayerNotifier] Palette extraction error: $e');
    }
  }

  Future<void> _updateHomeWidget() async {
    try {
      await HomeWidget.saveWidgetData<String>('title', state.currentSong?.title ?? 'No Song Playing');
      await HomeWidget.saveWidgetData<String>('artist', state.currentSong?.artist ?? 'It Feels Music');
      await HomeWidget.updateWidget(name: 'MusicWidgetProvider');
    } catch (e) {
      debugPrint('Error updating home widget: $e');
    }
  }

  Future<String?> startBroadcasting(String uid) async {
    if (state.currentSong == null) return null;
    final isPremium = ref.read(subscriptionProvider).isPremium;
    final roomId = await _roomService.createRoom(uid, state.currentSong!, state.position, state.isPlaying, isPublic: isPremium);
    state = state.copyWith(currentRoomId: roomId, isHost: true);
    locator<SocialService>().updatePresence(state.currentSong, state.isPlaying, roomId: roomId);
    
    // Zero-cognitive load friending: Notify all friends
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final friends = List<String>.from(data['friends'] ?? []);
        final myName = data['name'] ?? 'Your friend';
        if (friends.isNotEmpty) {
          final NotificationService notifService = locator<NotificationService>();
          await notifService.notifyFriendsOfRoom(friends, myName, roomId);
        }
      }
    } catch (e) {
      debugPrint("Error fetching friends to notify: $e");
    }
    
    // Listen for join requests
    _joinRequestSubscription?.cancel();
    _joinRequestSubscription = _roomService.listenToJoinRequests(roomId).listen((event) {
      if (event.snapshot.value != null) {
        final guestId = event.snapshot.key!;
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final guestName = data['name'] ?? 'Someone';
        
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('$guestName wants to join your room!', style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.midnightPrimary,
            duration: const Duration(seconds: 10),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: 'Accept',
              textColor: Colors.white,
              onPressed: () {
                _roomService.acceptJoinRequest(roomId, guestId);
              },
            ),
          ),
        );
      }
    });

    return roomId;
  }

  Future<void> joinSession(String roomId) async {
    state = state.copyWith(currentRoomId: roomId, isHost: false);
    
    _roomSubscription?.cancel();
    _roomSubscription = _roomService.listenToRoom(roomId).listen((event) async {
      if (event.snapshot.value == null) {
        leaveSession();
        return;
      }
      
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final hostId = data['hostId']?.toString();
      if (hostId != null) {
        _roomService.autoFriend(hostId);
      }
      
      final songId = data['songId']?.toString();
      final isPlaying = data['isPlaying'] as bool? ?? false;
      final positionMs = data['positionMs'] as int? ?? 0;
      
      if (songId != null && (state.currentSong == null || state.currentSong!.id != songId)) {
        final inQueue = state.queue.cast<Song?>().firstWhere((s) => s?.id == songId, orElse: () => null);
        if (inQueue != null) {
          await playSong(inQueue, queue: state.queue);
        } else {
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
      
      final diff = (state.position.inMilliseconds - positionMs).abs();
      if (diff > 2000) {
        await seek(Duration(milliseconds: positionMs));
      }
      
      if (isPlaying != state.isPlaying) {
        if (isPlaying) {
          await audioHandler.play();
        } else {
          await audioHandler.pause();
        }
      }
    });
  }

  void leaveSession() {
    if (state.isHost && state.currentRoomId != null) {
      _roomService.endRoom(state.currentRoomId!);
    }
    _roomSubscription?.cancel();
    _joinRequestSubscription?.cancel();
    state = state.copyWith(clearCurrentRoomId: true, isHost: false);
  }

  void _preloadQueueLyricsAndMedia() {
    if (state.currentSong != null) {
      _lyricsService.preloadLyrics(state.currentSong!);
      BackendApiService.preloadVideoStreams(state.currentSong!);
    }
    if (state.queue.isNotEmpty && state.currentIndex >= 0) {
      for (int offset = 1; offset <= 3; offset++) {
        final idx = state.currentIndex + offset;
        if (idx < state.queue.length) {
          final nextSong = state.queue[idx];
          _lyricsService.preloadLyrics(nextSong);
          apiService.preloadStreamUrl(nextSong);
          if (offset <= 2) {
            BackendApiService.preloadVideoStreams(nextSong);
          }
        }
      }
    }
  }
}

typedef AudioPlayerProvider = AudioPlayerNotifier;
