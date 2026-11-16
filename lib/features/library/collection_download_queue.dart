import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:it_feels_music/data/models/song_model.dart';

enum CollectionDownloadPhase {
  queued,
  loading,
  downloading,
  complete,
  partial,
  failed,
  canceled,
}

class CollectionDownloadJob {
  final String title;
  final CollectionDownloadPhase phase;
  final int total, saved, failed;
  const CollectionDownloadJob(
    this.title,
    this.phase, {
    this.total = 0,
    this.saved = 0,
    this.failed = 0,
  });
  bool get busy => {
    CollectionDownloadPhase.queued,
    CollectionDownloadPhase.loading,
    CollectionDownloadPhase.downloading,
  }.contains(phase);
}

/// Serializes collection work, sharing duplicate taps and retaining progress after navigation.
/// The existing download notifier remains responsible for actual media and disk storage.
class CollectionDownloadQueue extends ChangeNotifier {
  final Future<bool> Function(Song) save;
  final bool Function(String) isSaved;
  final Future<void> Function(Song)? prepareRetry;
  final Set<String> _failedIds = {};
  final Map<String, CollectionDownloadJob> _jobs = {};
  final Map<String, Future<void>> _pending = {};
  final Set<String> _canceled = {};
  Future<void> _tail = Future.value();
  bool _disposed = false;
  CollectionDownloadQueue({
    required this.save,
    required this.isSaved,
    this.prepareRetry,
  });
  CollectionDownloadJob? job(String key) => _jobs[key];
  void _set(String key, CollectionDownloadJob job) {
    if (_disposed) return;
    _jobs[key] = job;
    notifyListeners();
  }

  Future<void> start(
    String key,
    String title,
    Future<List<Song>> Function() load,
  ) {
    if (_disposed) return Future.value();
    if (_pending.containsKey(key)) return _pending[key]!;
    _canceled.remove(key);
    _set(key, CollectionDownloadJob(title, CollectionDownloadPhase.queued));
    final task = _tail
        .catchError((Object _) {})
        .then((_) => _run(key, title, load));
    _tail = task;
    _pending[key] = task;
    return task.whenComplete(() => _pending.remove(key));
  }

  Future<void> _run(
    String key,
    String title,
    Future<List<Song>> Function() load,
  ) async {
    if (_disposed || _canceled.contains(key)) return;
    var total = 0, saved = 0, failed = 0;
    try {
      _set(key, CollectionDownloadJob(title, CollectionDownloadPhase.loading));
      final songs = {
        for (final song in await load())
          if (song.id.isNotEmpty && !song.id.startsWith('radio:'))
            song.id: song,
      }.values.toList();
      total = songs.length;
      if (_disposed || _canceled.contains(key)) return;
      if (songs.isEmpty) throw const FormatException('No downloadable tracks');
      for (final song in songs) {
        if (_disposed || _canceled.contains(key)) break;
        _set(
          key,
          CollectionDownloadJob(
            title,
            CollectionDownloadPhase.downloading,
            total: total,
            saved: saved,
            failed: failed,
          ),
        );
        try {
          if (_failedIds.contains(song.id) && !isSaved(song.id)) {
            await prepareRetry?.call(song);
          }
          if (isSaved(song.id) || await save(song)) {
            saved++;
            _failedIds.remove(song.id);
          } else {
            failed++;
            _failedIds.add(song.id);
          }
        } catch (_) {
          failed++;
          _failedIds.add(song.id);
        }
      }
      _set(
        key,
        CollectionDownloadJob(
          title,
          _canceled.contains(key)
              ? CollectionDownloadPhase.canceled
              : failed == 0
              ? CollectionDownloadPhase.complete
              : saved == 0
              ? CollectionDownloadPhase.failed
              : CollectionDownloadPhase.partial,
          total: total,
          saved: saved,
          failed: failed,
        ),
      );
    } catch (_) {
      _set(
        key,
        CollectionDownloadJob(
          title,
          _canceled.contains(key)
              ? CollectionDownloadPhase.canceled
              : CollectionDownloadPhase.failed,
          total: total,
          saved: saved,
          failed: failed,
        ),
      );
    }
  }

  void cancel(String key) {
    _canceled.add(key);
    final current = job(key);
    if (current != null) {
      _set(
        key,
        CollectionDownloadJob(
          current.title,
          CollectionDownloadPhase.canceled,
          total: current.total,
          saved: current.saved,
          failed: current.failed,
        ),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
