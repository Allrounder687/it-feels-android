import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/features/library/see_all_screen.dart';
import 'package:it_feels_music/features/home/home_provider.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/core/providers/bottom_ui_provider.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:go_router/go_router.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/main.dart';

class FakeHomeNotifier extends HomeNotifier {
  @override
  HomeState build() => HomeState();
  
  @override
  Future<void> loadHomeData({bool refresh = false}) async {}
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
  setUpAll(() {
    appProviderContainer = ProviderContainer();
  });

  Widget createWidgetUnderTest(String title, List<Song> songs) {
    return ProviderScope(
      parent: appProviderContainer,
      overrides: [
        homeProvider.overrideWith(() => FakeHomeNotifier()),
        audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier()),
        bottomUiProvider.overrideWith(() => FakeBottomUiNotifier()),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/see_all',
          routes: [
            GoRoute(
              path: '/see_all',
              builder: (context, state) => SeeAllSongsScreen(
                title: title,
                songs: songs,
              ),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('SeeAllSongsScreen renders empty state', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest('Trending', []));
    expect(find.byType(SeeAllSongsScreen), findsOneWidget);
  });
}
