import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'connected_music_models.dart';

abstract interface class AccountStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

abstract interface class AccountPlaylistCacheStore {
  Future<void> clearPlaylistCache(String provider);
}

abstract interface class AccountGateway {
  Future<void> install(AccountAddon addon);
  Stream<AccountSnapshot> read(AccountAddon addon, {RemotePlaylist? playlist});
  Future<void> disconnect(AccountAddon addon);
  void dispose();
}

abstract interface class PublicPlaylistGateway {
  Stream<AccountSnapshot> discover(AccountAddon addon);
}

/// Account-scoped caches contain metadata only. Sessions never enter this store.
class ConnectedMusicService extends ChangeNotifier {
  final AccountStore store;
  final AccountGateway gateway;
  final DateTime Function() now;
  final Map<String, AccountConnection> _accounts = {};
  final Map<String, int> _epochs = {};
  final Map<String, Future<void>> _refreshes = {};
  final Map<String, Future<void>> _storageTasks = {};
  final Map<String, Timer> _retries = {};
  final Map<String, int> _failures = {};
  final Map<String, AccountSnapshot> _playlistMemoryCache = {};
  final Map<String, DateTime> _playlistCachedAt = {};
  final Map<String, _SharedPlaylistRead> _playlistReads = {};
  Future<void>? _initialization;
  bool _disposed = false;
  ConnectedMusicService({
    required this.store,
    required this.gateway,
    DateTime Function()? clock,
  }) : now = clock ?? DateTime.now;

  AccountConnection account(String id) =>
      _accounts[id] ?? const AccountConnection();
  int generation(String id) => _epochs[id] ?? 0;
  Future<void> _storage(String id, Future<void> Function() operation) {
    final previous = _storageTasks[id] ?? Future<void>.value();
    final next = previous.catchError((Object _) {}).then((_) => operation());
    _storageTasks[id] = next;
    return next;
  }

  List<RemotePlaylist> get playlists => [
    for (final addon in accountAddons) ...account(addon.id).playlists,
  ];
  bool get hasConnections => accountAddons.any((a) => account(a.id).linked);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String _cacheKey(String id) => 'connected_music.v1.$id';
  String _playlistCacheKey(String key) => 'connected_music.v1.playlist.$key';

