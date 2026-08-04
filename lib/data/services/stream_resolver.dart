import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:it_feels_music/data/models/cache_models.dart';
import 'package:it_feels_music/services/database_service.dart';
import 'package:it_feels_music/services/backend_api_service.dart';
import 'package:isar/isar.dart';

class StreamResolver {
  static final StreamResolver _instance = StreamResolver._internal();
  factory StreamResolver() => _instance;
  StreamResolver._internal();

  final Map<String, Map<String, dynamic>> _memoryCache = {};
  final Map<String, Future<Map<String, dynamic>>> _inFlightRequests = {};
  
  /// Get video streams with caching and deduplication
  Future<Map<String, dynamic>> resolveStream(String videoId, {String? query, bool bypassCache = false}) async {
    final cacheKey = '$videoId|${query ?? ""}';

    if (!bypassCache) {
      // 1. Check Memory Cache
      if (_memoryCache.containsKey(cacheKey)) {
        final cached = _memoryCache[cacheKey]!;
        final expiry = cached['expiryTime'] as DateTime?;
        if (expiry != null && DateTime.now().isBefore(expiry)) {
          return cached;
        } else {
          _memoryCache.remove(cacheKey); // Expired
        }
      }

      // 2. Check Disk Cache (Isar)
      try {
        final db = DatabaseService();
        await DatabaseService.ensureInitialized();
        if (db.isar != null && db.isar!.isOpen) {
          final cachedStream = await db.isar!.cachedStreams.filter().videoIdEqualTo(videoId).findFirst();
          if (cachedStream != null) {
            if (!cachedStream.isExpired) {
              final result = {
                'streams': [
                  {
                    'url': cachedStream.resolvedVideoUrl,
                    'quality': cachedStream.quality,
                    'videoOnly': false,
                  }
                ],
                'audioUrl': cachedStream.resolvedAudioUrl,
                'expiryTime': cachedStream.expiryTime,
                'resolvedAt': cachedStream.resolvedAt,
                'resolverVersion': cachedStream.resolverVersion,
                'failureCount': cachedStream.failureCount,
              };
              _memoryCache[cacheKey] = result;
              return result;
            } else {
              // Delete expired from Isar
              await db.isar!.writeTxn(() async {
                await db.isar!.cachedStreams.delete(cachedStream.id);
              });
            }
          }
        }
      } catch (e) {
        debugPrint('[StreamResolver] Disk cache read error: $e');
      }
    }

    // 3. Deduplicate in-flight requests
    if (_inFlightRequests.containsKey(cacheKey) && !bypassCache) {
      return await _inFlightRequests[cacheKey]!;
    }

    // 4. Fetch from BackendApiService
    final future = _fetchAndCache(videoId, query, cacheKey);
    _inFlightRequests[cacheKey] = future;
    
    try {
      final result = await future;
      return result;
    } finally {
      _inFlightRequests.remove(cacheKey);
    }
  }

  Future<Map<String, dynamic>> _fetchAndCache(String videoId, String? query, String cacheKey) async {
    final result = await BackendApiService.getVideoStreams(videoId, query: query, bypassCache: true);
    
    if (result.isNotEmpty && result['streams'] != null && (result['streams'] as List).isNotEmpty) {
      // Set TTL to 10 minutes
      final expiryTime = DateTime.now().add(const Duration(minutes: 10));
      result['expiryTime'] = expiryTime;
      
      _memoryCache[cacheKey] = result;

      // Save to Disk Cache (Isar)
      try {
        final db = DatabaseService();
        await DatabaseService.ensureInitialized();
        if (db.isar != null && db.isar!.isOpen) {
          final streams = result['streams'] as List;
          final bestStream = streams.firstWhere(
            (s) => s['quality'] == '1080p' || s['quality'] == '720p',
            orElse: () => streams.first,
          );
          
          final cachedStream = CachedStream()
            ..videoId = videoId
            ..resolvedVideoUrl = bestStream['url']
            ..resolvedAudioUrl = result['audioUrl'] ?? ''
            ..quality = bestStream['quality'] ?? 'unknown'
            ..expiryTime = expiryTime
            ..resolvedAt = DateTime.now()
            ..resolverVersion = 1
            ..failureCount = 0;

          await db.isar!.writeTxn(() async {
            await db.isar!.cachedStreams.put(cachedStream);
          });
        }
      } catch (e) {
        debugPrint('[StreamResolver] Disk cache write error: $e');
      }
    }
    
    return result;
  }

  void preResolve(String videoId, {String? query}) {
    // Fire and forget
    resolveStream(videoId, query: query).catchError((_) => {});
  }

  void clearCache(String videoId) {
    _memoryCache.removeWhere((key, value) => key.startsWith('$videoId|'));
    _inFlightRequests.removeWhere((key, value) => key.startsWith('$videoId|'));
    
    // Clear from disk
    DatabaseService().isar?.writeTxn(() async {
      await DatabaseService().isar?.cachedStreams.filter().videoIdEqualTo(videoId).deleteAll();
    });
  }

  /// Handle 401/403/410 errors from player by clearing cache and retrying once.
  Future<Map<String, dynamic>> handlePlaybackError(String videoId, {String? query}) async {
    // Check failure count
    final cacheKey = '$videoId|${query ?? ""}';
    int failureCount = 0;
    
    try {
      final db = DatabaseService();
      await DatabaseService.ensureInitialized();
      if (db.isar != null && db.isar!.isOpen) {
        final cachedStream = await db.isar!.cachedStreams.filter().videoIdEqualTo(videoId).findFirst();
        if (cachedStream != null) {
          failureCount = cachedStream.failureCount;
        }
      }
    } catch (_) {}
    
    if (failureCount > 0) {
      throw Exception('Stream URL expired or forbidden. Retry limit reached.');
    }
    
    clearCache(videoId);
    
    final result = await resolveStream(videoId, query: query, bypassCache: true);
    
    // Update failure count
    try {
      final db = DatabaseService();
      if (db.isar != null && db.isar!.isOpen) {
        await db.isar!.writeTxn(() async {
          final cachedStream = await db.isar!.cachedStreams.filter().videoIdEqualTo(videoId).findFirst();
          if (cachedStream != null) {
            cachedStream.failureCount = failureCount + 1;
            await db.isar!.cachedStreams.put(cachedStream);
          }
        });
      }
    } catch (_) {}
    
    return result;
  }
}
