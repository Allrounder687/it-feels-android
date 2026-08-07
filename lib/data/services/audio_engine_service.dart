import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/audio_player_handler.dart';
import 'package:it_feels_music/services/storage_service.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/services/backend_api_service.dart';

enum AudioVibe {
  normal,
  slowedReverb,
  nightcore,
}

class AudioEngineService {
  late AudioPlayerHandler audioHandler;
  
  // Expose Streams for Notifier to bind to
  Stream<PlaybackState> get playbackStateStream => audioHandler.playbackState;
  Stream<Duration> get positionStream => audioHandler.player.positionStream;
  Stream<Duration?> get durationStream => audioHandler.player.durationStream;
  Stream<PlayerState> get playerStateStream => audioHandler.player.playerStateStream;
  
  // State getters
  bool get isPlaying => audioHandler.player.playing;
  Duration get position => audioHandler.player.position;
  Duration? get duration => audioHandler.player.duration;
  
  // The Notifier will maintain the true queue state, but we need to pass currentSong to ListenTogether
  Song? currentSong;
  
  Timer? _sleepTimer;
  
  bool isSleepTimerActive = false;
  DateTime? sleepTimerEndTime;
  bool sleepAfterCurrentTrack = false;
  
  // DSP & Haptics Cache
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
    
    final audioSettings = await StorageService.loadAudioSettings();
    await _applyAudioSettings(audioSettings);
  }

  Future<void> _applyAudioSettings(Map<String, dynamic> settings) async {
    try {
      final equalizer = audioHandler.equalizer;
      final loudnessEnhancer = audioHandler.loudnessEnhancer;
      
      playbackSpeed = settings['speed'] ?? 1.0;
      playbackPitch = settings['pitch'] ?? 1.0;
      await audioHandler.player.setSpeed(playbackSpeed);
      await audioHandler.player.setPitch(playbackPitch);

      isDspEngineEnabled = settings['dspEngine'] ?? false;
      uiHapticsEnabled = settings['uiHaptics'] ?? true;
      audioSyncHapticsEnabled = settings['audioSyncHaptics'] ?? false;
      isAutoplayEnabled = settings['autoplay'] ?? true;
      crossfadeDuration = settings['crossfade'] ?? 0.0;

      if (isDspEngineEnabled) {
        await _enableDspEngine(equalizer, loudnessEnhancer);
      } else {
        await _disableDspEngine(equalizer, loudnessEnhancer);
      }
    } catch (e) {
      debugPrint("Audio Enhancer initialization error: $e");
    }
  }

  Future<void> setDspEngine(bool enabled) async {
    isDspEngineEnabled = enabled;
    if (enabled) {
      await _enableDspEngine(audioHandler.equalizer, audioHandler.loudnessEnhancer);
    } else {
      await _disableDspEngine(audioHandler.equalizer, audioHandler.loudnessEnhancer);
    }
    saveAudioSettings();
  }

  Future<void> _enableDspEngine(AndroidEqualizer eq, AndroidLoudnessEnhancer le) async {
    try {
      if (Platform.isAndroid) {
        await le.setEnabled(true);
        await le.setTargetGain(0.4);

        await eq.setEnabled(true);
        final params = await eq.parameters;
        if (params.bands.length >= 5) {
          final hour = DateTime.now().hour;
          final isLateNight = hour >= 23 || hour <= 5;
          
          if (isLateNight) {
            // Sleepy EQ: Cut bass and highs to reduce ear fatigue
            await le.setTargetGain(0.1); // Lower loudness
            await params.bands[0].setGain(params.minDecibels * 0.3); // Cut sub-bass
            await params.bands[1].setGain(0);
            await params.bands[2].setGain(params.maxDecibels * 0.2); // Slight mid boost for vocals
            await params.bands[3].setGain(0);
            await params.bands[4].setGain(params.minDecibels * 0.4); // Cut harsh highs
            debugPrint('[AudioEngineService] Applied Late-Night Sleepy DSP profile');
          } else {
            // Normal Punchy EQ
            await params.bands[0].setGain(params.maxDecibels * 0.5);
            await params.bands[1].setGain(params.maxDecibels * 0.2);
            await params.bands[2].setGain(0);
            await params.bands[3].setGain(params.maxDecibels * 0.3);
            await params.bands[4].setGain(params.maxDecibels * 0.6);
          }
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
      playbackSpeed = speed;
      saveAudioSettings();
    } catch (e) {
      debugPrint("Error setting Speed: $e");
    }
  }

  Future<void> setPlaybackPitch(double pitch) async {
    try {
      await audioHandler.player.setPitch(pitch);
      playbackPitch = pitch;
      saveAudioSettings();
    } catch (e) {
      debugPrint("Error setting Pitch: $e");
    }
  }

  void setCrossfadeDuration(double duration) {
    crossfadeDuration = duration;
    saveAudioSettings();
  }

  Future<void> saveAudioSettings() async {
    try {
      await StorageService.saveAudioSettings(
        dspEngine: isDspEngineEnabled,
        uiHaptics: uiHapticsEnabled,
        audioSyncHaptics: audioSyncHapticsEnabled,
        speed: playbackSpeed,
        pitch: playbackPitch,
        autoplay: isAutoplayEnabled,
        crossfade: crossfadeDuration,
      );
    } catch (e) {
      debugPrint("Error saving Audio Settings: $e");
    }
  }

  Future<void> setAudioVibe(AudioVibe vibe) async {
    currentVibe = vibe;
    
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
        break;
      case AudioVibe.nightcore:
        await setPlaybackSpeed(1.15);
        await setPlaybackPitch(1.15);
        await setDspEngine(true);
        break;
    }
  }

  // Sleep Timer
  void startSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    sleepTimerEndTime = DateTime.now().add(duration);
    isSleepTimerActive = true;
    _sleepTimerController.add(sleepTimerEndTime);
    
    _sleepTimer = Timer(duration, () {
      audioHandler.pause();
      isSleepTimerActive = false;
      sleepTimerEndTime = null;
      _sleepTimerController.add(null);
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    isSleepTimerActive = false;
    sleepTimerEndTime = null;
    _sleepTimerController.add(null);
    
    sleepAfterCurrentTrack = false;
    _sleepAfterTrackController.add(false);
  }

  void setSleepAfterCurrentTrack() {
    sleepAfterCurrentTrack = true;
    _sleepAfterTrackController.add(true);
  }

  // Playback Controls
  Future<void> play() => audioHandler.play();
  Future<void> pause() => audioHandler.pause();
  Future<void> stop() => audioHandler.stop();
  Future<void> seek(Duration pos) => audioHandler.seek(pos);
  Future<void> skipToNext() => audioHandler.skipToNext();
  Future<void> skipToPrevious() => audioHandler.skipToPrevious();

  Future<void> playSong(Song song, String streamUrl) async {
    await audioHandler.playSong(song, streamUrl);
  }
}
