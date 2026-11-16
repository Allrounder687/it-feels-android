import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/features/connected_music/connected_music_models.dart';
import 'package:it_feels_music/features/connected_music/connected_music_service.dart';

class MemoryStore implements AccountStore {
  final values = <String, String>{};
  Completer<void>? writeGate;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    await writeGate?.future;
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class FakeGateway implements AccountGateway {
  final requests = <String, List<StreamController<AccountSnapshot>>>{};
  int installs = 0, disconnects = 0;
  @override
  Future<void> install(AccountAddon addon) async {
    installs++;
  }

  @override
  Stream<AccountSnapshot> read(AccountAddon addon, {RemotePlaylist? playlist}) {
    final stream = StreamController<AccountSnapshot>();
    (requests[addon.id] ??= []).add(stream);
    return stream.stream;
  }

  StreamController<AccountSnapshot> latest(String id) => requests[id]!.last;
  @override
  Future<void> disconnect(AccountAddon addon) async {
    disconnects++;
  }

  @override
  void dispose() {
    for (final streams in requests.values) {
      for (final s in streams) {
        unawaited(s.close());
      }
    }
  }
}

final youtube = accountAddons.first;
final spotify = accountAddons.last;
RemotePlaylist playlist(String id, [String title = 'Curator mix']) =>
    RemotePlaylist(
      providerId: youtube.id,
      id: id,
      title: title,
      url: '${youtube.origin}/playlist?list=$id',
    );
AccountSnapshot snapshot(
  List<RemotePlaylist> playlists, {
  bool complete = true,
  String name = 'Listener',
}) => AccountSnapshot(
  authenticated: true,
  complete: complete,
  accountName: name,
  playlists: playlists,
);
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late MemoryStore store;
  late FakeGateway gateway;
  late ConnectedMusicService service;
  setUp(() {
    store = MemoryStore();
    gateway = FakeGateway();
    service = ConnectedMusicService(store: store, gateway: gateway);
  });
  tearDown(() => service.dispose());

  Future<void> connect({List<RemotePlaylist> playlists = const []}) async {
    final operation = service.connected(youtube, snapshot([]));
    await flush();
    gateway.latest(youtube.id).add(snapshot(playlists));
    await gateway.latest(youtube.id).close();
    await operation;
  }

