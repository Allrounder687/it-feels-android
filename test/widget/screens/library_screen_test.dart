import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/features/library/library_screen.dart';
import 'package:it_feels_music/features/home/home_provider.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/features/library/download_provider.dart';
import 'package:it_feels_music/features/library/custom_playlist_provider.dart';
import 'package:it_feels_music/core/widgets/empty_state_widget.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:go_router/go_router.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/main.dart';

class FakeHomeNotifier extends HomeNotifier {
  final List<Song> _songs;
  FakeHomeNotifier({List<Song> songs = const []}) : _songs = songs;

  @override
  HomeState build() => HomeState(trendingSongs: _songs);
}

class FakeAudioPlayerNotifier extends AudioPlayerNotifier {
  final List<Song> _favorites;
  FakeAudioPlayerNotifier({List<Song> favorites = const []}) : _favorites = favorites;

  @override
  AudioPlayerState build() => AudioPlayerState(isLoading: false, favoriteSongs: _favorites);
}

class FakeDownloadNotifier extends DownloadNotifier {
  final List<Song> _downloads;
  FakeDownloadNotifier({List<Song> downloads = const []}) : _downloads = downloads;

  @override
  DownloadState build() => DownloadState(downloadedSongs: _downloads);
}

class FakeCustomPlaylistNotifier extends CustomPlaylistNotifier {
  @override
  CustomPlaylistState build() => CustomPlaylistState(playlists: []);
}

void main() {
  Widget createWidgetUnderTest({
    List<Song> trending = const [],
    List<Song> favorites = const [],
    List<Song> downloads = const [],
  }) {
    appProviderContainer = ProviderContainer(
      overrides: [
        homeProvider.overrideWith(() => FakeHomeNotifier(songs: trending)),
        audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier(favorites: favorites)),
        downloadProvider.overrideWith(() => FakeDownloadNotifier(downloads: downloads)),
        customPlaylistProvider.overrideWith(() => FakeCustomPlaylistNotifier()),
      ],
    );

    return UncontrolledProviderScope(
      container: appProviderContainer,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/library',
          routes: [
            GoRoute(
              path: '/library',
              builder: (context, state) => const LibraryScreen(),
            ),
            GoRoute(
              path: '/search',
              builder: (context, state) => const Scaffold(body: Text("Search Screen")),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('LibraryScreen renders empty state for FAVORITES tab without cut-off', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest(favorites: []));
    await tester.pumpAndSettle();

    // Tap FAVORITES tab
    await tester.tap(find.text("FAVORITES"));
    await tester.pumpAndSettle();

    // Verify PremiumEmptyState is displayed fully with title, message, and CTA button
    expect(find.byType(PremiumEmptyState), findsOneWidget);
    expect(find.text("It's empty here"), findsOneWidget);
    expect(find.text("No favorite songs added yet"), findsOneWidget);
    expect(find.text("Discover Music"), findsOneWidget);
  });

  testWidgets('LibraryScreen renders empty state for DOWNLOADS tab', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest(downloads: []));
    await tester.pumpAndSettle();

    // Tap DOWNLOADS tab
    await tester.tap(find.text("DOWNLOADS"));
    await tester.pumpAndSettle();

    expect(find.byType(PremiumEmptyState), findsOneWidget);
    expect(find.text("It's empty here"), findsOneWidget);
    expect(find.text("No downloaded tracks for offline playback"), findsOneWidget);
    expect(find.text("Discover Music"), findsOneWidget);
  });

  testWidgets('LibraryScreen renders songs list when tracks are available', (tester) async {
    final testSong = Song(
      id: '1',
      saavnId: '1',
      title: 'Test Song 1',
      artist: 'Test Artist',
      album: 'Test Album',
      duration: 180,
      coverArt: '',
      addedAt: DateTime.now(),
    );

    await tester.pumpWidget(createWidgetUnderTest(
      favorites: [testSong],
    ));
    await tester.pumpAndSettle();

    // Tap FAVORITES tab
    await tester.tap(find.text("FAVORITES"));
    await tester.pumpAndSettle();

    expect(find.text("Test Song 1"), findsOneWidget);
    expect(find.text("Test Artist"), findsOneWidget);
    expect(find.byType(PremiumEmptyState), findsNothing);
  });
}
