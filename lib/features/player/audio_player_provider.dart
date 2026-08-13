import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:it_feels_music/features/player/active_media_provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:vibration/vibration.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/audio_player_handler.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/services/database_service.dart';
import 'package:it_feels_music/services/storage_service.dart';
import 'package:it_feels_music/services/backend_api_service.dart';
import 'package:it_feels_music/data/services/lyrics_service.dart';
import 'package:it_feels_music/data/services/smart_cache_service.dart';
import 'package:it_feels_music/core/utils/des_decryptor.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/features/cast/cast_service.dart'
    as it_feels_music_cast_service;
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/player/palette_extractor_service.dart';
import 'package:it_feels_music/data/services/audio_engine_service.dart';
import 'package:it_feels_music/features/social/listen_together_service.dart';

enum AppThemeMode { dynamic, midnight, burgundy, amoled, materialYou, light, glass }

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
  Duration get position => locator<AudioEngineService>().position;
  final Duration duration;
  final String? currentStreamUrl;
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
    this.duration = Duration.zero,
    this.currentStreamUrl,
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
  });

  bool get isInRoom => currentRoomId != null;
  Duration? get sleepTimerRemaining =>
      sleepTimerEndTime?.difference(DateTime.now());

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
      case AppThemeMode.glass: return Colors.transparent;
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
      case AppThemeMode.glass: return const Color(0x0DFFFFFF);
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
      case AppThemeMode.glass: return AppColors.midnightAccent;
    }
  }

  Color get themeTextColor {
    return appThemeMode == AppThemeMode.light ? Colors.black87 : Colors.white;
  }

  Color get themeMutedTextColor {
    return appThemeMode == AppThemeMode.light ? Colors.black54 : (appThemeMode == AppThemeMode.glass ? const Color(0xB3FFFFFF) : Colors.white54);
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
      case AppThemeMode.glass: return const Color(0x0DFFFFFF);
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
      case AppThemeMode.glass: return const Color(0x1AFFFFFF);
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
      case AppThemeMode.glass: return const Color(0x0DFFFFFF);
      default:
        return AppColors.midnightPill.withValues(alpha: 0.5);
    }
  }

  Color get themeUnselectedPillTextColor {
    switch (appThemeMode) {
      case AppThemeMode.light:
        return const Color(0xFF334155);
      case AppThemeMode.glass: return const Color(0xB3FFFFFF);
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
      case AppThemeMode.glass: return const Color(0x33FFFFFF);
      default:
        return AppColors.midnightPrimary;
    }
  }

  Color get themeNavPillTextColor {
    switch (appThemeMode) {
      case AppThemeMode.light:
        return Colors.white;
      case AppThemeMode.glass: return Colors.white;
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
    Duration? duration,
    String? currentStreamUrl,
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
      hasSentTelemetryForCurrentSong:
          hasSentTelemetryForCurrentSong ?? this.hasSentTelemetryForCurrentSong,
      duration: duration ?? this.duration,
      currentStreamUrl: currentStreamUrl ?? this.currentStreamUrl,
      extractedBackgroundColor:
          themeBackgroundColor ?? extractedBackgroundColor,
      extractedSurfaceColor: themeSurfaceColor ?? extractedSurfaceColor,
      extractedAccentColor: themeAccentColor ?? extractedAccentColor,
      materialYouSurface: materialYouSurface ?? this.materialYouSurface,
      materialYouSurfaceContainer:
          materialYouSurfaceContainer ?? this.materialYouSurfaceContainer,
      materialYouPrimary: materialYouPrimary ?? this.materialYouPrimary,
      appThemeMode: appThemeMode ?? this.appThemeMode,
      sleepTimerEndTime: clearSleepTimerEndTime
          ? null
          : (sleepTimerEndTime ?? this.sleepTimerEndTime),
      isSleepTimerActive: isSleepTimerActive ?? this.isSleepTimerActive,
      sleepAfterCurrentTrack:
          sleepAfterCurrentTrack ?? this.sleepAfterCurrentTrack,
      isDspEngineEnabled: isDspEngineEnabled ?? this.isDspEngineEnabled,
      uiHapticsEnabled: uiHapticsEnabled ?? this.uiHapticsEnabled,
      audioSyncHapticsEnabled:
          audioSyncHapticsEnabled ?? this.audioSyncHapticsEnabled,
      currentRoomId: clearCurrentRoomId
          ? null
          : (currentRoomId ?? this.currentRoomId),
      isHost: isHost ?? this.isHost,
      isAutoplayEnabled: isAutoplayEnabled ?? this.isAutoplayEnabled,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      playbackPitch: playbackPitch ?? this.playbackPitch,
      currentVibe: currentVibe ?? this.currentVibe,
    );
  }
}