  test('a canceled/anonymous login cannot create a connection', () async {
    await expectLater(
      service.connected(youtube, const AccountSnapshot()),
      throwsA(isA<AccountAccessException>()),
    );
    expect(service.hasConnections, false);
    expect(gateway.requests, isEmpty);
  });
  test(
    'connect automatically loads the home feed and persists metadata only',
    () async {
      await connect(playlists: [playlist('one')]);
      expect(service.account(youtube.id).status, ConnectionStatus.connected);
      expect(service.playlists.single.id, 'one');
      final persisted = store.values.values.single;
      expect(persisted, contains('Listener'));
      expect(persisted, isNot(contains('cookie')));
    },
  );
  test(
    'cold start restores a cached feed without blocking on the network',
    () async {
      await connect(playlists: [playlist('one')]);
      final other = ConnectedMusicService(store: store, gateway: FakeGateway());
      await other.initialize();
      expect(other.playlists.single.id, 'one');
      other.dispose();
    },
  );
  test('corrupt cached metadata does not break initialization', () async {
    store.values['connected_music.v1.${youtube.id}'] = '{broken';
    await service.initialize();
    expect(service.playlists, isEmpty);
  });
  test('overlapping refreshes coalesce into one provider request', () async {
    await connect();
    final first = service.refresh(youtube, force: true);
    final second = service.refresh(youtube, force: true);
    await flush();
    expect(gateway.requests[youtube.id]!.length, 2);
    gateway.latest(youtube.id).add(snapshot([playlist('one')]));
    await gateway.latest(youtube.id).close();
    await Future.wait([first, second]);
  });
  test('fresh feed does not repeatedly request the service', () async {
    await connect();
    await service.refresh(youtube);
    expect(gateway.requests[youtube.id]!.length, 1);
  });
  test(
    'successful refresh applies removals, ordering and title changes',
    () async {
      await connect(playlists: [playlist('one'), playlist('two')]);
      final operation = service.refresh(youtube, force: true);
      await flush();
      gateway
          .latest(youtube.id)
          .add(snapshot([playlist('two', 'Updated'), playlist('three')]));
      await gateway.latest(youtube.id).close();
      await operation;
      expect(service.playlists.map((p) => p.id), ['two', 'three']);
      expect(service.playlists.first.title, 'Updated');
    },
  );
  test('duplicate playlist IDs collapse within the same account', () async {
    await connect(playlists: [playlist('one'), playlist('one')]);
    expect(service.playlists, hasLength(1));
  });
  test(
    'network failure retains the cached library and exposes retry state',
    () async {
      await connect(playlists: [playlist('one')]);
      final operation = service.refresh(youtube, force: true);
      await flush();
      gateway.latest(youtube.id).addError(const AccountAccessException());
      await gateway.latest(youtube.id).close();
      await operation;
      expect(service.playlists.single.id, 'one');
      expect(service.account(youtube.id).status, ConnectionStatus.offline);
    },
  );
  test(
    'expired sessions expose reconnect without discarding cached playlists',
    () async {
      await connect(playlists: [playlist('one')]);
      final operation = service.refresh(youtube, force: true);
      await flush();
      gateway
          .latest(youtube.id)
          .addError(const AccountAccessException(needsLogin: true));
      await gateway.latest(youtube.id).close();
      await operation;
      expect(service.account(youtube.id).status, ConnectionStatus.reconnect);
      expect(service.playlists, hasLength(1));
    },
  );
  test('partial refresh does not persist an incomplete replacement', () async {
    await connect(playlists: [playlist('one')]);
    final saved = store.values.values.single;
    final operation = service.refresh(youtube, force: true);
    await flush();
    gateway
        .latest(youtube.id)
        .add(snapshot([playlist('two')], complete: false));
    await gateway.latest(youtube.id).close();
    await operation;
    expect(store.values.values.single, saved);
    expect(service.account(youtube.id).status, ConnectionStatus.offline);
  });
  test(
    'disconnect clears feed and cache; late network responses cannot resurrect them',
    () async {
      await connect(playlists: [playlist('one')]);
      final operation = service.refresh(youtube, force: true);
      await flush();
      await service.disconnect(youtube);
      gateway.latest(youtube.id).add(snapshot([playlist('late')]));
      unawaited(gateway.latest(youtube.id).close());
      await operation;
      expect(service.playlists, isEmpty);
      expect(store.values, isEmpty);
      expect(gateway.disconnects, 1);
    },
  );
  test(
    'disconnect during a pending cache write leaves no account data behind',
    () async {
      await connect();
      store.writeGate = Completer<void>();
      final operation = service.refresh(youtube, force: true);
      await flush();
      gateway.latest(youtube.id).add(snapshot([playlist('late')]));
      unawaited(gateway.latest(youtube.id).close());
      await flush();
      final disconnect = service.disconnect(youtube);
      store.writeGate!.complete();
      await Future.wait([operation, disconnect]);
      expect(store.values, isEmpty);
      expect(service.hasConnections, false);
    },
  );
  test('switching accounts cannot reuse old account metadata', () async {
    await connect(playlists: [playlist('old')]);
    final operation = service.connected(
      youtube,
      snapshot([], name: 'New listener'),
    );
    await flush();
    expect(service.playlists, isEmpty);
    gateway
        .latest(youtube.id)
        .add(snapshot([playlist('new')], name: 'New listener'));
    await gateway.latest(youtube.id).close();
    await operation;
    expect(service.playlists.single.id, 'new');
  });
  test(
    'one unavailable service does not prevent the other from refreshing',
    () async {
      await connect();
      final operation = service.connected(
        spotify,
        const AccountSnapshot(authenticated: true),
      );
      await flush();
      gateway.latest(spotify.id).addError(const AccountAccessException());
      await gateway.latest(spotify.id).close();
      await operation;
      final refresh = service.refreshAll(force: true);
      await flush();
      gateway.latest(youtube.id).add(snapshot([playlist('one')]));
      gateway.latest(spotify.id).addError(const AccountAccessException());
      await Future.wait([
        gateway.latest(youtube.id).close(),
        gateway.latest(spotify.id).close(),
      ]);
      await refresh;
      expect(service.playlists.single.id, 'one');
    },
  );
  test(
    'repeated recordings have independent playlist entry identities',
    () async {
      await connect();
      final events = <AccountSnapshot>[];
      final subscription = service.playlist(playlist('one')).listen(events.add);
      await flush();
      Map<String, dynamic> track(String key) => {
        'entryId': key,
        'id': 'song',
        'title': 'Original',
        'artist': 'Artist',
      };
      gateway
          .latest(youtube.id)
          .add(
            AccountSnapshot.fromJson(youtube.id, {
              'authenticated': true,
              'tracks': [track('a'), track('b')],
            }),
          );
      gateway
          .latest(youtube.id)
          .add(
            AccountSnapshot.fromJson(youtube.id, {
              'authenticated': true,
              'complete': true,
              'tracks': [track('a'), track('b'), track('c')],
            }),
          );
      await gateway.latest(youtube.id).close();
      await flush();
      await subscription.cancel();
      expect(events.last.tracks.map((t) => t.entryId), ['a', 'b', 'c']);
      expect(events.last.tracks.map((t) => t.song.id).toSet(), hasLength(1));
    },
  );
  test(
    'untrusted playlist links and malformed entries cannot enter the feed',
    () {
      final result = AccountSnapshot.fromJson(youtube.id, {
        'playlists': [
          null,
          7,
          {},
          {
            'id': 'x',
            'title': 'Bad',
            'url': 'https://music.youtube.com.evil.example/playlist',
          },
          {'id': 'y', 'title': 'Bad', 'url': 'javascript:alert(1)'},
          playlist('safe').toJson(),
        ],
        'tracks': [
          null,
          {},
          {'id': 'ok', 'title': 'Song', 'duration': 'bad'},
        ],
      });
      expect(result.playlists.single.id, 'safe');
      expect(result.tracks.single.song.duration, 0);
    },
  );
  test('navigation accepts only HTTPS service/auth domains', () {
    expect(
      youtube.allowsNavigation(Uri.parse('https://accounts.google.com/signin')),
      true,
    );
    for (final url in [
      'http://music.youtube.com',
      'https://youtube.com.evil.example',
      'file:///secret',
      'https://user:password@music.youtube.com',
    ]) {
      expect(youtube.allowsNavigation(Uri.parse(url)), false, reason: url);
    }
  });
  test('remote identity is stable across metadata refreshes', () {
    expect(playlist('one'), playlist('one', 'Renamed'));
    expect(playlist('one').hashCode, playlist('one', 'Renamed').hashCode);
  });
  test('metadata serialization contains source provenance', () {
    final data =
        jsonDecode(jsonEncode(playlist('one').toJson()))
            as Map<String, dynamic>;
    expect(RemotePlaylist.fromJson(youtube.id, data).key, '${youtube.id}:one');
  });
}
