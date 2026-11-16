import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:media_kit/media_kit.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/data/services/audio_player_handler.dart';
import 'package:it_feels_music/data/models/song_model.dart';

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

  setUpAll(() {
    registerFallbackValue(Media('https://example.com/audio.mp3'));
    registerFallbackValue(Duration.zero);
  });

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
    when(() => mockState.volume).thenReturn(100.0);

    when(() => mockPlayer.play()).thenAnswer((_) async {});
    when(() => mockPlayer.pause()).thenAnswer((_) async {});
    when(() => mockPlayer.stop()).thenAnswer((_) async {});
    when(() => mockPlayer.seek(any())).thenAnswer((_) async {});
    when(() => mockPlayer.open(any(), play: any(named: 'play'))).thenAnswer((_) async {});
    when(() => mockPlayer.setVolume(any())).thenAnswer((_) async {});
    when(() => mockPlayer.dispose()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await playingController.close();
    await positionController.close();
    await completedController.close();
    await bufferingController.close();
    await audioDevicesController.close();
    await audioDeviceController.close();
  });

  test('AudioPlayerHandler survives or self-heals if play is called while marked disposed', () async {
    final handler = AudioPlayerHandler(
      apiService: mockRepo,
      customPlayer: mockPlayer,
      customPlayerFactory: () => mockPlayer,
    );
    
    // Simulate an edge-case disposal (e.g. from app detachment)
    await handler.dispose();
    expect(handler.isDisposed, isTrue);

    // Calling play() should self-heal and re-initialize player without staying dead
    await handler.play();
    expect(handler.isDisposed, isFalse);
    expect(handler.player, isNotNull);
  });

  test('AudioPlayerHandler self-heals when playSong is called after disposal', () async {
    final handler = AudioPlayerHandler(
      apiService: mockRepo,
      customPlayer: mockPlayer,
      customPlayerFactory: () => mockPlayer,
    );
    
    await handler.dispose();
    expect(handler.isDisposed, isTrue);

    final testSong = Song(
      id: 'test_123',
      saavnId: 'test_123',
      title: 'Resilience Track',
      artist: 'IT Feels',
      album: 'Obsidian',
      duration: 180,
      streamUrl: 'https://example.com/audio.mp3',
      coverArt: 'https://example.com/art.jpg',
      addedAt: DateTime.now(),
    );

    await handler.playSong(testSong, 'https://example.com/audio.mp3');
    expect(handler.isDisposed, isFalse);
  });
}
