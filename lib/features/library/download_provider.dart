import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/services/download_service.dart';
import 'package:it_feels_music/services/storage_service.dart';

@immutable
class DownloadState {
  final List<Song> downloadedSongs;
  final Map<String, double> downloadProgressMap;
  final Set<String> downloadingIds;
  final bool isScanning;
  final bool isRestoring;
  final double restorationProgress;
  final String restorationStatus;

  const DownloadState({
    this.downloadedSongs = const [],
    this.downloadProgressMap = const {},
    this.downloadingIds = const {},
    this.isScanning = false,
    this.isRestoring = false,
    this.restorationProgress = 0.0,
    this.restorationStatus = '',
  });

  int get missingDetailsCount {
    return downloadedSongs.where(DownloadService.isSongMissingDetails).length;
  }

  static String normalizeId(String id) {
    if (id.startsWith('saavn:')) return id.substring(6);
    if (id.startsWith('youtube:')) return id.substring(8);
    return id;
  }

  bool isDownloaded(String songId) {
    if (songId.isEmpty) return false;
    final cleanQuery = normalizeId(songId);
    return downloadedSongs.any((s) {
      if (s.id == songId) return true;
      final cleanSaved = normalizeId(s.id);
      if (cleanSaved == cleanQuery) return true;
      if (s.saavnId.isNotEmpty && (s.saavnId == songId || s.saavnId == cleanQuery)) return true;
      return false;
    });
  }

  bool isDownloading(String songId) {
    if (songId.isEmpty) return false;
    final cleanQuery = normalizeId(songId);
    return downloadingIds.any((id) {
      if (id == songId) return true;
      final cleanId = normalizeId(id);
      return cleanId == cleanQuery;
    });
  }

  double getProgress(String songId) {
    if (songId.isEmpty) return 0.0;
    if (downloadProgressMap.containsKey(songId)) {
      return downloadProgressMap[songId]!;
    }
    final cleanQuery = normalizeId(songId);
    for (final entry in downloadProgressMap.entries) {
      if (normalizeId(entry.key) == cleanQuery) {
        return entry.value;
      }
    }
    return 0.0;
  }

  DownloadState copyWith({
    List<Song>? downloadedSongs,
    Map<String, double>? downloadProgressMap,
    Set<String>? downloadingIds,
    bool? isScanning,
    bool? isRestoring,
    double? restorationProgress,
    String? restorationStatus,
  }) {
    return DownloadState(
      downloadedSongs: downloadedSongs ?? this.downloadedSongs,
      downloadProgressMap: downloadProgressMap ?? this.downloadProgressMap,
      downloadingIds: downloadingIds ?? this.downloadingIds,
      isScanning: isScanning ?? this.isScanning,
      isRestoring: isRestoring ?? this.isRestoring,
      restorationProgress: restorationProgress ?? this.restorationProgress,
      restorationStatus: restorationStatus ?? this.restorationStatus,
    );
  }
}

class DownloadNotifier extends Notifier<DownloadState> {
  late final DownloadService downloadService;

  @override
  DownloadState build() {
    downloadService = DownloadService(apiService: locator<IMusicRepository>());
    _init();
    return const DownloadState();
  }

  Future<void> _init() async {
    final songs = await StorageService.loadDownloads();
    state = state.copyWith(downloadedSongs: songs);
    // Background scan for any downloads from older/debug/other app builds
    unawaited(scanAndSync());
  }

  /// Scans file manager directories across all versions/builds and synchronizes state
  Future<List<Song>> scanAndSync() async {
    state = state.copyWith(isScanning: true);
    try {
      final scanned = await downloadService.scanAllDownloads();
      state = state.copyWith(downloadedSongs: scanned, isScanning: false);
      return scanned;
    } catch (e) {
      debugPrint('[DownloadNotifier] scanAndSync error: $e');
      state = state.copyWith(isScanning: false);
      return state.downloadedSongs;
    }
  }

