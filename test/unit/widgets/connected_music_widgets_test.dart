import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/services/audio_engine_service.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart'
    show audioPlayerProvider;
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/connected_music/connected_music_models.dart';
import 'package:it_feels_music/features/connected_music/connected_music_providers.dart';
import 'package:it_feels_music/features/connected_music/connected_music_service.dart';
import 'package:it_feels_music/features/new_experience/connected/new_connected_accounts.dart';
import '../services/connected_music_service_test.dart' show MemoryStore;

class _Gateway implements AccountGateway {
  int reads = 0;
  @override
  Future<void> install(AccountAddon addon) async {}
  @override
  Stream<AccountSnapshot> read(AccountAddon addon, {RemotePlaylist? playlist}) {
    reads++;
    return Stream.value(
      AccountSnapshot(
        authenticated: true,
        complete: true,
        accountName: 'Alex',
        playlists: [
          RemotePlaylist(
            providerId: addon.id,
            id: 'test',
            title: 'Late night discoveries',
            owner: 'Your favorite curator',
            url: '${addon.origin}/playlist?list=test',
          ),
        ],
      ),
    );
  }

  @override
  Future<void> disconnect(AccountAddon addon) async {}
  @override
  void dispose() {}
}

class _Audio extends AudioPlayerNotifier {
  final List<Song> initial;
  _Audio(this.initial);
  @override
  AudioPlayerState build() => AudioPlayerState(queue: initial, currentIndex: 0);
}

class _Engine implements AudioEngineService {
  @override
  Duration get position => Duration.zero;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Song song(String entry) => Song(
  id: 'youtube:same',
  saavnId: '',
  title: 'Original',
  artist: 'Artist',
  album: '',
  duration: 180,
  coverArt: '',
  addedAt: DateTime(2026),
  queueKey: entry,
);

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    locator.registerSingleton<AudioEngineService>(_Engine());
    final fontDirectory = Platform.environment['CONNECTED_FONT_DIR'];
    if (fontDirectory != null) {
      for (final weight in [
        FontWeight.w400,
        FontWeight.w500,
        FontWeight.w700,
        FontWeight.w800,
      ]) {
        for (final family in ['outfit', 'inter']) {
          final variant = weight == FontWeight.w400
              ? 'regular'
              : '${weight.value}';
          final loader = FontLoader(
            '${family == 'outfit' ? 'Outfit' : 'Inter'}_$variant',
          );
          loader.addFont(
            File(
              '$fontDirectory/$family.ttf',
            ).readAsBytes().then((b) => ByteData.sublistView(b)),
          );
          await loader.load();
        }
      }
      final material = Platform.environment['FLUTTER_MATERIAL_FONTS']!;
      for (final entry in {
        'MaterialIcons': 'materialicons-regular.otf',
        'Roboto': 'roboto-regular.ttf',
      }.entries) {
        final loader = FontLoader(entry.key);
        loader.addFont(
          File(
            '$material/${entry.value}',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
        await loader.load();
      }
    }
  });
  tearDownAll(() => locator.unregister<AudioEngineService>());
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });
  for (final size in [
    const Size(320, 568),
    const Size(768, 1024),
    const Size(1440, 1000),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('connected accounts fit ${size.width}px at ${scale}x text', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = ConnectedMusicService(
          store: MemoryStore(),
          gateway: _Gateway(),
        );
        final key = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              connectedMusicProvider.overrideWith((ref) => service),
              audioPlayerProvider.overrideWith(() => _Audio([])),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(useMaterial3: true),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: RepaintBoundary(
                key: key,
                child: const NewConnectedAccountsScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Connect YouTube Music'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Connect YouTube Music'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (size.width == 1440 &&
            scale == 1 &&
            Platform.environment['CAPTURE_CONNECTED_UI'] == '1') {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('build/connected_music_preview.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets(
    'connected feed replaces the invitation with real remote playlists',
    (tester) async {
      final service = ConnectedMusicService(
        store: MemoryStore(),
        gateway: _Gateway(),
      );
      await service.connected(
        accountAddons.first,
        const AccountSnapshot(authenticated: true),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectedMusicProvider.overrideWith((ref) => service),
            audioPlayerProvider.overrideWith(() => _Audio([])),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: SingleChildScrollView(child: NewConnectedMusicFeed()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('From YouTube Music'), findsOneWidget);
      expect(find.text('Late night discoveries'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'reopening a fresh remote playlist uses cache and explicit refresh fetches current contents',
    () async {
      final gateway = _Gateway();
      final service = ConnectedMusicService(
        store: MemoryStore(),
        gateway: gateway,
      );
      await service.connected(
        accountAddons.first,
        const AccountSnapshot(authenticated: true),
      );
      final playlist = service.playlists.single;
      final container = ProviderContainer(
        overrides: [connectedMusicProvider.overrideWith((ref) => service)],
      );
      addTearDown(container.dispose);
      final first = container.listen(
        remotePlaylistProvider(playlist),
        (_, _) {},
      );
      await container.read(remotePlaylistProvider(playlist).future);
      first.close();
      await container.pump();
      final second = container.listen(
        remotePlaylistProvider(playlist),
        (_, _) {},
      );
      await container.read(remotePlaylistProvider(playlist).future);
      expect(gateway.reads, 2);
      second.close();
      await container.pump();
      service.invalidatePlaylist(playlist);
      final third = container.listen(
        remotePlaylistProvider(playlist),
        (_, _) {},
      );
      await container.read(remotePlaylistProvider(playlist).future);
      await container.pump();
      expect(gateway.reads, 3);
      third.close();
    },
  );
  test(
    'playlist continuation preserves repeats and stable queue keys',
    () async {
      final first = song('entry1'), second = song('entry2');
      final container = ProviderContainer(
        overrides: [
          audioPlayerProvider.overrideWith(() => _Audio([first])),
        ],
      );
      addTearDown(container.dispose);
      container.read(audioPlayerProvider.notifier).appendPlaylistPage([second]);
      final queue = container.read(audioPlayerProvider).queue;
      expect(queue, hasLength(2));
      expect(queue.map((s) => s.queueKey).toSet(), hasLength(2));
      expect(ConnectedPlayback.queueMatches([first, second], queue), true);
      expect(
        ConnectedPlayback.queueMatches([first, second], [second, first]),
        false,
      );
      expect(ConnectedPlayback.queueMatches([first, second], [first]), false);
      await Future<void>.delayed(Duration.zero);
    },
  );
}
