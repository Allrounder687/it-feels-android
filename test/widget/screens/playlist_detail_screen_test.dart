import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/features/library/playlist_detail_screen.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/core/providers/bottom_ui_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/main.dart';

import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/services/lyrics_service.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/features/social/social_service.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/main.dart';
import 'package:mocktail/mocktail.dart';

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

class FakeAudioPlayerNotifier extends AudioPlayerNotifier {
  @override
  AudioPlayerState build() => AudioPlayerState(isLoading: false);
}

class FakeBottomUiNotifier extends BottomUiNotifier {
  @override
  double build() => 0.0;
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
  final mockPlaylist = Playlist(
    id: 'playlist123',
    title: 'Test Playlist',
    coverArt: 'test.jpg',
    songCount: 10,
    type: 'playlist',
  );

  Widget createWidgetUnderTest(String playlistId) {
    appProviderContainer = ProviderContainer(
      overrides: [
        audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier()),
        bottomUiProvider.overrideWith(() => FakeBottomUiNotifier()),
      ],
    );

    return UncontrolledProviderScope(
      container: appProviderContainer,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/playlist/$playlistId',
          routes: [
            GoRoute(
              path: '/playlist/:id',
              builder: (context, state) => PlaylistDetailScreen(
                playlist: mockPlaylist,
              ),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('PlaylistDetailScreen renders correctly', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest('playlist123'));
    expect(find.byType(PlaylistDetailScreen), findsOneWidget);
  });
}
