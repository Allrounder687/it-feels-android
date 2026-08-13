import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:it_feels_music/features/player/fullscreen_video_screen.dart';
import 'package:it_feels_music/features/player/video_player_provider.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/main.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/services/lyrics_service.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/features/social/social_service.dart';

class FakeVideoPlayerNotifier extends VideoPlayerNotifier {
  @override
  VideoPlayerState build() => VideoPlayerState(isLoading: false);

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

class MockLyricsService extends Mock implements LyricsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockMusicApiService extends Mock implements MusicApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSocialService extends Mock implements SocialService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    if (!locator.isRegistered<LyricsService>()) {
      locator.registerSingleton<LyricsService>(MockLyricsService());
    }
    if (!locator.isRegistered<MusicApiService>()) {
      locator.registerSingleton<MusicApiService>(MockMusicApiService());
    }
    if (!locator.isRegistered<SocialService>()) {
      locator.registerSingleton<SocialService>(MockSocialService());
    }
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
    appProviderContainer = ProviderContainer(
      overrides: [
        videoPlayerProvider.overrideWith(() => FakeVideoPlayerNotifier()),
        audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier()),
      ],
    );

    return UncontrolledProviderScope(
      container: appProviderContainer,
      child: MaterialApp(
        home: FullscreenVideoScreen(
          song: mockSong,
        ),
      ),
    );
  }

  testWidgets('FullscreenVideoScreen renders correctly', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    expect(find.byType(FullscreenVideoScreen), findsOneWidget);
  });
}
