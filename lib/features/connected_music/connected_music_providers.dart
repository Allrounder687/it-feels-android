import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart'
    show audioPlayerProvider;
import 'package:it_feels_music/data/models/song_model.dart';
import 'account_browser_gateway.dart';
import 'connected_music_models.dart';
import 'connected_music_service.dart';

final accountBrowserGatewayProvider = Provider<AccountBrowserGateway>(
  (ref) => AccountBrowserGateway(),
);
final connectedMusicProvider = ChangeNotifierProvider<ConnectedMusicService>((
  ref,
) {
  final service = ConnectedMusicService(
    store: PreferencesAccountStore(),
    gateway: ref.watch(accountBrowserGatewayProvider),
  );
  unawaited(service.initialize().then((_) => service.refreshAll(force: true)));
  final timer = Timer.periodic(
    const Duration(minutes: 15),
    (_) => unawaited(service.refreshAll()),
  );
  ref.onDispose(timer.cancel);
  return service;
});

// Playback keeps in-flight pages alive. Unused playlists are released so reopening
// reads the curator's current contents instead of an indefinitely retained snapshot.
final remotePlaylistProvider = StreamProvider.autoDispose
    .family<AccountSnapshot, RemotePlaylist>((ref, playlist) {
      ref.watch(
        connectedMusicProvider.select((s) => s.generation(playlist.providerId)),
      );
      final service = ref.read(connectedMusicProvider);
      if (playlist.requiresAccount &&
          !service.account(playlist.providerId).linked) {
        return Stream.value(
          const AccountSnapshot(error: 'login_required', complete: true),
        );
      }
      return service.playlist(playlist);
    });

final connectedPlaybackProvider = Provider<ConnectedPlayback>((ref) {
  final controller = ConnectedPlayback(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

/// Appends pages only while the user's queue still belongs to this listening session.
/// Replacing, deleting, shuffling or reordering the queue relinquishes ownership.
class ConnectedPlayback {
  final Ref ref;
  ProviderSubscription<AsyncValue<AccountSnapshot>>? _subscription;
  List<Song> _queued = [];
  int _generation = 0;
  bool _starting = false;
  ConnectedPlayback(this.ref);

  Future<void> play(RemotePlaylist playlist, int index) async {
    final page = ref.read(remotePlaylistProvider(playlist)).valueOrNull;
    if (page == null ||
        page.tracks.isEmpty ||
        index < 0 ||
        index >= page.tracks.length) {
      return;
    }
    final generation = ++_generation;
    _subscription?.close();
    _queued = page.tracks.map((t) => t.song).toList();
    _starting = true;
    _subscription = ref.listen(remotePlaylistProvider(playlist), (_, next) {
      if (!_starting && generation == _generation) {
        _append(next.valueOrNull);
        if (next.hasError) {
          _subscription?.close();
          _subscription = null;
        }
      }
    });
    try {
      await ref
          .read(audioPlayerProvider.notifier)
          .playSong(_queued[index], queue: _queued, index: index);
    } finally {
      if (generation == _generation) {
        _starting = false;
        _append(ref.read(remotePlaylistProvider(playlist)).valueOrNull);
      }
    }
  }

  void _append(AccountSnapshot? page) {
    if (page == null) return;
    if (page.tracks.length <= _queued.length) {
      if (page.complete || page.error != null) {
        _subscription?.close();
        _subscription = null;
      }
      return;
    }
    final state = ref.read(audioPlayerProvider);
    if (!queueMatches(_queued, state.queue) || state.isShuffle) {
      _subscription?.close();
      _subscription = null;
      return;
    }
    final more = page.tracks.skip(_queued.length).map((t) => t.song).toList();
    ref.read(audioPlayerProvider.notifier).appendPlaylistPage(more);
    _queued = [..._queued, ...more];
    if (page.complete || page.error != null) {
      _subscription?.close();
      _subscription = null;
    }
  }

  static bool queueMatches(List<Song> expected, List<Song> actual) {
    if (expected.length != actual.length) return false;
    for (var i = 0; i < expected.length; i++) {
      if (!identical(expected[i], actual[i]) &&
          expected[i].effectiveQueueKey != actual[i].effectiveQueueKey) {
        return false;
      }
    }
    return true;
  }

  void dispose() {
    ++_generation;
    _subscription?.close();
  }
}
