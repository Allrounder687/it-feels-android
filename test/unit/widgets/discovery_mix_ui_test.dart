import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/core/widgets/collection_download_button.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/models/mix_chapter.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/features/connected_music/connected_music_models.dart';
import 'package:it_feels_music/features/discovery/discovery_feed_service.dart';
import 'package:it_feels_music/features/library/collection_download_queue.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/features/new_experience/discovery/new_discovery_feed.dart';
import 'package:it_feels_music/features/new_experience/connected/new_mix_chapters_panel.dart';
import '../services/discovery_and_mix_test.dart' show Repo, track;

class _Audio extends AudioPlayerNotifier {
  @override
  AudioPlayerState build() => const AudioPlayerState();
  @override
  Future<void> playSong(
    Song song, {
    List<Song>? queue,
    int index = 0,
    BuildContext? context,
    String? predefinedStreamUrl,
    int retryCount = 0,
  }) async {
    state = state.copyWith(
      currentSong: song,
      queue: queue,
      currentIndex: index,
      isPlaying: true,
    );
  }

  @override
  Future<void> seek(Duration pos) async {}
}

void main() {
  late Repo repo;
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = Repo();
    locator.registerSingleton<IMusicRepository>(repo);
    when(
      () => repo.searchPlaylists(any(), count: any(named: 'count')),
    ).thenAnswer(
      (call) async => [
        Playlist(
          id: call.positionalArguments.first as String,
          title: 'Curated ${call.positionalArguments.first}',
          songCount: 40,
        ),
      ],
    );
    when(() => repo.searchSongs(any(), count: any(named: 'count'))).thenAnswer(
      (_) async => [track('blue', title: 'Blue Sky', artist: 'Artist Name')],
    );
  });
  tearDown(() => locator.unregister<IMusicRepository>());
  const playlist = RemotePlaylist(
    providerId: 'youtube_music',
    id: 'video:mix',
    videoId: 'mix',
    title: 'One hour music mix',
    url: 'https://music.youtube.com/watch?v=mix',
    requiresAccount: false,
  );
  AccountSnapshot snapshot() => AccountSnapshot(
    complete: true,
    tracks: [
      RemoteTrack('full', track('youtube:mix', title: 'One hour music mix')),
    ],
    chapters: const [
      MixChapter(
        title: 'Artist Name - Blue Sky',
        startSeconds: 0,
        endSeconds: 180,
      ),
      MixChapter(
        title: 'Unmatched creator track',
        startSeconds: 180,
        endSeconds: 360,
      ),
    ],
  );
  for (final width in [320.0, 768.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'discovery and chapter controls fit $width pixels at ${scale}x',
        (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final feed = DiscoveryFeedService(repo);
          await feed.refresh();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                discoveryFeedProvider.overrideWith((ref) => feed),
                audioPlayerProvider.overrideWith(_Audio.new),
                collectionDownloadQueueProvider.overrideWith(
                  (ref) => CollectionDownloadQueue(
                    save: (_) async => true,
                    isSaved: (_) => false,
                  ),
                ),
              ],
              child: MaterialApp(
                theme: ThemeData.dark(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const Scaffold(
                  body: SingleChildScrollView(child: NewDiscoveryFeed()),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Surprise me'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            ProviderScope(
              overrides: [audioPlayerProvider.overrideWith(_Audio.new)],
              child: MaterialApp(
                theme: ThemeData.dark(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: NewMixChaptersPanel(
                        playlist: playlist,
                        snapshot: snapshot(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Build track playlist'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets(
    'video-only mix source falls back to a saved downloadable chapter playlist',
    (tester) async {
      registerFallbackValue(track('fallback'));
      when(
        () => repo.getStreamUrl(any()),
      ).thenAnswer((_) async => 'https://cdn.example/file?mime=video%2Fmp4');
      final downloaded = <Song>[];
      final container = ProviderContainer(
        overrides: [
          audioPlayerProvider.overrideWith(_Audio.new),
          collectionDownloadQueueProvider.overrideWith(
            (ref) => CollectionDownloadQueue(
              save: (song) async {
                downloaded.add(song);
                return true;
              },
              isSaved: (_) => false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: NewMixChaptersPanel(
                  playlist: playlist,
                  snapshot: snapshot(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(downloaded.map((s) => s.id), ['blue']);
      expect(
        container.read(customPlaylistProvider).playlists.single.songs.single.id,
        'blue',
      );
      expect(find.textContaining('1/2 chapters matched'), findsOneWidget);
      await tester.tap(find.text('Build track playlist'));
      await tester.pumpAndSettle();
      expect(container.read(customPlaylistProvider).playlists, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'chapter metadata arriving after the full-mix preview enables safe matching',
    (tester) async {
      registerFallbackValue(track('fallback'));
      final current = ValueNotifier<AccountSnapshot>(
        AccountSnapshot(tracks: snapshot().tracks),
      );
      addTearDown(current.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [audioPlayerProvider.overrideWith(_Audio.new)],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ValueListenableBuilder<AccountSnapshot>(
                  valueListenable: current,
                  builder: (_, value, _) =>
                      NewMixChaptersPanel(playlist: playlist, snapshot: value),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final build = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Build track playlist'),
      );
      expect(build.onPressed, isNull);
      current.value = snapshot();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Build track playlist'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1/2 chapters matched'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
