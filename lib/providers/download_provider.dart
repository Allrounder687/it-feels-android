import 'dart:io';
import 'package:flutter/material.dart';
import '../data/models/song_model.dart';
import '../data/services/music_api_service.dart';
import '../services/download_service.dart';
import '../services/storage_service.dart';

class DownloadProvider extends ChangeNotifier {
  final DownloadService downloadService;
  List<Song> _downloadedSongs = [];
  final Map<String, double> _downloadProgressMap = {};
  final Set<String> _downloadingIds = {};

  DownloadProvider({required MusicApiService apiService})
      : downloadService = DownloadService(apiService: apiService) {
    _init();
  }

  List<Song> get downloadedSongs => _downloadedSongs;

  bool isDownloaded(String songId) {
    return _downloadedSongs.any((s) => s.id == songId);
  }

  bool isDownloading(String songId) {
    return _downloadingIds.contains(songId);
  }

  double getProgress(String songId) {
    return _downloadProgressMap[songId] ?? 0.0;
  }

  Future<void> _init() async {
    _downloadedSongs = await StorageService.loadDownloads();
    notifyListeners();
  }

  Future<bool> downloadSong(Song song) async {
    if (isDownloaded(song.id)) return true;
    if (isDownloading(song.id)) return false;

    _downloadingIds.add(song.id);
    _downloadProgressMap[song.id] = 0.0;
    notifyListeners();

    final success = await downloadService.downloadSong(
      song,
      onProgress: (progress) {
        _downloadProgressMap[song.id] = progress;
        notifyListeners();
      },
    );

    _downloadingIds.remove(song.id);
    _downloadProgressMap.remove(song.id);

    if (success) {
      _downloadedSongs = await StorageService.loadDownloads();
    }
    notifyListeners();
    return success;
  }

  Future<void> downloadBatch(List<Song> songs) async {
    for (final song in songs) {
      if (!isDownloaded(song.id)) {
        await downloadSong(song);
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

    _downloadedSongs.removeWhere((s) => s.id == song.id);
    await StorageService.saveDownloads(_downloadedSongs);
    notifyListeners();
  }

  Future<void> clearAllDownloads() async {
    for (final song in _downloadedSongs) {
      try {
        if (song.encryptedMediaUrl != null && song.encryptedMediaUrl!.isNotEmpty) {
          final file = File(song.encryptedMediaUrl!);
          if (await file.exists()) {
            await file.delete();
          }
        }
      } catch (_) {}
    }
    _downloadedSongs.clear();
    await StorageService.saveDownloads(_downloadedSongs);
    notifyListeners();
  }
}