  /// Restores missing metadata, album artwork, and lyrics from JioSaavn for all downloaded tracks
  Future<int> restoreMissingMetadata() async {
    if (state.isRestoring) return 0;
    state = state.copyWith(
      isRestoring: true,
      restorationProgress: 0.0,
      restorationStatus: 'Starting metadata restoration...',
    );

    try {
      final restoredCount = await downloadService.restoreAllMissingMetadata(
        candidateSongs: state.downloadedSongs,
        onProgress: (current, total, song) {
          final progress = total > 0 ? (current / total) : 0.0;
          state = state.copyWith(
            restorationProgress: progress,
            restorationStatus: 'Restoring ($current/$total): ${song.title.isNotEmpty ? song.title : song.id}',
          );
        },
      );

      final updatedDownloads = await StorageService.loadDownloads();
      state = state.copyWith(
        downloadedSongs: updatedDownloads,
        isRestoring: false,
        restorationProgress: 1.0,
        restorationStatus: 'Restored $restoredCount tracks',
      );
      return restoredCount;
    } catch (e) {
      debugPrint('[DownloadNotifier] restoreMissingMetadata error: $e');
      state = state.copyWith(
        isRestoring: false,
        restorationStatus: 'Error during restoration: $e',
      );
      return 0;
    }
  }

  /// Restores metadata and artwork for a single downloaded song
  Future<bool> restoreSingleSong(Song song) async {
    try {
      final restored = await downloadService.restoreSongMetadata(song);
      if (restored != null) {
        final existing = await StorageService.loadDownloads();
        final updated = existing.map((s) => s.id == song.id ? restored : s).toList();
        await StorageService.saveDownloads(updated);
        state = state.copyWith(downloadedSongs: updated);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[DownloadNotifier] restoreSingleSong error: $e');
      return false;
    }
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
          final parentDir = file.parent;
          await file.delete();

          // If the song is in its own dedicated folder, delete cover, lyrics, and metadata files too
          try {
            final rootPath = await downloadService.getDownloadDirectoryPath();
            if (parentDir.path != rootPath && await parentDir.exists()) {
              final remaining = await parentDir.list().toList();
              final isSongFolder = remaining.isEmpty || remaining.every((f) {
                final lower = f.path.toLowerCase();
                return lower.endsWith('.jpg') ||
                    lower.endsWith('.png') ||
                    lower.endsWith('.lrc') ||
                    lower.endsWith('.txt') ||
                    lower.endsWith('.json');
              });
              if (isSongFolder) {
                await parentDir.delete(recursive: true);
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    final cleanId = DownloadState.normalizeId(song.id);
    final updated = List<Song>.from(state.downloadedSongs)..removeWhere((s) {
      if (s.id == song.id) return true;
      final sClean = DownloadState.normalizeId(s.id);
      if (sClean == cleanId) return true;
      if (s.saavnId.isNotEmpty && (s.saavnId == song.id || s.saavnId == cleanId)) return true;
      return false;
    });
    state = state.copyWith(downloadedSongs: updated);
    await StorageService.saveDownloads(updated);
  }

  Future<void> clearAllDownloads() async {
    for (final song in state.downloadedSongs) {
      try {
        if (song.encryptedMediaUrl != null && song.encryptedMediaUrl!.isNotEmpty) {
          final file = File(song.encryptedMediaUrl!);
          if (await file.exists()) {
            final parentDir = file.parent;
            await file.delete();
            try {
              final rootPath = await downloadService.getDownloadDirectoryPath();
              if (parentDir.path != rootPath && await parentDir.exists()) {
                final remaining = await parentDir.list().toList();
                final isSongFolder = remaining.isEmpty || remaining.every((f) {
                  final lower = f.path.toLowerCase();
                  return lower.endsWith('.jpg') ||
                      lower.endsWith('.png') ||
                      lower.endsWith('.lrc') ||
                      lower.endsWith('.txt') ||
                      lower.endsWith('.json');
                });
                if (isSongFolder) {
                  await parentDir.delete(recursive: true);
                }
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    }
    state = state.copyWith(downloadedSongs: const []);
    await StorageService.saveDownloads(const []);
  }
}

typedef DownloadProvider = DownloadNotifier;