class AudioPlayerNotifier extends Notifier<AudioPlayerState> {
  AudioEngineService get engine => locator<AudioEngineService>();
  ListenTogetherService get socialSync => locator<ListenTogetherService>();
  MusicApiService get apiService => locator<MusicApiService>();

  final LyricsService _lyricsService = locator<LyricsService>();

  AudioPlayerHandler get audioHandler => engine.audioHandler;

  final List<StreamSubscription> _eventSubscriptions = [];
  bool _hasListenedToEvents = false;
  bool _isFading = false;
  Timer? _audioSyncHapticTimer;
  bool _hasShownEmailVerification = false;
  int _playSongGenerationToken = 0;
  Timer? _bufferingTimer;

  @override
  AudioPlayerState build() {
    // Sync theme with SettingsProvider for initial state
    final currentTheme = ref.read(settingsProvider).theme;
    final initialState = AudioPlayerState(
      appThemeMode: _mapThemeString(currentTheme),
    );

    // Defer side-effects until after build completes to prevent 'uninitialized provider' exceptions
    Future.microtask(() {
      _listenToEvents();
      _initMemory();
    });

    ref.listen(settingsProvider.select((s) => s.theme), (previous, next) {
      setAppThemeMode(_mapThemeString(next));
    });

    ref.onDispose(() {
      for (final sub in _eventSubscriptions) { sub.cancel(); }
      _eventSubscriptions.clear();
      _bufferingTimer?.cancel();
      _audioSyncHapticTimer?.cancel();
    });

    return initialState;
  }

  AppThemeMode _mapThemeString(String themeStr) {
    switch (themeStr) {
      case 'Dynamic (Album Art)':
        return AppThemeMode.dynamic;
      case 'Midnight Blue':
        return AppThemeMode.midnight;
      case 'Deep Burgundy':
        return AppThemeMode.burgundy;
      case 'Pitch Black (AMOLED)':
        return AppThemeMode.amoled;
      case 'Light Theme':
        return AppThemeMode.light;
      case 'Glass (Desktop)':
        return AppThemeMode.glass;
      default:
        return AppThemeMode.materialYou;
    }
  }

