import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:windows_taskbar/windows_taskbar.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/audio_player_handler.dart';
import 'package:it_feels_music/services/storage_service.dart';
import 'package:home_widget/home_widget.dart';

enum AudioVibe {
  normal,
  slowedReverb,
  nightcore,
}

class AudioEngineService {
  late AudioPlayerHandler audioHandler;
  
  Stream<PlaybackState> get playbackStateStream => audioHandler.playbackState;
  Stream<Duration> get positionStream => audioHandler.player.stream.position;
  Stream<Duration> get durationStream => audioHandler.player.stream.duration;
  
  bool get isPlaying => audioHandler.player.state.playing;
  Duration get position => audioHandler.player.state.position;
  Duration? get duration => audioHandler.player.state.duration;
  
  Stream<bool> get playerStateStream => audioHandler.player.stream.playing;
  Stream<bool> get bufferingStream => audioHandler.player.stream.buffering;
  Stream<bool> get trackCompletedStream => audioHandler.player.stream.completed;
  
  Song? currentSong;
  
  StreamSubscription? _positionSub;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _mediaItemSub;
  DateTime _lastTaskbarUpdate = DateTime(2000);
  Timer? _sleepTimer;
  
  bool isSleepTimerActive = false;
  DateTime? sleepTimerEndTime;
  bool sleepAfterCurrentTrack = false;
  
  bool isDspEngineEnabled = false;
  bool uiHapticsEnabled = true;
  bool audioSyncHapticsEnabled = false;
  bool isAutoplayEnabled = true;
  double crossfadeDuration = 0.0;
  double playbackSpeed = 1.0;
  double playbackPitch = 1.0;
  AudioVibe currentVibe = AudioVibe.normal;
  
  final _sleepTimerController = StreamController<DateTime?>.broadcast();
  Stream<DateTime?> get sleepTimerStream => _sleepTimerController.stream;

  final _sleepAfterTrackController = StreamController<bool>.broadcast();
  Stream<bool> get sleepAfterTrackStream => _sleepAfterTrackController.stream;

  Future<void> init(AudioPlayerHandler handler) async {
    audioHandler = handler;
    
    if (!kIsWeb && Platform.isWindows) {
      try { WindowsTaskbar.setProgressMode(TaskbarProgressMode.normal).catchError((_) {}); } catch (_) {}
      _positionSub = positionStream.listen((pos) {
        final now = DateTime.now();
        if (now.difference(_lastTaskbarUpdate).inMilliseconds < 1000) return;
        _lastTaskbarUpdate = now;

        final dur = duration;
        if (dur != null && dur.inMilliseconds > 0) {
          try { WindowsTaskbar.setProgress(pos.inMilliseconds, dur.inMilliseconds).catchError((_) {}); } catch (_) {}
        }
      });
      _playerStateSub = audioHandler.player.stream.playing.listen((playing) {
        try {
          _updateWindowsTaskbarThumbnail(playing);
          if (playing) {
            WindowsTaskbar.setProgressMode(TaskbarProgressMode.normal).catchError((_) {});
          } else {
            WindowsTaskbar.setProgressMode(TaskbarProgressMode.paused).catchError((_) {});
          }
        } catch (_) {}
      });
      _setupWindowsTaskbar();
    }

    if (!kIsWeb && Platform.isIOS) {
      HomeWidget.setAppGroupId('group.com.itfeels.music');
      _mediaItemSub = audioHandler.mediaItem.listen((item) {
        if (item != null) {
          HomeWidget.saveWidgetData('widget_title', item.title);
          HomeWidget.saveWidgetData('widget_artist', item.artist ?? 'Unknown');
          HomeWidget.updateWidget(name: 'ITFeelsWidget');
        }
      });
    }

    final audioSettings = await StorageService.loadAudioSettings();
    await _applyAudioSettings(audioSettings);
  }

  Future<void> _applyAudioSettings(Map<String, dynamic> settings) async {
    try {
      playbackSpeed = settings['speed'] ?? 1.0;
      playbackPitch = settings['pitch'] ?? 1.0;
      await audioHandler.player.setRate(playbackSpeed);
      await audioHandler.player.setPitch(playbackPitch);

      isDspEngineEnabled = settings['dspEngine'] ?? false;
      uiHapticsEnabled = settings['uiHaptics'] ?? true;
      audioSyncHapticsEnabled = settings['audioSyncHaptics'] ?? false;
      isAutoplayEnabled = settings['autoplay'] ?? true;
      crossfadeDuration = settings['crossfade'] ?? 0.0;

      await setDspEngine(isDspEngineEnabled);
    } catch (e) {
      debugPrint("Audio Enhancer initialization error: $e");
    }
  }

  Future<void> setDspEngine(bool enabled) async {
    isDspEngineEnabled = enabled;
    try {
      if (enabled) {
        // Boost low frequencies and high frequencies using libmpv audio filters
        final af = 'equalizer=f=64:width_type=q:w=1:g=5,equalizer=f=4000:width_type=q:w=1:g=3';
        try {
          // Access the NativePlayer's setProperty method dynamically
          await (audioHandler.player.platform as dynamic).setProperty('af', af);
        } catch (_) {
          // Fallback if platform does not support setProperty
          await audioHandler.player.setVolume(120.0);
        }
      } else {
        try {
          await (audioHandler.player.platform as dynamic).setProperty('af', '');
        } catch (_) {
          await audioHandler.player.setVolume(100.0);
        }
      }
      saveAudioSettings();
    } catch (e) {
      debugPrint('[AudioEngine] Failed to apply DSP: $e');
    }
  }

