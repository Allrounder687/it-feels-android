import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/features/player/fullscreen_video_screen.dart';
import 'package:it_feels_music/features/player/video_player_provider.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/main.dart';

class FakeVideoPlayerNotifier extends VideoPlayerNotifier {
  @override
  VideoPlayerState build() => VideoPlayerState();

  @override
  Future<void> initializeVideo(String videoUrl, {Duration? startAt}) async {}

  @override
  Future<void> setQuality(String qualityUrl) async {}

  @override
  void disposeVideo() {}
  
  @override
  void retryMatch() {}

  @override
  Future<void> submitCustomUrl(String customUrl) async {}
}

class FakeAudioPlayerNotifier extends AudioPlayerNotifier {
  @override
  AudioPlayerState build() => AudioPlayerState(isLoading: false);
}

void main() {
  setUpAll(() {
    appProviderContainer = ProviderContainer();
  });

  final mockSong = Song(
    id: 'song1',
    title: 'Test Song',
    artist: 'Test Artist',
    album: 'Test Album',
    duration: 200,
    saavnId: 'saavn1',
    coverArt: 'cover.jpg',
    addedAt: DateTime.now(),
  );

  Widget createWidgetUnderTest() {
    return ProviderScope(
      parent: appProviderContainer,
      overrides: [
        videoPlayerProvider.overrideWith(() => FakeVideoPlayerNotifier()),
        audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier()),
      ],
      child: MaterialApp(
        home: FullscreenVideoScreen(
          currentSong: mockSong,
          onClose: () {},
        ),
      ),
    );
  }

  testWidgets('FullscreenVideoScreen renders correctly', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    expect(find.byType(FullscreenVideoScreen), findsOneWidget);
  });
}
