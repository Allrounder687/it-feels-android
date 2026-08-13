import 'package:flutter/foundation.dart';
import 'package:it_feels_music/services/database_service.dart';
import 'package:it_feels_music/services/download_service.dart';
import 'package:it_feels_music/services/storage_service.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';

class SmartCacheService {
  final DatabaseService _dbService;

  SmartCacheService({DatabaseService? dbService}) : _dbService = dbService ?? DatabaseService();

  bool _isRunning = false;

  /// Trigger a background sync of the top 50 most played songs.
  Future<void> syncTopSongs() async {
    if (_isRunning) return;
    _isRunning = true;

    try {
      final settings = await StorageService.loadSettings();
      final bool enableSmartDownloads = settings['enableSmartDownloads'] ?? true;
      if (!enableSmartDownloads) {
        debugPrint('[SmartCacheService] Smart Downloads is disabled in settings. Aborting sync.');
        return;
      }

      debugPrint('[SmartCacheService] Starting background sync of top songs...');
      final topSongs = await _dbService.getTopPlayedSongs(limit: 50);
      
      if (topSongs.isEmpty) {
        debugPrint('[SmartCacheService] No top songs found to cache.');
        return;
      }

      final downloadedList = await StorageService.loadDownloads();
      final downloadedIds = downloadedList.map((s) => s.id).toSet();

      final songsToDownload = topSongs.where((song) => 
        !downloadedIds.contains(song.id) && 
        !song.id.startsWith('radio:')
      ).toList();

      if (songsToDownload.isEmpty) {
        debugPrint('[SmartCacheService] All top 50 songs are already cached.');
        return;
      }

      debugPrint('[SmartCacheService] Found ${songsToDownload.length} new songs to auto-cache.');
      
      final downloadService = locator<DownloadService>();

      const batchSize = 5;
      for (int i = 0; i < songsToDownload.length; i += batchSize) {
        final end = (i + batchSize < songsToDownload.length) ? i + batchSize : songsToDownload.length;
        final batch = songsToDownload.sublist(i, end);

        for (var song in batch) {
          debugPrint('[SmartCacheService] Auto-downloading: ${song.title}');
          final success = await downloadService.downloadSong(song);
          if (success) {
            final currentDownloads = await StorageService.loadDownloads();
            if (!currentDownloads.any((s) => s.id == song.id)) {
              // Wait for background downloader
            }
          }
        }
        
        // Explicitly yield to the event loop after processing a batch.
        // This gives Dart's Garbage Collector time to flush graphics buffers/memory 
        // before the next batch, completely preventing Out-Of-Memory (OOM) crashes.
        if (end < songsToDownload.length) {
          await Future.delayed(const Duration(milliseconds: 1500));
        }
      }
      debugPrint('[SmartCacheService] Background sync complete.');
    } catch (e) {
      debugPrint('[SmartCacheService] Error during sync: $e');
    } finally {
      _isRunning = false;
    }
  }
}
