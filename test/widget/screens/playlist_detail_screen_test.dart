import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/features/library/playlist_detail_screen.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/core/providers/bottom_ui_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/main.dart';

class FakeAudioPlayerNotifier extends AudioPlayerNotifier {
  @override
  AudioPlayerState build() => AudioPlayerState(isLoading: false);
}

class FakeBottomUiNotifier extends BottomUiNotifier {
  @override
  double build() => 0.0;
}

void main() {
  setUpAll(() {
    appProviderContainer = ProviderContainer();
  });

  Widget createWidgetUnderTest(String playlistId) {
    return ProviderScope(
      parent: appProviderContainer,
      overrides: [
        audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier()),
        bottomUiProvider.overrideWith(() => FakeBottomUiNotifier()),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/playlist/$playlistId',
          routes: [
            GoRoute(
              path: '/playlist/:id',
              builder: (context, state) => PlaylistDetailScreen(
                playlistName: 'Test Playlist',
                playlistId: state.pathParameters['id'],
                isChart: false,
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
