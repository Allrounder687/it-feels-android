import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'connected_music_models.dart';

abstract interface class AccountStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
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
    _retries.remove(addon.id)?.cancel();
    _failures.remove(addon.id);
    _refreshes.remove(addon.id);
    _accounts[addon.id] = AccountConnection(
      status: ConnectionStatus.connected,
      name: verified.accountName,
    );
    _notify();
    final epoch = generation(addon.id);
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

  Stream<AccountSnapshot> playlist(RemotePlaylist playlist) async* {
    final addon = accountAddons.firstWhere((a) => a.id == playlist.providerId);
    final epoch = _epochs[addon.id] ?? 0;
    final entries = <String, RemoteTrack>{};
    await for (final page in gateway.read(addon, playlist: playlist)) {
      if (_disposed || (_epochs[addon.id] ?? 0) != epoch) return;
      if (page.error == 'login_required') {
        throw const AccountAccessException(needsLogin: true);
      }
      for (final t in page.tracks) {
        entries[t.entryId] = t;
      }
      yield AccountSnapshot(
        authenticated: page.authenticated,
        complete: page.complete,
        tracks: entries.values.toList(),
        error: page.error,
        chapters: page.chapters,
      );
    }
  }

  Future<void> disconnect(AccountAddon addon) async {
    _retries.remove(addon.id)?.cancel();
    _failures.remove(addon.id);
    _epochs[addon.id] = (_epochs[addon.id] ?? 0) + 1;
    _refreshes.remove(addon.id);
    _accounts.remove(addon.id);
    _notify();
    try {
      await _storage(addon.id, () => store.delete(_cacheKey(addon.id)));
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