  Future<void> _initMemory() async {
    // Let the engine initialize its hardware DSP & speed settings
    await engine.init(locator<AudioPlayerHandler>());

    // Wire up Lock Screen & Control Center skip buttons
    audioHandler.onSkipNext = () => skipToNext();
    audioHandler.onSkipPrevious = () => skipToPrevious();

    // Sync the Notifier's state with the Engine's initial state
    state = state.copyWith(
      isDspEngineEnabled: engine.isDspEngineEnabled,
      uiHapticsEnabled: engine.uiHapticsEnabled,
      audioSyncHapticsEnabled: engine.audioSyncHapticsEnabled,
      isAutoplayEnabled: engine.isAutoplayEnabled,
      crossfadeDuration: engine.crossfadeDuration,
      playbackSpeed: engine.playbackSpeed,
      playbackPitch: engine.playbackPitch,
      currentVibe: engine.currentVibe,
    );

    final pState = await StorageService.loadPlaybackState();
    if (pState != null) {
      final List<Song> savedQueue = pState['queue'];
      final int savedIndex = pState['currentIndex'];
      final int savedPosition = pState['positionSeconds'];

      if (savedQueue.isNotEmpty &&
          savedIndex >= 0 &&
          savedIndex < savedQueue.length) {
        final current = savedQueue[savedIndex];
        state = state.copyWith(
          queue: savedQueue,
          currentIndex: savedIndex,
          currentSong: current,
          duration: Duration(seconds: current.duration),
        );

        final mediaItems = savedQueue
            .map<MediaItem>(
              (s) => MediaItem(
                id: s.id,
                title: s.title,
                artist: s.artist,
                artUri: Uri.tryParse(s.coverArt),
                duration: Duration(seconds: s.duration),
              ),
            )
            .toList();

        await audioHandler.updateQueue(mediaItems);
        await audioHandler.skipToQueueItem(savedIndex);
        if (savedPosition > 0) {
          await engine.seek(Duration(seconds: savedPosition));
        }
      }
    }

    // Trigger smart auto-cache for top played songs
    locator<SmartCacheService>().syncTopSongs();
  }

  void _saveMemory() {
    StorageService.savePlaybackState(
      state.queue,
      state.currentIndex,
      positionSeconds: state.position.inSeconds,
    );
  }

  void _listenToEvents() {
    if (_hasListenedToEvents) return;
    _hasListenedToEvents = true;

    // We bind to the Engine's streams which are wrappers over audioHandler
    _eventSubscriptions.add(engine.playerStateStream.listen((pState) async {
      final isPlaying = pState.playing;
      state = state.copyWith(isPlaying: isPlaying);
      socialSync.updatePresence(state.currentSong, isPlaying);

      if (isPlaying && state.audioSyncHapticsEnabled) {
        _startAudioSyncHaptics();
      } else {
        _stopAudioSyncHaptics();
      }

      if (pState.processingState == ProcessingState.buffering) {
        if (_bufferingTimer == null || !_bufferingTimer!.isActive) {
          _bufferingTimer = Timer(const Duration(milliseconds: 1500), () async {
            if (state.currentSong != null) {
              final originalUrl = await apiService.getStreamUrl(
                state.currentSong!,
              );
              if (originalUrl != null && !originalUrl.contains('_96.mp4')) {
                final downgradedUrl = DesDecryptor.get96kbpsUrl(originalUrl);
                if (downgradedUrl != null && downgradedUrl != originalUrl) {
                  debugPrint(
                    '[AdaptiveNetwork] Excessive buffering detected. Downgrading to 96kbps...',
                  );
                  final pos = engine.position;
                  await engine.playSong(state.currentSong!, downgradedUrl);
                  await engine.seek(pos);
                  await engine.play();
                }
              }
            }
          });
        }
      } else {
        _bufferingTimer?.cancel();
        _bufferingTimer = null;
      }

      if (pState.processingState == ProcessingState.completed) {
        _handleTrackCompleted();
      }

      if (state.currentRoomId != null &&
          state.isHost &&
          state.currentSong != null) {
        socialSync.updateRoomState(
          state.currentSong!,
          state.position,
          state.isPlaying,
        );
      }
    }));

    _eventSubscriptions.add(engine.positionStream.listen((pos) {
      if (!state.hasSentTelemetryForCurrentSong &&
          state.currentSong != null &&
          pos.inSeconds >= 30) {
        state = state.copyWith(hasSentTelemetryForCurrentSong: true);
        BackendApiService.sendTelemetryPlay(state.currentSong!);
      }

      // Windows threading bug fallback: Manually trigger completion if we reach the end of the track
      // since the native events channel drops the completed event on non-platform threads.
      if (Platform.isWindows &&
          state.isPlaying &&
          state.duration != null &&
          !state.isLoading) {
        if (state.duration!.inMilliseconds > 0 && pos.inMilliseconds > 0) {
          if (state.duration!.inMilliseconds - pos.inMilliseconds <= 250) {
            _handleTrackCompleted();
          }
        }
      }
    }));

    _eventSubscriptions.add(engine.durationStream.listen((dur) {
      if (dur != null) {
        state = state.copyWith(duration: dur);
      }
    }));

    // Bind sleep timer streams from engine
    _eventSubscriptions.add(engine.sleepTimerStream.listen((endTime) {
      state = state.copyWith(
        sleepTimerEndTime: endTime,
        clearSleepTimerEndTime: endTime == null,
        isSleepTimerActive: endTime != null,
      );
    }));

    _eventSubscriptions.add(engine.sleepAfterTrackStream.listen((val) {
      state = state.copyWith(sleepAfterCurrentTrack: val);
    }));

    _loadFavorites();
  }

