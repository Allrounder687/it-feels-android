import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/features/library/artist_detail_screen.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/core/providers/bottom_ui_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/main.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/services/lyrics_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLyricsService extends Mock implements LyricsService {}

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
  });

  Widget createWidgetUnderTest(String artistId) {
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
          initialLocation: '/artist/$artistId',
          routes: [
            GoRoute(
              path: '/artist/:id',
              builder: (context, state) => ArtistDetailScreen(
                artistName: 'Test Artist',
                artistId: state.pathParameters['id'],
              ),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('ArtistDetailScreen renders correctly', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest('artist123'));
    expect(find.byType(ArtistDetailScreen), findsOneWidget);
  });
}