  void _rememberPlaylist(String key, AccountSnapshot snapshot) {
    _playlistMemoryCache.remove(key);
    if (_playlistMemoryCache.length >= 8) {
      final oldest = _playlistMemoryCache.keys.first;
      _playlistMemoryCache.remove(oldest);
      _playlistCachedAt.remove(oldest);
    }
    _playlistMemoryCache[key] = snapshot;
  }

  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    for (final addon in accountAddons) {
      final epoch = _epochs[addon.id] ?? 0;
      try {
        final raw = await store.read(_cacheKey(addon.id));
        if (raw == null || _disposed || (_epochs[addon.id] ?? 0) != epoch) {
          continue;
        }
        final j = jsonDecode(raw) as Map<String, dynamic>;
        final snapshot = AccountSnapshot.fromJson(addon.id, j);
        _accounts[addon.id] = AccountConnection(
          status: ConnectionStatus.connected,
          name: snapshot.accountName,
          playlists: snapshot.playlists,
          updatedAt: DateTime.tryParse(j['updatedAt']?.toString() ?? ''),
        );
      } catch (_) {
        /* Corrupt or unavailable storage must not block the home feed. */
      }
    }
    _notify();
  }

  Future<void> refreshAll({bool force = false}) async {
    await initialize();
    await Future.wait(
      accountAddons
          .where((a) => account(a.id).linked)
          .map((a) => refresh(a, force: force)),
    );
  }

  Future<void> refresh(AccountAddon addon, {bool force = false}) {
    if (_disposed) return Future.value();
    final existing = _refreshes[addon.id];
    if (existing != null) return existing;
    final current = account(addon.id);
    if (!current.linked) return Future.value();
    if (!force &&
        current.status == ConnectionStatus.connected &&
        current.updatedAt != null &&
        now().difference(current.updatedAt!) < const Duration(minutes: 15)) {
      return Future.value();
    }
    final future = _refresh(addon);
    _refreshes[addon.id] = future;
    return future.whenComplete(() {
      if (identical(_refreshes[addon.id], future)) _refreshes.remove(addon.id);
    });
  }

  Future<void> _refresh(AccountAddon addon) async {
    final epoch = _epochs[addon.id] ?? 0;
    final before = account(addon.id);
    bool active() => !_disposed && (_epochs[addon.id] ?? 0) == epoch;
    _accounts[addon.id] = AccountConnection(
      status: ConnectionStatus.refreshing,
      name: before.name,
      playlists: before.playlists,
      updatedAt: before.updatedAt,
    );
    _notify();
    try {
      await gateway.install(addon);
      AccountSnapshot? last;
      await for (final snapshot in gateway.read(addon)) {
        if (!active()) return;
        if (!snapshot.authenticated) {
          if (snapshot.error == 'login_required') {
            throw const AccountAccessException(needsLogin: true);
          }
          continue;
        }
        last = snapshot;
        // Publish incremental results while preserving previously cached shelves until completion.
        final merged = {
          for (final p in before.playlists) p.key: p,
          for (final p in snapshot.playlists) p.key: p,
        };
        _accounts[addon.id] = AccountConnection(
          status: ConnectionStatus.refreshing,
          name: snapshot.accountName.isEmpty
              ? before.name
              : snapshot.accountName,
          playlists: merged.values.toList(),
          updatedAt: before.updatedAt,
        );
        _notify();
      }
      if (!active()) return;
      if (last == null) throw const AccountAccessException(needsLogin: true);
      if (!last.complete || last.error != null) {
        throw const AccountAccessException();
      }
      final unique = {for (final p in last.playlists) p.key: p};
      final name = last.accountName.isEmpty ? before.name : last.accountName;
      final updated = now();
      // Write before exposing success. Disconnect invalidates epochs and deletes this cache.
      await _storage(addon.id, () async {
        if (!active()) return;
        await store.write(
          _cacheKey(addon.id),
          jsonEncode({
            'authenticated': true,
            'accountName': name,
            'updatedAt': updated.toIso8601String(),
            'playlists': unique.values.map((p) => p.toJson()).toList(),
          }),
        );
      });
      if (!active()) return;
      _accounts[addon.id] = AccountConnection(
        status: ConnectionStatus.connected,
        name: name,
        playlists: unique.values.toList(),
        updatedAt: updated,
      );
      _failures.remove(addon.id);
      _retries.remove(addon.id)?.cancel();
    } catch (e) {
      if (!active()) return;
      final current = account(addon.id);
      final needsLogin = e is AccountAccessException && e.needsLogin;
      _accounts[addon.id] = AccountConnection(
        status: needsLogin
            ? ConnectionStatus.reconnect
            : ConnectionStatus.offline,
        name: current.name,
        playlists: current.playlists,
        updatedAt: before.updatedAt,
        message: needsLogin
            ? 'Sign in again to refresh your playlists.'
            : 'Could not refresh. Your saved view is still available.',
      );
      if (!needsLogin) {
        final failures = (_failures[addon.id] ?? 0) + 1;
        _failures[addon.id] = failures;
        _retries.remove(addon.id)?.cancel();
        if (failures <= 4) {
          _retries[addon.id] = Timer(
            Duration(seconds: 30 * (1 << (failures - 1))),
            () {
              if (active()) unawaited(refresh(addon, force: true));
            },
          );
        }
      }
    }
    _notify();
  }

  /// Called only after the login browser has verified an authenticated service page.
  Future<void> connected(AccountAddon addon, AccountSnapshot verified) async {
    if (!verified.authenticated || _disposed) {
      throw const AccountAccessException(needsLogin: true);
    }
    _epochs[addon.id] = (_epochs[addon.id] ?? 0) + 1;
    final epoch = generation(addon.id);
    _playlistMemoryCache.removeWhere(
      (key, _) => key.startsWith('${addon.id}:'),
    );
    _playlistCachedAt.removeWhere((key, _) => key.startsWith('${addon.id}:'));
    _retries.remove(addon.id)?.cancel();
    _failures.remove(addon.id);
    _refreshes.remove(addon.id);
    if (store is AccountPlaylistCacheStore) {
      try {
        await _storage(
          addon.id,
          () =>
              (store as AccountPlaylistCacheStore).clearPlaylistCache(addon.id),
        );
      } catch (_) {
        if (!_disposed && generation(addon.id) == epoch) {
          _accounts[addon.id] = const AccountConnection(
            message: 'Could not prepare this account cache. Please reconnect.',
          );
          _notify();
        }
        return;
      }
      if (_disposed || generation(addon.id) != epoch) return;
    }
    _accounts[addon.id] = AccountConnection(
      status: ConnectionStatus.connected,
      name: verified.accountName,
    );
    _notify();
    try {
      await _storage(addon.id, () async {
        if (generation(addon.id) != epoch || _disposed) return;
        await store.write(
          _cacheKey(addon.id),
          jsonEncode({
            'authenticated': true,
            'accountName': verified.accountName,
            'playlists': <dynamic>[],
          }),
        );
      });
    } catch (_) {
      // The refresh below reports a storage failure without an unhandled login Future.
    }
    if (generation(addon.id) != epoch || _disposed) return;
    await refresh(addon, force: true);
  }

  void invalidatePlaylist(RemotePlaylist playlist) {
    _playlistCachedAt.remove(playlist.key);
  }

  Stream<AccountSnapshot> playlist(RemotePlaylist playlist) => _playlistReads
      .putIfAbsent(
        playlist.key,
        () => _SharedPlaylistRead(
          () => _readPlaylist(playlist),
          () => _playlistReads.remove(playlist.key),
        ),
      )
      .stream;

  Stream<AccountSnapshot> _readPlaylist(RemotePlaylist playlist) async* {
    final addon = accountAddons.firstWhere((a) => a.id == playlist.providerId);
    final epoch = _epochs[addon.id] ?? 0;
    final entries = <String, RemoteTrack>{};

    // 1. Yield in-memory cache immediately if available
    final mem = _playlistMemoryCache[playlist.key];
    if (mem != null) {
      for (final t in mem.tracks) {
        entries[t.entryId] = t;
      }
      yield mem;
      final cachedAt = _playlistCachedAt[playlist.key];
      if (mem.complete &&
          cachedAt != null &&
          now().difference(cachedAt) < const Duration(minutes: 15)) {
        return;
      }
    } else {
      // 2. Yield persistent disk cache if available
      try {
        final raw = await store.read(_playlistCacheKey(playlist.key));
        if (raw != null &&
            raw.isNotEmpty &&
            !_disposed &&
            (_epochs[addon.id] ?? 0) == epoch) {
          final cachedSnapshot = await decodeAccountSnapshot(
            playlist.providerId,
            raw,
          );
          if (_disposed || (_epochs[addon.id] ?? 0) != epoch) return;
          if (cachedSnapshot.complete || cachedSnapshot.tracks.isNotEmpty) {
            for (final t in cachedSnapshot.tracks) {
              entries[t.entryId] = t;
            }
            _rememberPlaylist(playlist.key, cachedSnapshot);
            yield cachedSnapshot;
            final cachedAt = cachedSnapshot.cachedAt;
            if (cachedSnapshot.complete &&
                cachedAt != null &&
                now().difference(cachedAt) < const Duration(minutes: 15)) {
              _playlistCachedAt[playlist.key] = cachedAt;
              return;
            }
          }
        }
      } catch (_) {}
    }

    // 3. Stream live/updated pages from gateway
    var firstLivePage = true;
    await for (final page in gateway.read(addon, playlist: playlist)) {
      if (_disposed || (_epochs[addon.id] ?? 0) != epoch) return;
      if (page.error == 'login_required') {
        throw const AccountAccessException(needsLogin: true);
      }
      if (firstLivePage) {
        entries
            .clear(); // A fresh curator snapshot replaces deleted/reordered cached entries.
        firstLivePage = false;
      }
      for (final t in page.tracks) {
        entries[t.entryId] = t;
      }
      final snapshot = AccountSnapshot(
        authenticated: page.authenticated,
        complete: page.complete,
        tracks: entries.values.toList(),
        error: page.error,
        chapters: page.chapters,
      );
      _rememberPlaylist(playlist.key, snapshot);

      // 4. Save to persistent store upon complete page resolution
      if (page.complete && page.error == null) {
        _playlistCachedAt[playlist.key] = now();
        unawaited(
          _storage(addon.id, () async {
            if (_disposed || (_epochs[addon.id] ?? 0) != epoch) return;
            final encoded = await encodePlaylistSnapshot(snapshot, now());
            if (_disposed || (_epochs[addon.id] ?? 0) != epoch) return;
            await store.write(_playlistCacheKey(playlist.key), encoded);
          }).catchError((Object _) {
            /* A disposable cache write must not crash playback. */
          }),
        );
      }
      yield snapshot;
    }
  }

  Future<void> disconnect(AccountAddon addon) async {
    _retries.remove(addon.id)?.cancel();
    _failures.remove(addon.id);
    _epochs[addon.id] = (_epochs[addon.id] ?? 0) + 1;
    _refreshes.remove(addon.id);
    _accounts.remove(addon.id);
    _playlistMemoryCache.removeWhere((k, _) => k.startsWith('${addon.id}:'));
    _playlistCachedAt.removeWhere((k, _) => k.startsWith('${addon.id}:'));
    _notify();
    try {
      await _storage(addon.id, () => store.delete(_cacheKey(addon.id)));
      if (store is AccountPlaylistCacheStore) {
        await _storage(
          addon.id,
          () =>
              (store as AccountPlaylistCacheStore).clearPlaylistCache(addon.id),
        );
      }
      await gateway.disconnect(addon);
    } catch (_) {
      if (!_disposed) {
        _accounts[addon.id] = const AccountConnection(
          status: ConnectionStatus.reconnect,
          message:
              'Could not finish disconnecting. Please retry disconnecting.',
        );
        _notify();
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _retries.values) {
      timer.cancel();
    }
    gateway.dispose();
    super.dispose();
  }
}

