import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/features/library/playlist_detail_screen.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/features/library/download_provider.dart';
import 'package:it_feels_music/core/providers/bottom_ui_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/main.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/services/lyrics_service.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/features/social/social_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLyricsService extends Mock implements LyricsService {}
class MockMusicRepository extends Mock implements IMusicRepository {}
class MockSocialService extends Mock implements SocialService {}

class FakeAudioPlayerNotifier extends AudioPlayerNotifier {
  @override
  AudioPlayerState build() => AudioPlayerState(isLoading: false);
}

class FakeBottomUiNotifier extends BottomUiNotifier {
  @override
  double build() => 0.0;
}

class FakeDownloadNotifier extends DownloadNotifier {
  List<Song> batchDownloaded = [];

  @override
  DownloadState build() => DownloadState();

  @override
  Future<void> downloadBatch(List<Song> songs) async {
    batchDownloaded.addAll(songs);
  }
}

void main() {
  late FakeDownloadNotifier fakeDownloadNotifier;

  setUp(() {
    fakeDownloadNotifier = FakeDownloadNotifier();
    if (!locator.isRegistered<LyricsService>()) {
      locator.registerSingleton<LyricsService>(MockLyricsService());
    }
    if (!locator.isRegistered<IMusicRepository>()) {
      locator.registerSingleton<IMusicRepository>(MockMusicRepository());
    }
    if (!locator.isRegistered<SocialService>()) {
      locator.registerSingleton<SocialService>(MockSocialService());
    }
  });

  final testSong = Song(
    id: 'song1',
    saavnId: 's1',
    title: 'Test Song 1',
    artist: 'Test Artist',
    album: 'Test Album',
    duration: 200,
    coverArt: '',
    addedAt: DateTime.now(),
  );

  final mockPlaylist = Playlist(
    id: 'playlist123',
    title: 'Test Playlist',
    coverArt: '',
    songCount: 1,
    type: 'playlist',
    songs: [testSong],
  );

  Widget createWidgetUnderTest(String playlistId) {
    appProviderContainer = ProviderContainer(
      overrides: [
        audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier()),
        bottomUiProvider.overrideWith(() => FakeBottomUiNotifier()),
        downloadProvider.overrideWith(() => fakeDownloadNotifier),
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

  testWidgets('PlaylistDetailScreen renders download button on narrow mobile screen without overflow', (tester) async {
    // Narrow mobile viewport (360x800 logical pixels)
    tester.view.physicalSize = const Size(360 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest('playlist123'));
    await tester.pumpAndSettle();

    expect(find.byType(PlaylistDetailScreen), findsOneWidget);

    // Verify Download Playlist button is rendered
    final downloadBtnFinder = find.byTooltip('Download Playlist');
    expect(downloadBtnFinder, findsOneWidget);

    // Verify that the download button is completely within visible screen bounds
    final downloadRect = tester.getRect(downloadBtnFinder);
    expect(downloadRect.left >= 0, isTrue);
    expect(downloadRect.right <= 360, isTrue);

    // Tap the download button and verify it responds to tap gestures
    await tester.tap(downloadBtnFinder);
    await tester.pump();

    // Verify feedback SnackBar was shown
    expect(find.text("Downloading 1 songs..."), findsOneWidget);
    expect(fakeDownloadNotifier.batchDownloaded.length, 1);
  });
}
