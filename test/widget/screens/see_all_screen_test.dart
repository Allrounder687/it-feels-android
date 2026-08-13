import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/features/library/see_all_screen.dart';
import 'package:it_feels_music/features/home/home_provider.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/core/providers/bottom_ui_provider.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:go_router/go_router.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/services/lyrics_service.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/features/social/social_service.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
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
  Widget createWidgetUnderTest(String title, List<Song> songs) {
    appProviderContainer = ProviderContainer(
      overrides: [
        homeProvider.overrideWith(() => FakeHomeNotifier()),
        audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier()),
        bottomUiProvider.overrideWith(() => FakeBottomUiNotifier()),
      ],
    );

    return UncontrolledProviderScope(
      container: appProviderContainer,
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
