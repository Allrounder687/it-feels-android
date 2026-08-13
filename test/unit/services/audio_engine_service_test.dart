import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/audio_engine_service.dart';
import 'package:it_feels_music/data/services/audio_player_handler.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}
class MockAndroidEqualizer extends Mock implements AndroidEqualizer {}
class MockAndroidLoudnessEnhancer extends Mock implements AndroidLoudnessEnhancer {}
class MockAudioPlayerHandler extends Mock implements AudioPlayerHandler {}

void main() {
  late MockAudioPlayer mockPlayer;
  late MockAndroidEqualizer mockEqualizer;
  late MockAndroidLoudnessEnhancer mockLoudnessEnhancer;
  late MockAudioPlayerHandler mockHandler;
  late AudioEngineService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'dspEngine': false,
      'uiHaptics': true,
      'audioSyncHaptics': false,
      'audio_speed_v1': 1.0,
      'audio_pitch_v1': 1.0,
      'autoplay': true,
      'crossfade_v1': 0.0,
    });

    mockPlayer = MockAudioPlayer();
    mockEqualizer = MockAndroidEqualizer();
    mockLoudnessEnhancer = MockAndroidLoudnessEnhancer();
    mockHandler = MockAudioPlayerHandler();

    // Stub AudioPlayerHandler fields & methods
    when(() => mockHandler.player).thenReturn(mockPlayer);
    when(() => mockHandler.equalizer).thenReturn(mockEqualizer);
    when(() => mockHandler.loudnessEnhancer).thenReturn(mockLoudnessEnhancer);
    
    final mockPlaybackState = PlaybackState(
      playing: false,
      processingState: AudioProcessingState.idle,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      speed: 1.0,
    );
    when(() => mockHandler.playbackState).thenAnswer((_) => BehaviorSubject<PlaybackState>.seeded(mockPlaybackState));
    when(() => mockPlayer.positionStream).thenAnswer((_) => Stream.value(Duration.zero));
    when(() => mockPlayer.durationStream).thenAnswer((_) => Stream.value(null));
    when(() => mockPlayer.playerStateStream).thenAnswer((_) => Stream.value(PlayerState(false, ProcessingState.idle)));
    
    when(() => mockPlayer.playing).thenReturn(false);
    when(() => mockPlayer.position).thenReturn(Duration.zero);
    when(() => mockPlayer.duration).thenReturn(null);

    when(() => mockPlayer.setSpeed(any())).thenAnswer((_) async {});
    when(() => mockPlayer.setPitch(any())).thenAnswer((_) async {});

    service = AudioEngineService();
    await service.init(mockHandler);
  });

  group('AudioEngineService Initialization', () {
    test('loads default preferences correctly on init', () {
      expect(service.playbackSpeed, 1.0);
      expect(service.playbackPitch, 1.0);
      expect(service.isDspEngineEnabled, isFalse);
      expect(service.uiHapticsEnabled, isTrue);
      expect(service.audioSyncHapticsEnabled, isFalse);
      expect(service.isAutoplayEnabled, isTrue);
      expect(service.crossfadeDuration, 0.0);
      
      verify(() => mockPlayer.setSpeed(1.0)).called(1);
      verify(() => mockPlayer.setPitch(1.0)).called(1);
    });
  });

  group('AudioEngineService Pitch/Speed Controls', () {
    test('setPlaybackSpeed updates value and delegates to player', () async {
      await service.setPlaybackSpeed(1.2);
      expect(service.playbackSpeed, 1.2);
      verify(() => mockPlayer.setSpeed(1.2)).called(1);
      
      await Future.delayed(Duration.zero); // yield for async SharedPreferences save
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('audio_speed_v1'), 1.2);
    });

    test('setPlaybackPitch updates value and delegates to player', () async {
      await service.setPlaybackPitch(0.9);
      expect(service.playbackPitch, 0.9);
      verify(() => mockPlayer.setPitch(0.9)).called(1);
      
      await Future.delayed(Duration.zero); // yield for async SharedPreferences save
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('audio_pitch_v1'), 0.9);
    });

    test('setCrossfadeDuration updates value and saves settings', () async {
      service.setCrossfadeDuration(3.5);
      expect(service.crossfadeDuration, 3.5);
      
      await Future.delayed(Duration.zero); // yield for async SharedPreferences save
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('crossfade_v1'), 3.5);
    });
  });

  group('AudioEngineService AudioVibes mapping', () {
    test('setAudioVibe normal resets speed/pitch/dsp', () async {
      await service.setAudioVibe(AudioVibe.normal);
      expect(service.playbackSpeed, 1.0);
      expect(service.playbackPitch, 1.0);
      expect(service.isDspEngineEnabled, isFalse);
    });

    test('setAudioVibe slowedReverb slows down and enables DSP', () async {
      await service.setAudioVibe(AudioVibe.slowedReverb);
      expect(service.playbackSpeed, 0.85);
      expect(service.playbackPitch, 0.85);
      expect(service.isDspEngineEnabled, isTrue);
    });

    test('setAudioVibe nightcore speeds up and enables DSP', () async {
      await service.setAudioVibe(AudioVibe.nightcore);
      expect(service.playbackSpeed, 1.15);
      expect(service.playbackPitch, 1.15);
      expect(service.isDspEngineEnabled, isTrue);
    });
  });

  group('AudioEngineService Sleep Timer', () {
    test('startSleepTimer sets endTime and schedules callback to pause', () async {
      when(() => mockHandler.pause()).thenAnswer((_) async {});
      
      var endTimes = <DateTime?>[];
      service.sleepTimerStream.listen((t) => endTimes.add(t));
      
      service.startSleepTimer(const Duration(milliseconds: 50));
      expect(service.isSleepTimerActive, isTrue);
      expect(service.sleepTimerEndTime, isNotNull);
      
      await Future.delayed(const Duration(milliseconds: 70));
      
      expect(service.isSleepTimerActive, isFalse);
      verify(() => mockHandler.pause()).called(1);
      expect(endTimes, contains(null));
    });

    test('cancelSleepTimer clears all states', () async {
      service.startSleepTimer(const Duration(seconds: 10));
      expect(service.isSleepTimerActive, isTrue);
      
      service.cancelSleepTimer();
      expect(service.isSleepTimerActive, isFalse);
      expect(service.sleepTimerEndTime, isNull);
      expect(service.sleepAfterCurrentTrack, isFalse);
    });

    test('setSleepAfterCurrentTrack sets flag', () {
      service.setSleepAfterCurrentTrack();
      expect(service.sleepAfterCurrentTrack, isTrue);
    });
  });
}
