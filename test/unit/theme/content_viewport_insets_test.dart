import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/features/new_experience/theme/content_viewport_insets.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/data/models/song_model.dart';

class FakeAudioPlayerNotifier extends AudioPlayerNotifier {
  final Song? testSong;
  FakeAudioPlayerNotifier({this.testSong});

  @override
  AudioPlayerState build() => AudioPlayerState(
        isLoading: false,
        currentSong: testSong,
      );
}

void main() {
  group('ContentViewportInsets Tests', () {
    testWidgets('calculates desktop bottom inset as constant 28.0', (tester) async {
      double? calculatedBottom;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier()),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(1280, 800), // Desktop viewport >= breakpointMedium (1024)
                padding: EdgeInsets.zero,
              ),
              child: Consumer(
                builder: (context, ref, _) {
                  calculatedBottom = ContentViewportInsets.bottom(context, ref);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      expect(calculatedBottom, 28.0);
    });

    testWidgets('calculates mobile bottom inset with nav dock, safe area, and comfort padding (no song)', (tester) async {
      double? calculatedBottom;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier(testSong: null)),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844), // Mobile viewport < breakpointMedium (1024)
                padding: EdgeInsets.only(bottom: 34.0), // iOS/Android gesture bar
              ),
              child: Consumer(
                builder: (context, ref, _) {
                  calculatedBottom = ContentViewportInsets.bottom(context, ref);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      // Expected clearance without playing song:
      // mobileNavDockHeight (68) + systemBottomInset (34) + comfortPadding (20) = 122.0
      expect(calculatedBottom, 68.0 + 34.0 + 20.0);
    });

    testWidgets('calculates mobile bottom inset including mini-player when song is active', (tester) async {
      double? calculatedBottom;

      final testSong = Song(
        id: 'test_active_song',
        saavnId: 'saavn_active',
        title: 'Active Song',
        artist: 'Active Artist',
        album: 'Active Album',
        duration: 210,
        coverArt: 'https://example.com/cover.jpg',
        addedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier(testSong: testSong)),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                padding: EdgeInsets.only(bottom: 34.0),
              ),
              child: Consumer(
                builder: (context, ref, _) {
                  calculatedBottom = ContentViewportInsets.bottom(context, ref);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      // Expected clearance with playing song:
      // mobileNavDockHeight (68) + systemBottomInset (34) + comfortPadding (20) + miniPlayerHeight (74) = 196.0
      expect(calculatedBottom, 68.0 + 34.0 + 20.0 + 74.0);
    });

    testWidgets('sliverBottomSpacer builds a valid SliverToBoxAdapter', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier()),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(400, 800),
                padding: EdgeInsets.only(bottom: 20),
              ),
              child: Consumer(
                builder: (context, ref, _) {
                  return CustomScrollView(
                    slivers: [
                      ContentViewportInsets.sliverBottomSpacer(context, ref),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SliverToBoxAdapter), findsOneWidget);
    });
  });
}