  bool _isHandlingCompletion = false;

  Future<void> _handleTrackCompleted() async {
    if (_isHandlingCompletion) return;
    _isHandlingCompletion = true;

    try {
      if (state.sleepAfterCurrentTrack) {
        state = state.copyWith(sleepAfterCurrentTrack: false);
        await engine.pause();
      } else if (state.isRepeat) {
        await engine.seek(Duration.zero);
        await engine.play();
      } else if (state.queue.isNotEmpty && state.isHost == false ||
          (state.isHost && state.currentRoomId != null) ||
          state.currentRoomId == null) {
        if (state.currentRoomId != null && !state.isHost) return;

        if (state.currentIndex == state.queue.length - 1 &&
            state.isAutoplayEnabled) {
          final current = state.queue[state.currentIndex];
          final recommendations = await locator<MusicApiService>()
              .getRecommendedSongs(current);
          if (recommendations.isNotEmpty) {
            final newSongs = recommendations
                .where((s) => !state.queue.any((q) => q.id == s.id))
                .toList();
            if (newSongs.isNotEmpty) {
              final updatedQ = List<Song>.from(state.queue)
                ..addAll(newSongs.take(10));
              state = state.copyWith(queue: updatedQ);
              _saveMemory();
            }
          }
        }
        await skipToNext();
      }
    } finally {
      // Allow a small buffer before re-enabling completion tracking
      await Future.delayed(const Duration(milliseconds: 1000));
      _isHandlingCompletion = false;
    }
  }

  void startSleepTimer(Duration duration) => engine.startSleepTimer(duration);
  void cancelSleepTimer() => engine.cancelSleepTimer();
  void setSleepAfterCurrentTrack() => engine.setSleepAfterCurrentTrack();

  void setAppThemeMode(AppThemeMode mode) {
    state = state.copyWith(appThemeMode: mode);
    _saveMemory();
  }

  void setMaterialYouColors(
    Color surface,
    Color surfaceContainer,
    Color primary,
  ) {
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
    engine.uiHapticsEnabled = enabled;
    await engine.saveAudioSettings();
  }

  Future<void> setAudioSyncHaptics(bool enabled) async {
    state = state.copyWith(audioSyncHapticsEnabled: enabled);
    engine.audioSyncHapticsEnabled = enabled;
    await engine.saveAudioSettings();
    if (state.isPlaying && enabled) {
      _startAudioSyncHaptics();
    } else {
      _stopAudioSyncHaptics();
    }
  }

  void _startAudioSyncHaptics() {
    _audioSyncHapticTimer?.cancel();
    _audioSyncHapticTimer = Timer.periodic(const Duration(milliseconds: 600), (
      timer,
    ) async {
      if (state.isPlaying &&
          state.audioSyncHapticsEnabled &&
          (await Vibration.hasVibrator() ?? false)) {
        Vibration.vibrate(duration: 15, amplitude: 40);
      } else {
        timer.cancel();
      }
    });
  }

  void _stopAudioSyncHaptics() {
    _audioSyncHapticTimer?.cancel();
  }

