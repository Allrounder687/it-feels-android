import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:it_feels_music/data/models/cache_models.dart';
import 'package:it_feels_music/services/database_service.dart';
import 'package:it_feels_music/services/backend_api_service.dart';
import 'package:isar/isar.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'dart:math';

class StreamResolver {
  static final StreamResolver _instance = StreamResolver._internal();
  factory StreamResolver() => _instance;
  StreamResolver._internal();

  final Map<String, Map<String, dynamic>> _memoryCache = {};
  final Map<String, Future<Map<String, dynamic>>> _inFlightRequests = {};
  
  void _enforceCacheLimit<K, V>(Map<K, V> cache, int maxSize) {
    while (cache.length > maxSize) {
      cache.remove(cache.keys.first);
    }
  }
  
  /// Get video streams with caching and deduplication
  Future<Map<String, dynamic>> resolveStream(String videoId, {String? query, bool bypassCache = false, Song? song, bool isVideoMode = false}) async {
    final cacheKey = '$videoId|${query ?? ""}|$isVideoMode';

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
              _enforceCacheLimit(_memoryCache, 30);
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
    final future = _fetchAndCache(videoId, query, cacheKey, song, isVideoMode);
    _inFlightRequests[cacheKey] = future;
    
    try {
      final result = await future;
      return result;
    } finally {
      _inFlightRequests.remove(cacheKey);
    }
  }

  Future<Map<String, dynamic>> _fetchAndCache(String videoId, String? query, String cacheKey, Song? song, bool isVideoMode) async {
    Map<String, dynamic> result = {};

    if (videoId.startsWith('spotify:')) {
      result = await _resolveSpotifyCascade(videoId, query, song, isVideoMode);
    } else {
      result = await BackendApiService.getVideoStreams(videoId, query: query, bypassCache: true);
    }
    
    if (result.isNotEmpty && result['streams'] != null && (result['streams'] as List).isNotEmpty) {
      // Set TTL to 10 minutes
      final expiryTime = DateTime.now().add(const Duration(minutes: 10));
      result['expiryTime'] = expiryTime;
      
      _memoryCache[cacheKey] = result;
      _enforceCacheLimit(_memoryCache, 30);

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
            ..resolverVersion = 2 // Bumped for Spotify Cascade
            ..failureCount = 0;

          // Store mapped source if available
          if (result['mappedSourceId'] != null) {
            // We can reuse the `quality` field or store it somewhere else, but Isar cache model
            // might need a field for mapped source. For now, we rely on the in-memory cache
            // or re-resolving the query on expiry.
          }

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

  /// Extracts title and artist from query, assuming format "Title Artist" 
  /// (Since we only get query string in resolver, we do best effort or parse it).
  Future<Map<String, dynamic>> _resolveSpotifyCascade(String spotifyId, String? query, Song? song, bool isVideoMode) async {
    if (song == null) {
      // Fallback if no song object provided
      return BackendApiService.getVideoStreams(spotifyId, query: query, bypassCache: true);
    }

    final String title = song.title;
    final String artist = song.artist;
    final int durationMs = song.duration * 1000;

    // STEP 1: Saavn Search Cascade (Bypass if Video Mode)
    if (!isVideoMode) {
      try {
      final saavnApi = MusicApiService();
      final results = await saavnApi.searchSongs('$title $artist', count: 10);
      
      if (results.isNotEmpty) {
        // Scoring
        final cleanTargetTitle = normalizeString(title);
        final targetArtists = artist.toLowerCase().split(',').map((e) => e.trim()).toList();
        
        Song? bestMatch;
        for (final candidate in results) {
          final candidateTitle = normalizeString(candidate.title);
          final candidateDuration = candidate.duration * 1000;
          
          bool titleMatch = candidateTitle == cleanTargetTitle || candidateTitle.contains(cleanTargetTitle) || cleanTargetTitle.contains(candidateTitle);
          
          // Artist Overlap
          final candidateArtists = candidate.artist.toLowerCase().split(',').map((e) => e.trim()).toList();
          bool artistMatch = targetArtists.any((ta) => candidateArtists.any((ca) => ca.contains(ta) || ta.contains(ca)));
          
          // Duration within 15s
          bool durationMatch = durationMs == 0 || (candidateDuration - durationMs).abs() <= 15000;

          if (titleMatch && artistMatch && durationMatch) {
            bestMatch = candidate;
            break; // Accept first strict match
          }
        }

        if (bestMatch != null) {
          debugPrint('[StreamCascade] Saavn match found: ${bestMatch.title}');
          final streamUrl = await saavnApi.getStreamUrl(bestMatch);
          if (streamUrl != null) {
            return {
              'title': bestMatch.title,
              'streams': [
                {'quality': '360p', 'url': streamUrl, 'mimeType': 'audio/mp4', 'videoOnly': false, 'isSaavn': true}
              ],
              'audioUrl': streamUrl,
              'durationMs': bestMatch.duration * 1000,
              'mappedSourceId': 'saavn:${bestMatch.id}',
            };
          }
        }
      }
      } catch (e) {
        debugPrint('[StreamCascade] Saavn fallback failed: $e');
      }
    }

    // STEP 2: YouTube Fallback
    debugPrint('[StreamCascade] Falling back to YouTube for: $title $artist');
    final queryForYoutube = '${song.title} ${song.artist.split(',').first} official music video';
    final ytResult = await BackendApiService.getVideoStreams(spotifyId, query: queryForYoutube, bypassCache: true);
    if (ytResult.isNotEmpty) {
       ytResult['mappedSourceId'] = 'youtube'; // Ideally we'd capture the actual resolved YouTube ID
    }
    return ytResult;
  }

  static String normalizeString(String input) {
    return input.toLowerCase()
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'feat\..*'), '')
        .replaceAll(RegExp(r'ft\..*'), '')
        .replaceAll(RegExp(r'remastered.*'), '')
        .trim();
  }


  void preResolve(String videoId, {String? query, Song? song, bool isVideoMode = false}) {
    // Fire and forget
    resolveStream(videoId, query: query, song: song, isVideoMode: isVideoMode).catchError((_) => <String, dynamic>{});
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
  Future<Map<String, dynamic>> handlePlaybackError(String videoId, {String? query, Song? song}) async {
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
    
    final result = await resolveStream(videoId, query: query, bypassCache: true, song: song);
    
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
