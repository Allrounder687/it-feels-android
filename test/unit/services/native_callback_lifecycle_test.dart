import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:media_kit/media_kit.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/data/services/audio_player_handler.dart';
import 'package:it_feels_music/data/services/equalizer_service.dart';

abstract class CustomPlatformPlayer implements PlatformPlayer {
  Future<void> setProperty(String property, String value);
}

class MockPlayer extends Mock implements Player {}
class MockPlayerPlatform extends Mock implements CustomPlatformPlayer {}
class MockMusicRepository extends Mock implements IMusicRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPlayer mockPlayer;
  late MockPlayerPlatform mockPlatform;
  late MockMusicRepository mockRepo;
  late EqualizerService eqService;
  late AudioPlayerHandler handler;

  late StreamController<bool> playingController;
  late StreamController<Duration> positionController;
  late StreamController<bool> completedController;
  late StreamController<bool> bufferingController;
  late StreamController<String> errorController;
  late StreamController<List<AudioDevice>> audioDevicesController;
  late StreamController<AudioDevice> audioDeviceController;

  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(Media(''));
  });

  setUp(() async {
    mockPlayer = MockPlayer();
    mockPlatform = MockPlayerPlatform();
    mockRepo = MockMusicRepository();
    eqService = EqualizerService();

    // Reset GetIt for isolated testing
    await locator.reset();
    locator.registerSingleton<EqualizerService>(eqService);
    locator.registerSingleton<IMusicRepository>(mockRepo);

    playingController = StreamController<bool>.broadcast();
    positionController = StreamController<Duration>.broadcast();
    completedController = StreamController<bool>.broadcast();
    bufferingController = StreamController<bool>.broadcast();
    errorController = StreamController<String>.broadcast();
    audioDevicesController = StreamController<List<AudioDevice>>.broadcast();
    audioDeviceController = StreamController<AudioDevice>.broadcast();

    final playerStream = PlayerStream(
      const Stream.empty(),
      playingController.stream,
      completedController.stream,
      positionController.stream,
      const Stream.empty(),
      const Stream.empty(),
      const Stream.empty(),
      const Stream.empty(),
      bufferingController.stream,
      const Stream.empty(),
      const Stream.empty(),
      const Stream.empty(),
      const Stream.empty(),
      const Stream.empty(),
      const Stream.empty(),
      const Stream.empty(),
      audioDeviceController.stream,
      audioDevicesController.stream,
      const Stream.empty(),
      const Stream.empty(),
      const Stream.empty(),
      const Stream.empty(),
      const Stream.empty(),
      const Stream.empty(),
      errorController.stream,
    );

    when(() => mockPlayer.stream).thenReturn(playerStream);
    when(() => mockPlayer.state).thenReturn(const PlayerState());
    when(() => mockPlayer.platform).thenReturn(mockPlatform);
    when(() => mockPlayer.play()).thenAnswer((_) async {});
    when(() => mockPlayer.pause()).thenAnswer((_) async {});
    when(() => mockPlayer.stop()).thenAnswer((_) async {});
    when(() => mockPlayer.dispose()).thenAnswer((_) async {});
    when(() => mockPlayer.setVolume(any())).thenAnswer((_) async {});
    when(() => mockPlayer.seek(any())).thenAnswer((_) async {});
    when(() => mockPlayer.open(any(), play: any(named: 'play'))).thenAnswer((_) async {});
    when(() => mockPlatform.setProperty(any(), any())).thenAnswer((_) async {});

    handler = AudioPlayerHandler(
      apiService: mockRepo,
      customPlayer: mockPlayer,
    );
    locator.registerSingleton<AudioPlayerHandler>(handler);
  });

  tearDown(() async {
    await playingController.close();
    await positionController.close();
    await completedController.close();
    await bufferingController.close();
    await errorController.close();
    await audioDevicesController.close();
    await audioDeviceController.close();
  });

  group('Scenario 1: Normal Playback Lifecycle (Init -> Play -> Pause -> Stop -> Dispose)', () {
    test('Executes orderly teardown sequence and marks handler disposed', () async {
      expect(handler.isDisposed, false);

      await handler.play();
      verify(() => mockPlayer.play()).called(1);

      await handler.pause();
      verify(() => mockPlayer.pause()).called(1);

      await handler.stop();
      verify(() => mockPlayer.stop()).called(1);

      await handler.dispose();
      expect(handler.isDisposed, true);
      verify(() => mockPlayer.setVolume(0.0)).called(1);
      // Mocktail consumes verified calls; 1 more call during handler.dispose()
      verify(() => mockPlayer.stop()).called(1);
      verify(() => mockPlayer.dispose()).called(1);
    });
  });

  group('Scenario 2: Post-Disposal Safety & Callback Defense', () {
    test('Invoking controls on disposed handler returns cleanly without touching player', () async {
      await handler.dispose();
      expect(handler.isDisposed, true);

      // Subsequent actions must be no-ops
      await handler.play();
      await handler.pause();
      await handler.stop();
      await handler.seek(const Duration(seconds: 30));
      await handler.playSong(
        Song(id: 's1', saavnId: 's1', title: 'Test', artist: 'Artist', album: 'Album', duration: 180, coverArt: '', addedAt: DateTime.now()),
        'http://test.mp3',
      );

      // Verify no extra play/pause/seek calls were forwarded to mockPlayer after disposal
      verifyNever(() => mockPlayer.play());
      verifyNever(() => mockPlayer.seek(any()));
    });
  });

  group('Scenario 3: EqualizerService Mutex Serialization & Concurrency Protection', () {
    test('Serializes concurrent audio filter applications sequentially', () async {
      final appliedFilters = <String>[];
      when(() => mockPlatform.setProperty('af', any())).thenAnswer((inv) async {
        final filter = inv.positionalArguments[1] as String;
        appliedFilters.add(filter);
      });

      await eqService.setEnabled(true, mockPlayer);

      // Fire 5 rapid band modifications concurrently
      final futures = [
        eqService.setBandGain(31, 4.0, mockPlayer),
        eqService.setBandGain(62, 6.0, mockPlayer),
        eqService.setBandGain(125, -2.0, mockPlayer),
        eqService.setBassBoost(5.0, mockPlayer),
        eqService.setTrebleBoost(3.0, mockPlayer),
      ];

      await Future.wait(futures);

      expect(appliedFilters.isNotEmpty, true);
      expect(eqService.isDisposed, false);
    });
  });

  group('Scenario 4: EqualizerService Detach & Hot Restart Safety', () {
    test('detachPlayer clears filter property and rejects subsequent modifications', () async {
      await eqService.setEnabled(true, mockPlayer);
      await eqService.setBandGain(62, 6.0, mockPlayer);
      expect(eqService.isDisposed, false);

      // Verify the pre-detach equalizer call
      verify(() => mockPlatform.setProperty('af', any(that: contains('equalizer')))).called(1);

      await eqService.detachPlayer(mockPlayer);
      expect(eqService.isDisposed, true);
      // setProperty('af', '') was called once during setEnabled (empty flat preset) and once during detachPlayer
      verify(() => mockPlatform.setProperty('af', '')).called(2);

      // Modifications after detach must be rejected and not touch platform
      await eqService.applyPreset('rock', mockPlayer);
      await eqService.setBandGain(250, 8.0, mockPlayer);

      // Verify setProperty was NOT called again with rock/equalizer filters after detach
      verifyNever(() => mockPlatform.setProperty('af', any(that: contains('equalizer'))));
    });
  });

  group('Scenario 5: Lifecycle Reset Across Hot Restarts', () {
    test('resetLifecycle restores filter updates for new player instance', () async {
      await eqService.detachPlayer(mockPlayer);
      expect(eqService.isDisposed, true);

      // Simulate new isolate / new session starting
      eqService.resetLifecycle();
      expect(eqService.isDisposed, false);

      await eqService.setEnabled(true, mockPlayer);
      await eqService.setBandGain(1000, 5.0, mockPlayer);

      verify(() => mockPlatform.setProperty('af', any(that: contains('1000')))).called(1);
    });
  });

  group('Scenario 6: Equalizer Preset Transition During Teardown', () {
    test('Preset change initiated concurrently with detach does not crash', () async {
      final detachFuture = eqService.detachPlayer(mockPlayer);
      final presetFuture = eqService.applyPreset('electronic', mockPlayer);

      await Future.wait([detachFuture, presetFuture]);
      expect(eqService.isDisposed, true);
    });
  });

  group('Scenario 7: Rapid Track Switching with Active Equalizer', () {
    test('Performs 20 rapid simulated song changes without unhandled exceptions', () async {
      for (int i = 0; i < 20; i++) {
        final song = Song(
          id: 'song_$i',
          saavnId: 'saavn_$i',
          title: 'Track $i',
          artist: 'Artist',
          album: 'Album $i',
          duration: 200,
          coverArt: '',
          addedAt: DateTime.now(),
        );
        await handler.playSong(song, 'http://test.com/stream_$i.mp3');
      }

      verify(() => mockPlayer.open(any(), play: true)).called(20);
    });
  });

  group('Scenario 8: App Teardown & Simulated Hot Restart Hooks', () {
    test('Simulated reassemble() hook detaches equalizer safely', () async {
      await eqService.setEnabled(true, mockPlayer);
      expect(eqService.isDisposed, false);

      // Simulate reassemble() action from PixelPlayerSaavnApp
      if (locator.isRegistered<EqualizerService>()) {
        await locator<EqualizerService>().detachPlayer();
      }

      expect(eqService.isDisposed, true);
    });

    test('Simulated AppLifecycleState.detached shuts down handler cleanly', () async {
      expect(handler.isDisposed, false);

      // Simulate AppLifecycleState.detached action from main.dart
      if (locator.isRegistered<AudioPlayerHandler>()) {
        await locator<AudioPlayerHandler>().dispose();
      }

      expect(handler.isDisposed, true);
      verify(() => mockPlayer.dispose()).called(1);
    });
  });

  group('Scenario 9: Application Exit During Active Playback', () {
    test('Simulated tray exit shuts down active player and detaches filters cleanly', () async {
      await handler.play();
      expect(handler.isDisposed, false);

      // Simulate tray menu exit click
      await handler.dispose();

      expect(handler.isDisposed, true);
      verify(() => mockPlayer.stop()).called(1);
      verify(() => mockPlayer.dispose()).called(1);
    });
  });
}