  Future<void> setDspEngine(bool enabled) async {
    state = state.copyWith(isDspEngineEnabled: enabled);
    await engine.setDspEngine(enabled);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    state = state.copyWith(playbackSpeed: speed);
    await engine.setPlaybackSpeed(speed);
  }

  Future<void> setPlaybackPitch(double pitch) async {
    state = state.copyWith(playbackPitch: pitch);
    await engine.setPlaybackPitch(pitch);
  }

  void setCrossfadeDuration(double duration) {
    state = state.copyWith(crossfadeDuration: duration);
    engine.setCrossfadeDuration(duration);
  }

  Future<void> setAudioVibe(AudioVibe vibe) async {
    state = state.copyWith(currentVibe: vibe);
    await engine.setAudioVibe(vibe);
    triggerHaptic(heavy: true);

    // Sync UI state back from engine since the vibe changes speed/pitch/dsp internally
    state = state.copyWith(
      playbackSpeed: engine.playbackSpeed,
      playbackPitch: engine.playbackPitch,
      isDspEngineEnabled: engine.isDspEngineEnabled,
    );
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
    engine.isAutoplayEnabled = state.isAutoplayEnabled;
    engine.saveAudioSettings();
  }

  Future<void> playSong(
    Song song, {
    List<Song>? queue,
    int index = 0,
    BuildContext? context,
    String? predefinedStreamUrl,
  }) async {
    final currentToken = ++_playSongGenerationToken;

    state = state.copyWith(
      currentSong: song,
      hasSentTelemetryForCurrentSong: false,
    );

    ref
        .read(activeMediaProvider.notifier)
        .setActiveMedia(ActiveMediaType.audio);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null && !_hasShownEmailVerification) {
      user.reload().then((_) {
        final reloadedUser = FirebaseAuth.instance.currentUser;
        if (reloadedUser != null && !reloadedUser.emailVerified) {
          _hasShownEmailVerification = true;
          rootScaffoldMessengerKey.currentState?.clearSnackBars();
          rootScaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: const Text(
                'Please verify your email to unlock exclusive features.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: AppColors.midnightPrimary,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              action: SnackBarAction(
                label: 'Send Link',
                textColor: Colors.white,
                onPressed: () {
                  reloadedUser.sendEmailVerification();
                },
              ),
            ),
          );
        }
      });
    }

    _preloadQueueLyricsAndMedia();

    List<Song> newQueue = List.from(state.queue);
    int newIndex = state.currentIndex;

    if (queue != null && queue.isNotEmpty) {
      newQueue = List.from(queue);
      if (index >= 0 &&
          index < newQueue.length &&
          newQueue[index].id == song.id) {
        newIndex = index;
      } else {
        final foundIndex = newQueue.indexWhere(
          (s) =>
              s.id == song.id ||
              (s.title.toLowerCase() == song.title.toLowerCase() &&
                  s.artist.toLowerCase() == song.artist.toLowerCase()),
        );
        if (foundIndex != -1) {
          newIndex = foundIndex;
        } else {
          newIndex = index >= 0 && index < newQueue.length ? index : 0;
        }
      }
    } else {
      if (index >= 0 &&
          index < newQueue.length &&
          newQueue[index].id == song.id) {
        newIndex = index;
      } else {
        final existingIndex = newQueue.indexWhere(
          (s) =>
              s.id == song.id ||
              (s.title.toLowerCase() == song.title.toLowerCase() &&
                  s.artist.toLowerCase() == song.artist.toLowerCase()),
        );
        if (existingIndex != -1) {
          newIndex = existingIndex;
        } else {
          if (newQueue.isEmpty) {
            newQueue = [song];
            newIndex = 0;
          } else {
            final insertPos = newIndex >= 0 && newIndex < newQueue.length
                ? newIndex + 1
                : newQueue.length;
            newQueue.insert(insertPos, song);
            newIndex = insertPos;
          }
        }
      }
    }

    state = state.copyWith(
      queue: newQueue,
      currentIndex: newIndex,
      isLoading: true,
    );
    _saveMemory();

    locator<PaletteExtractorService>().extract(song.coverArt).then((res) {
      if (res != null) {
        state = state.copyWith(
          themeBackgroundColor: res.backgroundColor,
          themeSurfaceColor: res.surfaceColor,
          themeAccentColor: res.accentColor,
          appThemeMode: _mapThemeString(ref.read(settingsProvider).theme),
        );
      } else {
        // Fallback for low-ram devices handling
        state = state.copyWith(appThemeMode: AppThemeMode.midnight);
      }
    });

    String? streamUrl;
    final downloads = await StorageService.loadDownloads();
    final downloadedSong = downloads.cast<Song?>().firstWhere(
      (s) => s?.id == song.id,
      orElse: () => null,
    );

    if (downloadedSong != null && downloadedSong.encryptedMediaUrl != null) {
      String localPath = downloadedSong.encryptedMediaUrl!;
      if (!File(localPath).existsSync() && Platform.isIOS) {
        final dir = await getApplicationDocumentsDirectory();
        final fileName = localPath.split('/').last;
        localPath = '${dir.path}/downloaded_music/$fileName';
      }

      if (File(localPath).existsSync()) {
        streamUrl = localPath;
        debugPrint(
          '[AudioPlayerNotifier] Playing downloaded file for ${song.title}',
        );
      }
    }

    streamUrl ??= predefinedStreamUrl ?? await apiService.getStreamUrl(song);

    if (currentToken != _playSongGenerationToken) {
      debugPrint('[AudioPlayerNotifier] Stale playSong request cancelled');
      return;
    }

    if (streamUrl != null) {
      state = state.copyWith(isLoading: false, currentStreamUrl: streamUrl);
      if (locator<it_feels_music_cast_service.CastService>().isConnected) {
        await engine.pause(); // Ensure local is paused
        await locator<it_feels_music_cast_service.CastService>().loadMedia(
          song,
          streamUrl,
          Duration.zero,
          true,
        );
      } else {
        await engine.playSong(song, streamUrl);
      }
      socialSync.updatePresence(song, true);
    } else {
      debugPrint(
        '[AudioPlayerNotifier] Failed to resolve stream for ${song.title}',
      );
    }

    _updateHomeWidget();
  }

  Future<void> play() async {
    state = state.copyWith(isPlaying: true); // Optimistic UI
    ref
        .read(activeMediaProvider.notifier)
        .setActiveMedia(ActiveMediaType.audio);

    if (locator<it_feels_music_cast_service.CastService>().isConnected) {
      await locator<it_feels_music_cast_service.CastService>().play();
    } else {
      await engine.play();
    }
    socialSync.updatePresence(state.currentSong, true);
  }

  Future<void> pause() async {
    state = state.copyWith(isPlaying: false); // Optimistic UI
    if (locator<it_feels_music_cast_service.CastService>().isConnected) {
      await locator<it_feels_music_cast_service.CastService>().pause();
    } else {
      await engine.pause();
    }
    socialSync.updatePresence(state.currentSong, false);
    _saveCurrentPosition();
  }

  Future<void> stop() async {
    if (locator<it_feels_music_cast_service.CastService>().isConnected) {
      await locator<it_feels_music_cast_service.CastService>().pause();
    } else {
      await engine.stop();
    }
    socialSync.updatePresence(state.currentSong, false);
    _saveCurrentPosition();
  }

  Future<void> closePlayer() async {
    await stop();
    state = state.copyWith(clearCurrentSong: true);
  }

  Future<void> _saveCurrentPosition() async {
    final song = state.currentSong;
    if (song != null) {
      final pos = engine.position;
      final updatedSong = song.copyWith(playbackPositionMs: pos.inMilliseconds);
      state = state.copyWith(currentSong: updatedSong);
      await DatabaseService().saveSong(updatedSong);
    }
  }

  Future<void> togglePlayPause() async {
    if (state.currentSong == null) return;
    triggerHaptic(heavy: true);

    if (engine.audioHandler.player.audioSource == null) {
      await playSong(
        state.currentSong!,
        queue: state.queue,
        index: state.currentIndex,
      );
      return;
    }

    final wasPlaying = state.isPlaying;
    // Optimistic UI Update for instant feedback
    state = state.copyWith(isPlaying: !wasPlaying);

    if (wasPlaying) {
      if (locator<it_feels_music_cast_service.CastService>().isConnected) {
        await locator<it_feels_music_cast_service.CastService>().pause();
      } else {
        await engine.pause();
      }
      socialSync.updatePresence(state.currentSong, false);
      _saveCurrentPosition();
    } else {
      if (locator<it_feels_music_cast_service.CastService>().isConnected) {
        await locator<it_feels_music_cast_service.CastService>().play();
      } else {
        await engine.play();
      }
      socialSync.updatePresence(state.currentSong, true);
    }
    _saveMemory();
  }

  Future<void> seek(Duration pos) async {
    if (locator<it_feels_music_cast_service.CastService>().isConnected) {
      await locator<it_feels_music_cast_service.CastService>().seek(pos);
    } else {
      await engine.seek(pos);
    }

    socialSync.updateRoomState(state.currentSong!, pos, state.isPlaying);
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
    await playSong(
      state.queue[nextIndex],
      queue: state.queue,
      index: nextIndex,
    );
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
    await playSong(
      state.queue[prevIndex],
      queue: state.queue,
      index: prevIndex,
    );
  }

  Future<void> _fadeOut() async {
    if (_isFading) return; // Prevent concurrent fadeouts from rapid skip taps
    _isFading = true;
    try {
      final fadeTime = state.crossfadeDuration.toInt();
      final step = 1.0 / (fadeTime * 10);
      double vol = 1.0;
      for (int i = 0; i < fadeTime * 10; i++) {
        vol -= step;
        if (vol < 0) vol = 0;
        await engine.audioHandler.player.setVolume(vol);
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } finally {
      _isFading = false;
      await engine.audioHandler.player.setVolume(1.0);
    }
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
    if (oldIndex < 0 ||
        oldIndex >= state.queue.length ||
        newIndex < 0 ||
        newIndex > state.queue.length)
      return;

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
    final target = engine.position + Duration(seconds: seconds);
    final clamped = target > state.duration ? state.duration : target;
    await seek(clamped);
  }

  Future<void> seekBackward({int seconds = 10}) async {
    final target = engine.position - Duration(seconds: seconds);
    final clamped = target < Duration.zero ? Duration.zero : target;
    await seek(clamped);
  }

  void toggleShuffle() {
    state = state.copyWith(isShuffle: !state.isShuffle);
  }

  void toggleRepeat() {
    state = state.copyWith(isRepeat: !state.isRepeat);
  }

  Future<void> _updateHomeWidget() async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await HomeWidget.saveWidgetData<String>(
          'title',
          state.currentSong?.title ?? 'No Song Playing',
        );
        await HomeWidget.saveWidgetData<String>(
          'artist',
          state.currentSong?.artist ?? 'It Feels Music',
        );
        await HomeWidget.updateWidget(name: 'MusicWidgetProvider');
      } catch (e) {
        debugPrint('Error updating home widget: $e');
      }
    }
  }

  Future<String?> startBroadcasting(String uid) async {
    if (state.currentSong == null) return null;
    final isPremium = ref.read(subscriptionProvider).isPremium;
    final roomId = await socialSync.startBroadcasting(
      uid,
      state.currentSong!,
      state.position,
      state.isPlaying,
      isPremium,
    );
    if (roomId != null) {
      state = state.copyWith(currentRoomId: roomId, isHost: true);
    }
    return roomId;
  }

  Future<void> joinSession(String roomId) async {
    state = state.copyWith(currentRoomId: roomId, isHost: false);
    await socialSync.joinSession(roomId);
  }

  void leaveSession() {
    socialSync.leaveSession();
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
