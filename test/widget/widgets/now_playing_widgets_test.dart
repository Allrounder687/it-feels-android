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
  final emptySong = Song(id: '1', title: 'Test', artist: 'Test', saavnId: '1', album: 'Album', coverArt: 'art.jpg', duration: 200, addedAt: DateTime.now());

  setUpAll(() {
    appProviderContainer = ProviderContainer();
  });

  Widget createWidgetUnderTest(Widget child) {
    return ProviderScope(
      parent: appProviderContainer,
      overrides: [
        audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier()),
        subscriptionProvider.overrideWith((ref) => FakeSubscriptionProvider()),
      ],
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
          accentColor: Colors.blue,
          onSeekStart: (_) {},
          onSeekEnd: () {},
          onSeekUpdate: (_) {},
        ),
      ));
      expect(find.byType(WavySeekBar), findsOneWidget);
    });
  });
}
