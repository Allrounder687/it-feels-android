import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/features/player/canvas_service.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

class FakeAudioPlayerNotifier extends AudioPlayerNotifier {
  @override
  AudioPlayerState build() => const AudioPlayerState(isLoading: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummySong = Song(
    id: '1',
    saavnId: 'saavn1',
    title: 'Test Song',
    artist: 'Test Artist',
    album: 'Test Album',
    duration: 200,
    coverArt: 'cover.jpg',
    encryptedMediaUrl: 'url',
    addedAt: DateTime.now(),
  );

  group('CanvasControllerNotifier Tests', () {
    test('initial state is null', () {
      final container = ProviderContainer(
        overrides: [
          audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier()),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(canvasControllerProvider), isNull);
    });

    test('loadCanvasForSong handles failure gracefully without throwing', () async {
      final container = ProviderContainer(
        overrides: [
          audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(canvasControllerProvider.notifier);

      // Since YouTube Explode and VideoPlayer will fail to initialize in a test environment,
      // this method should catch the exception internally and the state should remain null.
      await expectLater(
        notifier.loadCanvasForSong(dummySong),
        completes,
      );

      expect(container.read(canvasControllerProvider), isNull);
    });
  });
}
