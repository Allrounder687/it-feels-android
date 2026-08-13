import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/widgets/animated_play_pause_button.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/main.dart';

import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/services/lyrics_service.dart';
import 'package:it_feels_music/data/services/audio_engine_service.dart';
import 'package:it_feels_music/features/social/listen_together_service.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLyricsService extends Mock implements LyricsService {}
class MockAudioEngineService extends Mock implements AudioEngineService {}
class MockListenTogetherService extends Mock implements ListenTogetherService {}
class MockMusicApiService extends Mock implements MusicApiService {}

class FakeAudioPlayerNotifier extends AudioPlayerNotifier {
  @override
  AudioPlayerState build() => AudioPlayerState(isLoading: false);
}

void main() {
  setUpAll(() {
    locator.registerLazySingleton<LyricsService>(() => MockLyricsService());
    locator.registerLazySingleton<AudioEngineService>(() => MockAudioEngineService());
    locator.registerLazySingleton<ListenTogetherService>(() => MockListenTogetherService());
    locator.registerLazySingleton<MusicApiService>(() => MockMusicApiService());

    appProviderContainer = ProviderContainer(
      overrides: [
        audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier()),
      ],
    );
  });

  tearDownAll(() {
    appProviderContainer.dispose();
    locator.reset();
  });

  group('AnimatedPlayPauseButton', () {
    testWidgets('renders and handles tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: appProviderContainer,
          child: MaterialApp(
            home: Scaffold(
              body: AnimatedPlayPauseButton(
                isPlaying: false,
                onPressed: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      );

      // Verify the widget is in the tree
      expect(find.byType(AnimatedPlayPauseButton), findsOneWidget);

      // Tap the button
      await tester.tap(find.byType(AnimatedPlayPauseButton));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('animates on isPlaying change', (tester) async {
      final key = GlobalKey();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: appProviderContainer,
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  bool playing = false;
                  return AnimatedPlayPauseButton(
                    key: key,
                    isPlaying: playing,
                    onPressed: () {
                      setState(() {
                        playing = !playing;
                      });
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Tap the button to change isPlaying
      await tester.tap(find.byKey(key));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 175)); // Halfway through animation
      await tester.pump(const Duration(milliseconds: 175)); // Finish animation
    });
  });
}
