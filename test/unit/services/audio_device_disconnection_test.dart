import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:media_kit/media_kit.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/data/services/audio_player_handler.dart';

class MockPlayer extends Mock implements Player {}
class MockPlayerState extends Mock implements PlayerState {}
class MockMusicRepository extends Mock implements IMusicRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPlayer mockPlayer;
  late MockPlayerState mockState;
  late MockMusicRepository mockRepo;

  late StreamController<bool> playingController;
  late StreamController<Duration> positionController;
  late StreamController<bool> completedController;
  late StreamController<bool> bufferingController;
  late StreamController<List<AudioDevice>> audioDevicesController;
  late StreamController<AudioDevice> audioDeviceController;

  setUp(() {
    mockPlayer = MockPlayer();
    mockState = MockPlayerState();
    mockRepo = MockMusicRepository();

    playingController = StreamController<bool>.broadcast();
    positionController = StreamController<Duration>.broadcast();
    completedController = StreamController<bool>.broadcast();
    bufferingController = StreamController<bool>.broadcast();
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
      const Stream.empty(),
    );

    when(() => mockPlayer.stream).thenReturn(playerStream);
    when(() => mockPlayer.state).thenReturn(mockState);

    when(() => mockState.playing).thenReturn(false);
    when(() => mockState.position).thenReturn(Duration.zero);
    when(() => mockState.duration).thenReturn(const Duration(minutes: 3));
    when(() => mockState.buffer).thenReturn(Duration.zero);
    when(() => mockState.rate).thenReturn(1.0);

    when(() => mockPlayer.pause()).thenAnswer((_) async {});
    when(() => mockPlayer.play()).thenAnswer((_) async {});
    when(() => mockPlayer.stop()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await playingController.close();
    await positionController.close();
    await completedController.close();
    await bufferingController.close();
    await audioDevicesController.close();
    await audioDeviceController.close();
  });

  group('AudioDevice Disconnection Auto-Pause', () {
    test('Initial audio device emission does not trigger pause', () async {
      when(() => mockState.playing).thenReturn(true);

      final handler = AudioPlayerHandler(
        apiService: mockRepo,
        customPlayer: mockPlayer,
      );

      // First emission (startup discovery)
      audioDevicesController.add([
        AudioDevice.auto(),
        const AudioDevice('wasapi/{1}', 'Headphones (Realtek)'),
        const AudioDevice('wasapi/{2}', 'Speakers (Realtek)'),
      ]);

      await Future.delayed(const Duration(milliseconds: 20));
      verifyNever(() => mockPlayer.pause());

      await handler.disposeSubscriptions();
    });

    test('Connecting/Adding a new audio device does not trigger pause', () async {
      when(() => mockState.playing).thenReturn(true);

      final handler = AudioPlayerHandler(
        apiService: mockRepo,
        customPlayer: mockPlayer,
      );

      // First emission
      audioDevicesController.add([
        AudioDevice.auto(),
        const AudioDevice('wasapi/{2}', 'Speakers (Realtek)'),
      ]);
      await Future.delayed(const Duration(milliseconds: 20));

      // Second emission: user plugged in headphones
      audioDevicesController.add([
        AudioDevice.auto(),
        const AudioDevice('wasapi/{2}', 'Speakers (Realtek)'),
        const AudioDevice('wasapi/{1}', 'Headphones (Realtek)'),
      ]);
      await Future.delayed(const Duration(milliseconds: 20));

      verifyNever(() => mockPlayer.pause());

      await handler.disposeSubscriptions();
    });

    test('Disconnecting an audio device while playing triggers auto-pause', () async {
      when(() => mockState.playing).thenReturn(true);

      final handler = AudioPlayerHandler(
        apiService: mockRepo,
        customPlayer: mockPlayer,
      );

      // First emission: headphones connected
      audioDevicesController.add([
        AudioDevice.auto(),
        const AudioDevice('wasapi/{1}', 'Headphones (Realtek)'),
        const AudioDevice('wasapi/{2}', 'Speakers (Realtek)'),
      ]);
      await Future.delayed(const Duration(milliseconds: 20));
      verifyNever(() => mockPlayer.pause());

      // Second emission: headphones unplugged (wasapi/{1} removed)
      audioDevicesController.add([
        AudioDevice.auto(),
        const AudioDevice('wasapi/{2}', 'Speakers (Realtek)'),
      ]);
      await Future.delayed(const Duration(milliseconds: 20));

      verify(() => mockPlayer.pause()).called(1);

      await handler.disposeSubscriptions();
    });

    test('Disconnecting an audio device when already paused does not call pause again', () async {
      when(() => mockState.playing).thenReturn(false);

      final handler = AudioPlayerHandler(
        apiService: mockRepo,
        customPlayer: mockPlayer,
      );

      // First emission
      audioDevicesController.add([
        AudioDevice.auto(),
        const AudioDevice('wasapi/{1}', 'Headphones (Realtek)'),
        const AudioDevice('wasapi/{2}', 'Speakers (Realtek)'),
      ]);
      await Future.delayed(const Duration(milliseconds: 20));

      // Headphones disconnected while paused
      audioDevicesController.add([
        AudioDevice.auto(),
        const AudioDevice('wasapi/{2}', 'Speakers (Realtek)'),
      ]);
      await Future.delayed(const Duration(milliseconds: 20));

      verifyNever(() => mockPlayer.pause());

      await handler.disposeSubscriptions();
    });

    test('Active audio device switching away triggers auto-pause if playing', () async {
      when(() => mockState.playing).thenReturn(true);

      final handler = AudioPlayerHandler(
        apiService: mockRepo,
        customPlayer: mockPlayer,
      );

      // Initial active device
      audioDeviceController.add(const AudioDevice('wasapi/{1}', 'Bluetooth Headset'));
      await Future.delayed(const Duration(milliseconds: 20));
      verifyNever(() => mockPlayer.pause());

      // Active device switches back to auto because bluetooth disconnected
      audioDeviceController.add(AudioDevice.auto());
      await Future.delayed(const Duration(milliseconds: 20));

      verify(() => mockPlayer.pause()).called(1);

      await handler.disposeSubscriptions();
    });
  });
}
