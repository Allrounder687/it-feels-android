import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';

class SmartStorageService {
  static const String _kMaxCacheSizeKey = 'max_cache_size_bytes';
  static const String _kAutoDownloadKey = 'auto_download_favorites';

  // Default max cache size: 1 GB (down from 2GB to preserve storage)
  static const int defaultMaxCacheSizeBytes = 1 * 1024 * 1024 * 1024;

  Future<int> getMaxCacheSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kMaxCacheSizeKey) ?? defaultMaxCacheSizeBytes;
  }

  Future<void> setMaxCacheSize(int bytes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kMaxCacheSizeKey, bytes);
    await enforceCacheLimit();
  }

  Future<bool> getAutoDownloadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAutoDownloadKey) ?? false;
  }

  Future<void> setAutoDownloadFavorites(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoDownloadKey, value);
  }

  Future<int> calculateCacheDirectorySize() async {
    int totalSize = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        tempDir.listSync(recursive: true, followLinks: false).forEach((FileSystemEntity entity) {
          if (entity is File) {
            totalSize += entity.lengthSync();
          }
        });
      }
    } catch (e) {
      debugPrint("Error calculating cache size: $e");
    }
    return totalSize;
  }
  
  Future<int> calculateDownloadsDirectorySize() async {
    int totalSize = 0;
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${docsDir.path}/downloads');
      if (downloadsDir.existsSync()) {
        downloadsDir.listSync(recursive: true, followLinks: false).forEach((FileSystemEntity entity) {
          if (entity is File) {
            totalSize += entity.lengthSync();
          }
        });
      }
    } catch (e) {
      debugPrint("Error calculating downloads size: $e");
    }
    return totalSize;
  }

  Future<void> enforceCacheLimit() async {
    try {
      final currentSize = await calculateCacheDirectorySize();
      final maxSize = await getMaxCacheSize();

      if (currentSize > maxSize) {
        debugPrint("Cache limit exceeded ($currentSize > $maxSize). Evicting old files...");
        final tempDir = await getTemporaryDirectory();
        
        // Get all files in cache
        List<File> cacheFiles = [];
        tempDir.listSync(recursive: true, followLinks: false).forEach((FileSystemEntity entity) {
          if (entity is File) {
            cacheFiles.add(entity);
          }
        });

        // Sort files by last accessed/modified time (oldest first)
        cacheFiles.sort((a, b) {
          final aStat = a.statSync();
          final bStat = b.statSync();
          return aStat.modified.compareTo(bStat.modified);
        });

        int sizeToDelete = currentSize - (maxSize ~/ 2); // Target 50% of max size after cleanup
        int deletedSize = 0;

        for (var file in cacheFiles) {
          if (deletedSize >= sizeToDelete) break;
          try {
            final length = file.lengthSync();
            file.deleteSync();
            deletedSize += length;
          } catch (e) {
            debugPrint("Failed to delete cache file: $e");
          }
        }
        debugPrint("Evicted $deletedSize bytes from cache.");
      }
    } catch (e) {
      debugPrint("Error enforcing cache limit: $e");
    }
  }

  Future<void> clearAllCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        tempDir.listSync(recursive: true, followLinks: false).forEach((FileSystemEntity entity) {
          if (entity is File) {
            entity.deleteSync();
          }
        });
      }
    } catch (e) {
      debugPrint("Error clearing all cache: $e");
    }
  }
}
