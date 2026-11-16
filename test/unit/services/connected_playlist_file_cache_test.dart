import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/features/connected_music/account_browser_gateway.dart';

void main() {
  late Directory directory;
  late PreferencesAccountStore store;
  const key = 'connected_music.v1.playlist.youtube_music:example';
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp(
      'it_feels_playlist_cache_',
    );
    store = PreferencesAccountStore(playlistDirectory: directory);
  });
  tearDown(() async {
    expect(
      directory.absolute.path,
      startsWith(
        '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}',
      ),
    );
    await directory.delete(recursive: true);
  });
  test(
    'playlist snapshots use files while ordinary account settings keep working',
    () async {
      await store.write(key, '{"tracks":[]}');
      await store.write(
        'connected_music.v1.youtube_music',
        '{"authenticated":true}',
      );
      expect(await store.read(key), '{"tracks":[]}');
      expect((await SharedPreferences.getInstance()).containsKey(key), false);
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          'connected_music.v1.youtube_music',
        ),
        true,
      );
      await store.write(key, '{"tracks":[1]}');
      expect(await store.read(key), '{"tracks":[1]}');
    },
  );
  test(
    'legacy playlist metadata migrates on read and can be deleted',
    () async {
      SharedPreferences.setMockInitialValues({key: '{"legacy":true}'});
      expect(await store.read(key), '{"legacy":true}');
      expect((await SharedPreferences.getInstance()).containsKey(key), false);
      await store.delete(key);
      expect(await store.read(key), isNull);
    },
  );
  test('account cleanup removes only that service', () async {
    const spotify = 'connected_music.v1.playlist.spotify:another';
    await store.write(key, '{"youtube":true}');
    await store.write(spotify, '{"spotify":true}');
    await store.clearPlaylistCache('youtube_music');
    expect(await store.read(key), isNull);
    expect(await store.read(spotify), '{"spotify":true}');
  });
  test(
    'disk cache entries are bounded rather than growing settings indefinitely',
    () async {
      for (var i = 0; i < 35; i++) {
        await store.write('$key$i', '{"tracks":[]}');
      }
      expect(
        await directory.list().where((f) => f.path.endsWith('.json')).length,
        32,
      );
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    },
  );
}
