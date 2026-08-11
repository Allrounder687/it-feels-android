import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/services/download_service.dart';
import 'package:it_feels_music/services/storage_service.dart';

@immutable
class DownloadState {
  final List<Song> downloadedSongs;
  final Map<String, double> downloadProgressMap;
  final Set<String> downloadingIds;

  const DownloadState({
    this.downloadedSongs = const [],
    this.downloadProgressMap = const {},
    this.downloadingIds = const {},
  });

  bool isDownloaded(String songId) {
    return downloadedSongs.any((s) => s.id == songId);
  }

  bool isDownloading(String songId) {
    return downloadingIds.contains(songId);
  }

  double getProgress(String songId) {
    return downloadProgressMap[songId] ?? 0.0;
  }

  DownloadState copyWith({
    List<Song>? downloadedSongs,
    Map<String, double>? downloadProgressMap,
    Set<String>? downloadingIds,
  }) {
    return DownloadState(
      downloadedSongs: downloadedSongs ?? this.downloadedSongs,
      downloadProgressMap: downloadProgressMap ?? this.downloadProgressMap,
      downloadingIds: downloadingIds ?? this.downloadingIds,
    );
  }
}

class DownloadNotifier extends Notifier<DownloadState> {
  late final DownloadService downloadService;

  @override
  DownloadState build() {
    downloadService = DownloadService(apiService: locator<MusicApiService>());
    _init();
    return const DownloadState();
  }

  Future<void> _init() async {
    final songs = await StorageService.loadDownloads();
    state = state.copyWith(downloadedSongs: songs);
  }

  Future<bool> downloadSong(Song song) async {
    if (state.isDownloaded(song.id)) return true;
    if (state.isDownloading(song.id)) return false;

    final updatedIds = Set<String>.from(state.downloadingIds)..add(song.id);
    final updatedProgress = Map<String, double>.from(state.downloadProgressMap)..[song.id] = 0.0;

    state = state.copyWith(
      downloadingIds: updatedIds,
      downloadProgressMap: updatedProgress,
    );

    final success = await downloadService.downloadSong(
      song,
      onProgress: (progress) {
        final currentMap = Map<String, double>.from(state.downloadProgressMap)..[song.id] = progress;
        state = state.copyWith(downloadProgressMap: currentMap);
      },
    );

    final finalIds = Set<String>.from(state.downloadingIds)..remove(song.id);
    final finalProgress = Map<String, double>.from(state.downloadProgressMap)..remove(song.id);

    List<Song> finalDownloads = state.downloadedSongs;
    if (success) {
      finalDownloads = await StorageService.loadDownloads();
    }

    state = state.copyWith(
      downloadingIds: finalIds,
      downloadProgressMap: finalProgress,
      downloadedSongs: finalDownloads,
    );

    return success;
  }

  Future<void> downloadBatch(List<Song> songs) async {
    const batchSize = 5;
    for (int i = 0; i < songs.length; i += batchSize) {
      final end = (i + batchSize < songs.length) ? i + batchSize : songs.length;
      final batch = songs.sublist(i, end);
      
      for (final song in batch) {
        if (!state.isDownloaded(song.id)) {
          await downloadSong(song);
        }
      }
      
      // Explicitly yield to the event loop after processing a batch.
      // This allows the Garbage Collector to sweep dead memory and prevents OOM crashes
      // on budget Android devices when downloading massive playlists.
      if (end < songs.length) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }
  }

  Future<void> removeDownload(Song song) async {
    try {
      if (song.encryptedMediaUrl != null && song.encryptedMediaUrl!.isNotEmpty) {
        final file = File(song.encryptedMediaUrl!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (_) {}

    final updated = List<Song>.from(state.downloadedSongs)..removeWhere((s) => s.id == song.id);
    state = state.copyWith(downloadedSongs: updated);
    await StorageService.saveDownloads(updated);
  }

  Future<void> clearAllDownloads() async {
    for (final song in state.downloadedSongs) {
      try {
        if (song.encryptedMediaUrl != null && song.encryptedMediaUrl!.isNotEmpty) {
          final file = File(song.encryptedMediaUrl!);
          if (await file.exists()) {
            await file.delete();
          }
        }
      } catch (_) {}
    }
    state = state.copyWith(downloadedSongs: const []);
    await StorageService.saveDownloads(const []);
  }
}

typedef DownloadProvider = DownloadNotifier;
