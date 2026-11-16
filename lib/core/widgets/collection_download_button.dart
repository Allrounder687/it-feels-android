import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart'
    show downloadProvider;
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/library/collection_download_queue.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';

final collectionDownloadQueueProvider =
    ChangeNotifierProvider<CollectionDownloadQueue>(
      (ref) => CollectionDownloadQueue(
        save: (song) => ref.read(downloadProvider.notifier).downloadSong(song),
        isSaved: (id) => ref.read(downloadProvider).isDownloaded(id),
      prepareRetry: (song) async { await locator<IMusicRepository>().getStreamUrl(song, bypassCache: true); },
      ),
    );

/// The same control is used by provider, generated, album, artist, and local collections.
class CollectionDownloadButton extends ConsumerWidget {
  final String collectionId, title;
  final List<Song>? songs;
  final Future<List<Song>> Function()? loadSongs;
  final bool iconOnly;
  const CollectionDownloadButton({
    super.key,
    required this.collectionId,
    required this.title,
    this.songs,
    this.loadSongs,
    this.iconOnly = false,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.read(collectionDownloadQueueProvider);
    final job = ref.watch(
      collectionDownloadQueueProvider.select((q) => q.job(collectionId)),
    );
    final busy = job?.busy == true;
    final canDownload = loadSongs != null || (songs?.isNotEmpty ?? false);
    final label = switch (job?.phase) {
      CollectionDownloadPhase.queued => 'Queued · cancel',
      CollectionDownloadPhase.loading => 'Preparing · cancel',
      CollectionDownloadPhase.downloading =>
        '${job!.saved + job.failed}/${job.total} · cancel',
      CollectionDownloadPhase.complete => 'Downloaded · check again',
      CollectionDownloadPhase.partial => 'Retry ${job!.failed} failed',
      CollectionDownloadPhase.failed => 'Retry download',
      CollectionDownloadPhase.canceled => 'Resume download',
      _ => 'Download',
    };
    final icon = busy
        ? Icons.close_rounded
        : job?.phase == CollectionDownloadPhase.complete
        ? Icons.download_done_rounded
        : Icons.download_rounded;
    void start() {
      if (busy) {
        queue.cancel(collectionId);
        return;
      }
      final snapshot = List<Song>.of(songs ?? const []);
      unawaited(
        queue.start(collectionId, title, loadSongs ?? () async => snapshot),
      );
    }

    final tooltip = '$label: $title';
    if (iconOnly) {
      return IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        tooltip: tooltip,
        onPressed: canDownload ? start : null,
        icon: Icon(icon, size: 20),
        visualDensity: VisualDensity.compact,
      );
    }
    return Tooltip(
      message: tooltip,
      child: OutlinedButton.icon(
        onPressed: canDownload ? start : null,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}