  Future<void> openSystemEqualizer() async {
    // Deprecated with media_kit migration
    debugPrint("System Equalizer handoff is deprecated. Using unified media_kit DSP instead.");
  }

  Future<void> setPlaybackSpeed(double speed) async {
    playbackSpeed = speed;
    if (currentVibe == AudioVibe.normal) {
      await audioHandler.player.setRate(speed);
      saveAudioSettings();
    }
  }

  Future<void> setPlaybackPitch(double pitch) async {
    playbackPitch = pitch;
    if (currentVibe == AudioVibe.normal) {
      await audioHandler.player.setPitch(pitch);
      saveAudioSettings();
    }
  }

  Future<void> setAudioVibe(AudioVibe vibe) async {
    currentVibe = vibe;
    try {
      switch (vibe) {
        case AudioVibe.slowedReverb:
          await audioHandler.player.setRate(0.85);
          await audioHandler.player.setPitch(0.85);
          break;
        case AudioVibe.nightcore:
          await audioHandler.player.setRate(1.25);
          await audioHandler.player.setPitch(1.25);
          break;
        case AudioVibe.normal:
          await audioHandler.player.setRate(playbackSpeed);
          await audioHandler.player.setPitch(playbackPitch);
          break;
      }
    } catch (e) {
      // Ignored: platform/engine pitch or rate change error
    }
  }

  Future<void> setCrossfadeDuration(double seconds) async {
    crossfadeDuration = seconds;
    saveAudioSettings();
  }

  void setSleepAfterCurrentTrack(bool value) {
    sleepAfterCurrentTrack = value;
    _sleepAfterTrackController.add(value);
  }

  void notifyLoading(Song song) => audioHandler.notifyLoading(song);
  void cancelLoading() => audioHandler.cancelLoading();

  Future<void> playSong(Song song, String streamUrl) async {
    await audioHandler.playSong(song, streamUrl);
  }

  Future<void> saveAudioSettings() async {
    await StorageService.saveAudioSettings(
      speed: playbackSpeed,
      pitch: playbackPitch,
      dspEngine: isDspEngineEnabled,
      uiHaptics: uiHapticsEnabled,
      audioSyncHaptics: audioSyncHapticsEnabled,
      autoplay: isAutoplayEnabled,
      crossfade: crossfadeDuration,
    );
  }

  Future<void> play() async => await audioHandler.play();
  Future<void> pause() async => await audioHandler.pause();
  Future<void> stop() async => await audioHandler.stop();
  Future<void> seek(Duration pos) async => await audioHandler.seek(pos);
  Future<void> skipToNext() async => await audioHandler.skipToNext();
  Future<void> skipToPrevious() async => await audioHandler.skipToPrevious();

  void triggerHaptic() {
    if (uiHapticsEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  void startSleepTimer(Duration duration, {bool finishTrack = false}) {
    isSleepTimerActive = true;
    sleepTimerEndTime = DateTime.now().add(duration);
    sleepAfterCurrentTrack = finishTrack;
    
    _sleepTimer?.cancel();
    _sleepTimerController.add(sleepTimerEndTime);
    _sleepAfterTrackController.add(sleepAfterCurrentTrack);

    _sleepTimer = Timer(duration, () {
      if (!sleepAfterCurrentTrack) {
        pause();
        cancelSleepTimer();
      }
    });
  }

  void cancelSleepTimer() {
    isSleepTimerActive = false;
    sleepTimerEndTime = null;
    sleepAfterCurrentTrack = false;
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerController.add(null);
    _sleepAfterTrackController.add(false);
  }

  void handleTrackCompleted() {
    if (isSleepTimerActive && sleepAfterCurrentTrack) {
      final now = DateTime.now();
      if (sleepTimerEndTime != null && now.isAfter(sleepTimerEndTime!)) {
        pause();
        cancelSleepTimer();
      }
    }
  }

  void dispose() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _mediaItemSub?.cancel();
    _sleepTimer?.cancel();
    _sleepTimerController.close();
        _sleepAfterTrackController.close();
  }

  void _setupWindowsTaskbar() {
    try {
      WindowsTaskbar.resetThumbnailToolbar().catchError((_) {});
      WindowsTaskbar.setThumbnailToolbar([
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon('assets/icons/prev.ico'),
          'Previous',
          () => audioHandler.skipToPrevious(),
        ),
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon('assets/icons/play.ico'),
          'Play',
          () => audioHandler.play(),
        ),
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon('assets/icons/next.ico'),
          'Next',
          () => audioHandler.skipToNext(),
        ),
      ]).catchError((_) {});
    } catch (_) {}
  }

  void _updateWindowsTaskbarThumbnail(bool isPlaying) {
    try {
      WindowsTaskbar.setThumbnailToolbar([
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon('assets/icons/prev.ico'),
          'Previous',
          () => audioHandler.skipToPrevious(),
        ),
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon(isPlaying ? 'assets/icons/pause.ico' : 'assets/icons/play.ico'),
          isPlaying ? 'Pause' : 'Play',
          () => isPlaying ? audioHandler.pause() : audioHandler.play(),
        ),
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon('assets/icons/next.ico'),
          'Next',
          () => audioHandler.skipToNext(),
        ),
      ]).catchError((_) {});
      
      if (isPlaying) {
        WindowsTaskbar.setOverlayIcon(ThumbnailToolbarAssetIcon('assets/icons/play.ico'), tooltip: 'Playing').catchError((_) {});
      } else {
        WindowsTaskbar.setOverlayIcon(ThumbnailToolbarAssetIcon('assets/icons/pause.ico'), tooltip: 'Paused').catchError((_) {});
      }
    } catch (_) {}
  }
}
