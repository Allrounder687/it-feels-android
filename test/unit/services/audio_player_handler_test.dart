import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:audio_service/audio_service.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/audio_player_handler.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}
class MockAndroidEqualizer extends Mock implements AndroidEqualizer {}
class MockAndroidLoudnessEnhancer extends Mock implements AndroidLoudnessEnhancer {}
class MockMusicApiService extends Mock implements MusicApiService {}

void main() {
  late MockAudioPlayer mockPlayer;
  late MockAndroidEqualizer mockEqualizer;
  late MockAndroidLoudnessEnhancer mockLoudnessEnhancer;
  late MockMusicApiService mockMusicApiService;
  late AudioPlayerHandler handler;

  setUpAll(() {
    registerFallbackValue(AudioSource.uri(Uri()));
  });

  setUp(() {
    mockPlayer = MockAudioPlayer();
    mockEqualizer = MockAndroidEqualizer();
    mockLoudnessEnhancer = MockAndroidLoudnessEnhancer();
    mockMusicApiService = MockMusicApiService();

    // Setup stubbing for just_audio streams so init doesn't throw or block
    when(() => mockPlayer.playbackEventStream).thenAnswer((_) => const Stream.empty());
    when(() => mockPlayer.playingStream).thenAnswer((_) => Stream.value(false));
    when(() => mockPlayer.positionStream).thenAnswer((_) => Stream.value(Duration.zero));
    when(() => mockPlayer.durationStream).thenAnswer((_) => Stream.value(null));
    when(() => mockPlayer.playerStateStream).thenAnswer((_) => Stream.value(PlayerState(false, ProcessingState.idle)));
    when(() => mockPlayer.playbackEvent).thenReturn(PlaybackEvent());
    when(() => mockPlayer.playing).thenReturn(false);
    when(() => mockPlayer.processingState).thenReturn(ProcessingState.idle);
    when(() => mockPlayer.speed).thenReturn(1.0);
    when(() => mockPlayer.position).thenReturn(Duration.zero);
    when(() => mockPlayer.bufferedPosition).thenReturn(Duration.zero);
    when(() => mockPlayer.play()).thenAnswer((_) async {});
    when(() => mockPlayer.pause()).thenAnswer((_) async {});
    when(() => mockPlayer.stop()).thenAnswer((_) async {});

    handler = AudioPlayerHandler(
      apiService: mockMusicApiService,
      customPlayer: mockPlayer,
      customEqualizer: mockEqualizer,
      customLoudnessEnhancer: mockLoudnessEnhancer,
    );
  });

  group('AudioPlayerHandler Basic Controls', () {
    test('play delegates to AudioPlayer', () async {
      await handler.play();
      verify(() => mockPlayer.play()).called(1);
    });

    test('pause delegates to AudioPlayer', () async {
      await handler.pause();
      verify(() => mockPlayer.pause()).called(1);
    });

    test('stop delegates to AudioPlayer', () async {
      await handler.stop();
      verify(() => mockPlayer.stop()).called(1);
    });

    test('seek delegates to AudioPlayer', () async {
      const target = Duration(seconds: 45);
      when(() => mockPlayer.seek(target)).thenAnswer((_) async {});
      await handler.seek(target);
      verify(() => mockPlayer.seek(target)).called(1);
    });
  });

  group('AudioPlayerHandler customAction & skip callbacks', () {
    test('customAction like_song triggers onToggleFavorite callback', () async {
      var callbackCalled = false;
      handler.onToggleFavorite = () async {
        callbackCalled = true;
      };

      await handler.customAction('like_song');
      expect(callbackCalled, isTrue);
    });

    test('skipToNext triggers onSkipNext callback', () async {
      var callbackCalled = false;
      handler.onSkipNext = () {
        callbackCalled = true;
      };

      await handler.skipToNext();
      expect(callbackCalled, isTrue);
    });

    test('skipToPrevious triggers onSkipPrevious callback', () async {
      var callbackCalled = false;
      handler.onSkipPrevious = () {
        callbackCalled = true;
      };

      await handler.skipToPrevious();
      expect(callbackCalled, isTrue);
    });
  });

  group('AudioPlayerHandler playSong', () {
    test('playSong sets file audio source for local paths', () async {
      final song = Song(
        id: '123',
        saavnId: '',
        title: 'Local Song',
        artist: 'Artist',
        album: 'Album',
        duration: 180,
        coverArt: '',
        genre: '',
        year: 2026,
        language: 'English',
        isExplicit: false,
        playCount: 0,
        skipCount: 0,
        addedAt: DateTime.now(),
        isFavorite: false,
        offlineStatus: OfflineStatus.none,
        searchVector: [],
      );

      when(() => mockPlayer.setAudioSource(any(), initialPosition: any(named: 'initialPosition')))
          .thenAnswer((_) async => null);

      await handler.playSong(song, 'file://path/to/song.mp3');

      verify(() => mockPlayer.stop()).called(1);
      verify(() => mockPlayer.setAudioSource(
            any(that: isA<ProgressiveAudioSource>()),
            initialPosition: Duration.zero,
          )).called(1);
    });

    test('playSong sets uri audio source for remote URLs', () async {
      final song = Song(
        id: '123',
        saavnId: '',
        title: 'Remote Song',
        artist: 'Artist',
        album: 'Album',
        duration: 180,
        coverArt: '',
        genre: '',
        year: 2026,
        language: 'English',
        isExplicit: false,
        playCount: 0,
        skipCount: 0,
        addedAt: DateTime.now(),
        isFavorite: false,
        offlineStatus: OfflineStatus.none,
        searchVector: [],
      );

      when(() => mockPlayer.setAudioSource(any(), initialPosition: any(named: 'initialPosition')))
          .thenAnswer((_) async => null);

      await handler.playSong(song, 'https://example.com/stream.mp3');

      verify(() => mockPlayer.stop()).called(1);
      verify(() => mockPlayer.setAudioSource(
            any(that: isA<UriAudioSource>()),
            initialPosition: Duration.zero,
          )).called(1);
    });
  });
}
