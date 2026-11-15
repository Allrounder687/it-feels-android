import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/intelligence/playlists/listening_collection_service.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/features/new_experience/discovery/new_listening_collections.dart';
import 'package:it_feels_music/features/new_experience/see_all/new_see_all_screen.dart';
import 'package:it_feels_music/features/new_experience/widgets/new_action_button.dart';
import 'package:it_feels_music/features/new_experience/widgets/new_card.dart';
import 'package:it_feels_music/features/new_experience/widgets/new_section_header.dart';
import 'package:it_feels_music/features/new_experience/widgets/new_media_tile.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:mocktail/mocktail.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/services/audio_engine_service.dart';
import 'package:it_feels_music/features/library/download_provider.dart';
import 'package:it_feels_music/features/new_experience/player/new_now_playing_screen.dart';
import 'package:it_feels_music/features/new_experience/player/new_equalizer_sheet.dart';
import 'package:it_feels_music/data/services/equalizer_service.dart';

class _Engine extends Mock implements AudioEngineService {}

class _Downloads extends DownloadNotifier {
  @override
  DownloadState build() => const DownloadState();
}

class _Audio extends AudioPlayerNotifier {
  final Song? song;
  _Audio([this.song]);
  @override
  AudioPlayerState build() => AudioPlayerState(currentSong: song);
}

void main() {
  final devices = <String, (Size, TargetPlatform)>{
    'small Android': (const Size(320, 568), TargetPlatform.android),
    'iPhone': (const Size(390, 844), TargetPlatform.iOS),
    'phone landscape': (const Size(844, 390), TargetPlatform.iOS),
    'tablet portrait': (const Size(768, 1024), TargetPlatform.android),
    'iPad landscape': (const Size(1024, 768), TargetPlatform.iOS),
    'Windows': (const Size(1280, 720), TargetPlatform.windows),
    'macOS': (const Size(1440, 900), TargetPlatform.macOS),
    'Linux': (const Size(1920, 1080), TargetPlatform.linux),
  };

  for (final device in devices.entries) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('${device.key} collections at text scale $scale', (
        tester,
      ) async {
        tester.view.reset();
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = device.value.$1;
        addTearDown(tester.view.reset);
        Widget wrap(Widget child) => ProviderScope(
          overrides: [audioPlayerProvider.overrideWith(_Audio.new)],
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(platform: device.value.$2),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                padding: const EdgeInsets.only(top: 24, bottom: 34),
              ),
              child: child!,
            ),
            home: child,
          ),
        );

        await tester.pumpWidget(
          wrap(
            NewCollectionBrowseScreen(
              title: 'Artist mixes',
              artworkSongs: const [],
              collections: ListeningCollection.catalogue([]).take(12).toList(),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(NewCard), findsWidgets);

        await tester.pumpWidget(
          wrap(
            NewSeeAllScreen.playlists(
              title: 'Collections',
              playlists: List.generate(
                12,
                (i) => Playlist(
                  id: 'test$i',
                  title: 'A very long collection title $i',
                  subtitle: 'A long subtitle',
                  songCount: 0,
                  image: '',
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          wrap(
            Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    NewSectionHeader(
                      title: 'Discover something new',
                      onAction: () {},
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        NewActionButton(
                          label: 'Add to Playlist',
                          icon: Icons.playlist_add,
                          onPressed: () {},
                        ),
                        NewActionButton(
                          label: 'Dynamic Mix',
                          icon: Icons.shuffle,
                          onPressed: () {},
                        ),
                      ],
                    ),
                    NewMediaTile(song: Song(id: 'tile', saavnId: 'tile',
                      title: 'A long song title', artist: 'Artist', album: 'Album',
                      duration: 200, coverArt: '', addedAt: DateTime(2020)),
                      onTap: () {}),
                    const NewListeningCollections(songs: []),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('${device.key} full player at text scale $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = device.value.$1;
        addTearDown(tester.view.reset);
        final engine = _Engine();
        when(
          () => engine.positionStream,
        ).thenAnswer((_) => Stream.value(Duration.zero));
        locator.registerSingleton<AudioEngineService>(engine);
        addTearDown(() => locator.unregister<AudioEngineService>());
        final song = Song(
          id: 'test',
          saavnId: 'test',
          title: 'A long title for small phones',
          artist: 'An artist name',
          album: 'An album',
          duration: 200,
          coverArt: '',
          addedAt: DateTime(2020),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              audioPlayerProvider.overrideWith(() => _Audio(song)),
              downloadProvider.overrideWith(_Downloads.new),
            ],
            child: MaterialApp(
              theme: ThemeData.dark().copyWith(platform: device.value.$2),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.only(top: 24, bottom: 34),
                ),
                child: child!,
              ),
              home: const NewNowPlayingScreen(),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -500),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byTooltip('Queue'), findsOneWidget);
        locator.registerSingleton<EqualizerService>(EqualizerService());
        addTearDown(() => locator.unregister<EqualizerService>());
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: NewEqualizerSheet(),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('touch play button is visible and responds without hover', (
    tester,
  ) async {
    var played = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NewCard(
            title: 'Mix',
            customArtwork: const ColoredBox(color: Colors.purple),
            onTap: () {},
            onPlay: () => played = true,
          ),
        ),
      ),
    );
    final opacity = tester.widget<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    expect(opacity.opacity, 1);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    expect(played, isTrue);
  });
}
