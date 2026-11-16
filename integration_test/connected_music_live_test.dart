import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/models/cache_models.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/data/services/addon_manager.dart';
import 'package:it_feels_music/features/connected_music/account_browser_gateway.dart';
import 'package:it_feels_music/features/connected_music/connected_music_models.dart';
import 'package:it_feels_music/features/connected_music/connected_music_providers.dart';
import 'package:it_feels_music/services/database_service.dart';

// Live validation must not contend with an open app's database or persist test searches.
class _NoCacheDatabase extends DatabaseService {
  @override
  Future<CachedSearch?> getCachedSearch(String queryKey) async => null;
  @override
  Future<void> saveCachedSearch(CachedSearch cache) async {}
}

/// Opt-in live smoke test. Prints counts/timing/status only, never credentials,
/// account names, playlist titles, or signed media URLs. Media bodies are canceled.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('VERIFY_CONNECTED_LIVE');
  testWidgets(
    'live lightweight YouTube discovery while Flutter continues rendering',
    (tester) async {
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: CircularProgressIndicator())),
        ),
      );
      final timings = <FrameTiming>[];
      void record(List<FrameTiming> frames) => timings.addAll(frames);
      binding.addTimingsCallback(record);
      final gateway = AccountBrowserGateway();
      final watch = Stopwatch()..start();
      try {
        final pages = await gateway
            .discover(accountAddons.first)
            .toList()
            .timeout(const Duration(seconds: 100));
        expect(pages, isNotEmpty);
        expect(pages.last.error, isNull);
        expect(pages.last.complete, true);
        expect(pages.last.playlists, isNotEmpty);
        debugPrint(
          'Live discovery: ${pages.last.playlists.length} cards in ${watch.elapsedMilliseconds}ms; ${timings.length} rendered frames; ${timings.where((f) => f.buildDuration.inMilliseconds > 100).length} builds over 100ms',
        );
        expect(timings.length, greaterThan(5));
      } finally {
        binding.removeTimingsCallback(record);
        gateway.dispose();
        await tester.pumpWidget(const SizedBox());
      }
    },
    skip: !enabled,
  );

  testWidgets(
    'live connected recording resolves to an audio endpoint without downloading its body',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Checking audio source'))),
      );
      if (!locator.isRegistered<DatabaseService>()) {
        locator.registerSingleton<DatabaseService>(_NoCacheDatabase());
      }
      await AddonManager().initialize();
      final container = ProviderContainer();
      container.read(connectedMusicProvider);
      addTearDown(container.dispose);
      final song = Song(
        id: 'youtube:Umqb9KENgmk',
        saavnId: '',
        title: 'Tum Hi Ho',
        artist: 'Arijit Singh',
        album: '',
        duration: 262,
        coverArt: '',
        addedAt: DateTime.now(),
      );
      final url = await MusicRepository()
          .getStreamUrl(song)
          .timeout(const Duration(seconds: 60));
      expect(
        url,
        isNotNull,
        reason:
            'Installed providers must expose either original audio or a verified matching recording',
      );
      final client = http.Client();
      try {
        final response = await client
            .send(
              http.Request('GET', Uri.parse(url!))
                ..headers['Range'] = 'bytes=0-0',
            )
            .timeout(const Duration(seconds: 15));
        await response.stream.listen((_) {}).cancel();
        debugPrint(
          'Live audio probe: status ${response.statusCode}, MIME ${response.headers['content-type']}',
        );
        expect(response.statusCode, anyOf(200, 206));
        expect(response.headers['content-type'], startsWith('audio/'));
      } finally {
        client.close();
      }
    },
    skip: !enabled,
  );
}
