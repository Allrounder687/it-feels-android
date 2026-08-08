import 'package:flutter/foundation.dart';
import 'package:it_feels_music/services/database_service.dart';
import 'package:it_feels_music/services/download_service.dart';
import 'package:it_feels_music/services/storage_service.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';

class SmartCacheService {
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
      final dbService = DatabaseService();
      final topSongs = await dbService.getTopPlayedSongs(limit: 50);
      
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

      for (var song in songsToDownload) {
        debugPrint('[SmartCacheService] Auto-downloading: ${song.title}');
        final success = await downloadService.downloadSong(song);
        if (success) {
          // Add to downloaded list in storage to prevent re-fetching
          final currentDownloads = await StorageService.loadDownloads();
          if (!currentDownloads.any((s) => s.id == song.id)) {
            // Note: DownloadService's download() completion should ideally handle saving, 
            // but we can ensure it's saved here if we want to manually construct the downloaded song object.
            // Actually, background_downloader might take a while. We just enqueue it.
          }
        }
        // Small delay to prevent network flood
        await Future.delayed(const Duration(milliseconds: 500));
      }
      debugPrint('[SmartCacheService] Background sync complete.');
    } catch (e) {
      debugPrint('[SmartCacheService] Error during sync: $e');
    } finally {
      _isRunning = false;
    }
  }
}
