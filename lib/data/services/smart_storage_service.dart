import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<Directory> _getSafeCacheDir() async {
    final tempDir = await getTemporaryDirectory();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final appCacheDir = Directory('${tempDir.path}/it_feels_music_cache');
      if (!appCacheDir.existsSync()) {
        appCacheDir.createSync(recursive: true);
      }
      return appCacheDir;
    }
    return tempDir;
  }

  Future<int> calculateCacheDirectorySize() async {
    int totalSize = 0;
    try {
      final tempDir = await _getSafeCacheDir();
      if (tempDir.existsSync()) {
        await for (var entity in tempDir.list(recursive: true, followLinks: false).handleError((e) {
          // Ignore concurrent file deletion errors
        })) {
          if (entity is File) {
            try {
              totalSize += await entity.length();
            } catch (e) {
              // Ignore
            }
          }
        }
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
        await for (var entity in downloadsDir.list(recursive: true, followLinks: false).handleError((e) {})) {
          if (entity is File) {
            try {
              totalSize += await entity.length();
            } catch (_) {}
          }
        }
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
        final tempDir = await _getSafeCacheDir();
        
        List<File> cacheFiles = [];
        await for (var entity in tempDir.list(recursive: true, followLinks: false).handleError((e) {})) {
          if (entity is File) {
            cacheFiles.add(entity);
          }
        }

        cacheFiles.sort((a, b) {
          try {
            return a.statSync().modified.compareTo(b.statSync().modified);
          } catch (_) {
            return 0;
          }
        });

        int sizeToDelete = currentSize - (maxSize ~/ 2); 
        int deletedSize = 0;

        for (var file in cacheFiles) {
          if (deletedSize >= sizeToDelete) break;
          try {
            final length = file.lengthSync();
            file.deleteSync();
            deletedSize += length;
          } catch (e) {
            // Ignore
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
      final tempDir = await _getSafeCacheDir();
      if (tempDir.existsSync()) {
        await for (var entity in tempDir.list(recursive: true, followLinks: false).handleError((e) {})) {
          if (entity is File) {
            try {
              entity.deleteSync();
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint("Error clearing all cache: $e");
    }
  }
}