/// All consumers of one playlist share a reader, including a download started
/// while its detail screen is loading. Late subscribers receive the latest page.
class _SharedPlaylistRead {
  final Stream<AccountSnapshot> Function() source;
  final void Function() release;
  final Set<MultiStreamController<AccountSnapshot>> _listeners = {};
  StreamSubscription<AccountSnapshot>? _subscription;
  AccountSnapshot? _latest;
  bool _closed = false;
  _SharedPlaylistRead(this.source, this.release);
  late final Stream<AccountSnapshot> stream = Stream.multi((listener) {
    if (_latest != null) listener.add(_latest!);
    if (_closed) {
      listener.close();
      return;
    }
    _listeners.add(listener);
    listener.onCancel = () {
      _listeners.remove(listener);
      if (_listeners.isEmpty && !_closed) {
        _closed = true;
        release();
        unawaited(_subscription?.cancel());
      }
    };
    _subscription ??= source().listen(
      (page) {
        _latest = page;
        for (final l in _listeners.toList()) {
          l.add(page);
        }
      },
      onError: (Object error, StackTrace stack) {
        for (final l in _listeners.toList()) {
          l.addError(error, stack);
        }
      },
      onDone: () {
        if (_closed) return;
        _closed = true;
        release();
        for (final l in _listeners.toList()) {
          l.close();
        }
        _listeners.clear();
      },
    );
  }, isBroadcast: true);
}
