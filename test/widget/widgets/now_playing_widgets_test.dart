import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/features/player/widgets/now_playing_info.dart';
import 'package:it_feels_music/features/player/widgets/now_playing_art.dart';
import 'package:it_feels_music/features/player/widgets/now_playing_actions.dart';
import 'package:it_feels_music/core/widgets/wavy_seek_bar.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/features/subscription/subscription_provider.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/main.dart';
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

class FakeAudioPlayerNotifier extends AudioPlayerNotifier {
  @override
  AudioPlayerState build() => AudioPlayerState(isLoading: false);
}

class FakeSubscriptionProvider extends ChangeNotifier implements SubscriptionProvider {
  @override
  bool get isPremium => false;
  @override
  bool get isLoading => false;
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

  final emptySong = Song(id: '1', title: 'Test', artist: 'Test', saavnId: '1', album: 'Album', coverArt: 'art.jpg', duration: 200, addedAt: DateTime.now());

  Widget createWidgetUnderTest(Widget child) {
    appProviderContainer = ProviderContainer(
      overrides: [
        audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier()),
        subscriptionProvider.overrideWith((ref) => FakeSubscriptionProvider()),
      ],
    );

    return UncontrolledProviderScope(
      container: appProviderContainer,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(body: child),
            ),
          ],
        ),
      ),
    );
  }

  group('NowPlayingWidgets', () {
    testWidgets('NowPlayingInfo renders', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        NowPlayingInfo(
          currentSong: emptySong,
          isWide: false,
        ),
      ));
      expect(find.byType(NowPlayingInfo), findsOneWidget);
    });

    testWidgets('NowPlayingArt renders', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        NowPlayingArt(
          isVideoMode: false,
          isWide: false,
          artSize: 300,
          currentSong: emptySong,
          isPlaying: false,
          surfaceColor: Colors.black,
          accentColor: Colors.blue,
          onQualityPickerTap: () {},
        ),
      ));
      expect(find.byType(NowPlayingArt), findsOneWidget);
    });

    testWidgets('NowPlayingActions renders', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        NowPlayingActions(
          currentSong: emptySong,
          isFav: false,
          isDown: false,
          isDownloading: false,
          surfaceColor: Colors.black,
          accentColor: Colors.blue,
        ),
      ));
      expect(find.byType(NowPlayingActions), findsOneWidget);
    });

    testWidgets('WavySeekBar renders', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        WavySeekBar(
          position: Duration.zero,
          duration: const Duration(minutes: 3),
          onSeek: (_) {},
        ),
      ));
      expect(find.byType(WavySeekBar), findsOneWidget);
    });
  });
}
