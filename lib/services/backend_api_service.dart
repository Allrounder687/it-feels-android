import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/utils/des_decryptor.dart';

class BackendApiService {
  // Configurable proxy base URL (defaults to user's live Cloudflare Worker URL)
  static String baseUrl = (dotenv.isInitialized ? dotenv.env['PROXY_BASE_URL'] : null) ?? 'https://it-feels-proxy.cleverfox687.workers.dev'; 
  static bool useProxyBackend = true; // Toggle to switch between direct & proxy mode
  static final Map<String, Map<String, dynamic>> _videoStreamCache = {};
  static final YoutubeExplode _yt = YoutubeExplode();
  @visibleForTesting
  static http.Client httpClient = http.Client();


  /// Fetch smart edge recommendations for a song/artist
  static Future<List<Song>> fetchRecommendations({String? songId, String? artist}) async {
    if (!useProxyBackend) return [];
    try {
      final uri = Uri.parse('$baseUrl/api/v1/recommendations').replace(queryParameters: {
        if (songId != null) 'songId': songId,
        if (artist != null) 'artist': artist,
      });

      final response = await httpClient.get(uri, headers: _proxyHeaders).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['recommendations'] is List) {
          final List recs = data['recommendations'];
          return recs.map((item) => _songFromProxyJson(item)).toList();
        }
      }
    } catch (e) {
      debugPrint('[BackendApiService] Recommendations fetch failed: $e');
    }
    return [];
  }

  /// Fetch cached artist details and top tracks from Cloudflare Edge
  static Future<List<Song>> fetchArtistDetails(String artist) async {
    if (!useProxyBackend) return [];
    try {
      final uri = Uri.parse('$baseUrl/api/v1/artist/details').replace(queryParameters: {
        'artist': artist,
      });

      final response = await httpClient.get(uri, headers: _proxyHeaders).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['topTracks'] is List) {
          final List tracks = data['topTracks'];
          return tracks.map((item) => _songFromProxyJson(item)).toList();
        }
      }
    } catch (e) {
      debugPrint('[BackendApiService] Artist details fetch failed: $e');
    }
    return [];
  }

  static String cleanSearchQuery(String title, String artist) {
    final cleanTitle = title.replaceAll(RegExp(r'\s*\([^)]*\)'), '').replaceAll(RegExp(r'\s*\[[^\]]*\]'), '').trim();
    final mainArtist = artist.split(',').first.trim();
    return '$cleanTitle $mainArtist official music video'.trim();
  }

  static Map<String, String> get _proxyHeaders => {
    'X-Feels-Secret': (dotenv.isInitialized ? dotenv.env['API_SECRET'] : null) ?? 'development_secret_123',
  };


  static Future<List<Song>> searchNativeCatalog(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'offline_native_search_${query.toLowerCase()}';
    
    try {
      final uri = Uri.parse('$baseUrl/api/v1/native/search').replace(queryParameters: {'query': query});
      final response = await httpClient.get(uri, headers: _proxyHeaders).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        prefs.setString(cacheKey, response.body);
        final data = await compute(jsonDecode, response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['results'] is List) {
          final List results = data['results'];
          return results.map((item) => _songFromProxyJson(item)).toList();
        }
      }
    } catch (e) {
      debugPrint('[BackendApiService] Native catalog search network error, falling back to offline cache: $e');
    }
    
    // Offline Fallback
    final cachedData = prefs.getString(cacheKey);
    if (cachedData != null) {
      debugPrint('[BackendApiService] Loaded Search Results from Offline Device Cache!');
      final data = await compute(jsonDecode, cachedData) as Map<String, dynamic>;
      if (data['success'] == true && data['results'] is List) {
        final List results = data['results'];
        return results.map((item) => _songFromProxyJson(item)).toList();
      }
    }
    
    return search(query); // Fallback to standard multi-source search
  }

  static Future<Map<String, dynamic>?> fetchNativeHomeFeed() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'offline_native_home_feed';
    
    try {
      final uri = Uri.parse('$baseUrl/api/v1/native/home');
      final response = await httpClient.get(uri, headers: _proxyHeaders).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        prefs.setString(cacheKey, response.body);
        return await compute(jsonDecode, response.body) as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('[BackendApiService] Native home feed network error, falling back to offline cache: $e');
    }
    
    // Offline Fallback
    final cachedData = prefs.getString(cacheKey);
    if (cachedData != null) {
      debugPrint('[BackendApiService] Loaded Home Feed from Offline Device Cache!');
      return await compute(jsonDecode, cachedData) as Map<String, dynamic>?;
    }
    return null;
  }

  /// Search tracks across multi-source backend proxy
  static Future<List<Song>> search(String query, {int page = 1, int limit = 20}) async {
    if (!useProxyBackend) {
      // Direct client fallback
      return _directSaavnSearch(query, page: page, limit: limit);
    }

    try {
      final uri = Uri.parse('$baseUrl/api/v1/search').replace(queryParameters: {
        'query': query,
        'page': page.toString(),
        'limit': limit.toString(),
        'provider': 'saavn',
      });

      final response = await httpClient.get(uri, headers: _proxyHeaders).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['results'] is List) {
          final List results = data['results'];
          return results.map((item) => _songFromProxyJson(item)).toList();
        }
      }
    } catch (e) {
      // Fallback on network timeout/error
    }

    return _directSaavnSearch(query, page: page, limit: limit);
  }

  /// Resolve streamable URL for a song
  static Future<String?> getStreamUrl(Song song) async {
    if (song.streamUrl != null && song.streamUrl!.isNotEmpty) {
      return song.streamUrl;
    }

    if (!useProxyBackend) {
      if (song.encryptedMediaUrl != null) {
        return DesDecryptor.decrypt(song.encryptedMediaUrl!);
      }
      return null;
    }

    try {
      final Uri uri;
      if (song.encryptedMediaUrl != null && song.encryptedMediaUrl!.isNotEmpty) {
        uri = Uri.parse('$baseUrl/api/v1/stream').replace(queryParameters: {
          'encryptedUrl': song.encryptedMediaUrl!,
        });
      } else {
        uri = Uri.parse('$baseUrl/api/v1/stream').replace(queryParameters: {
          'id': song.id,
          'title': song.title,
          'artist': song.artist,
        });
      }

      final response = await httpClient.get(uri, headers: _proxyHeaders).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['streamUrl'] != null) {
          return data['streamUrl'] as String;
        }
      }
    } catch (e) {
      // Fallback to local decryption
    }

    if (song.encryptedMediaUrl != null) {
      return DesDecryptor.decrypt(song.encryptedMediaUrl!);
    }
    return null;
  }

  /// Fetch synced or plain lyrics via Proxy/LrcLib
  static Future<Map<String, String>?> getLyrics(String track, String artist, {String? album, int? duration}) async {
    if (!useProxyBackend) return null;

    try {
      final uri = Uri.parse('$baseUrl/api/v1/lyrics').replace(queryParameters: {
        'track': track,
        'artist': artist,
        if (album != null) 'album': album,
        if (duration != null && duration > 0) 'duration': duration.toString(),
      });

      final response = await httpClient.get(uri, headers: _proxyHeaders).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['lyrics'] != null) {
          final lyrics = data['lyrics'];
          return {
            'plain': lyrics['plainLyrics'] ?? '',
            'synced': lyrics['syncedLyrics'] ?? '',
            'source': lyrics['source'] ?? 'proxy',
          };
        }
      }
    } catch (e) {
      // Return null on failure
    }
    return null;
  }

  /// AI Edge Action Proxy
  static Future<Map<String, dynamic>?> performAiAction({
    required String provider,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/ai/action');
      final response = await httpClient.post(
        uri,
        headers: {..._proxyHeaders, 'Content-Type': 'application/json'},
        body: json.encode({
          'provider': provider,
          'action': action,
          'payload': payload,
        }),
      ).timeout(const Duration(seconds: 25));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('[BackendApiService] AI Action Error: $e');
    }
    return null;
  }

  /// Welcome Email (Resend)
  static Future<bool> sendWelcomeEmail(String email) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/email/welcome');
      final response = await httpClient.post(
        uri,
        headers: {..._proxyHeaders, 'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      ).timeout(const Duration(seconds: 15));
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[BackendApiService] Welcome Email Error: $e');
      return false;
    }
  }

  /// Telemetry Play Event Tracker
  static Future<void> sendTelemetryPlay(Song song) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/telemetry/play');
      await httpClient.post(
        uri,
        headers: {..._proxyHeaders, 'Content-Type': 'application/json'},
        body: json.encode({
          'songId': song.id,
          'title': song.title,
          'artist': song.artist,
          'coverArt': song.coverArt,
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[BackendApiService] Telemetry Play Error: $e');
    }
  }

  /// Preload MP4 video stream data for a song
  static Future<void> preloadVideoStreams(Song song) async {
    if (song.id.isEmpty) return;
    final videoId = song.id.contains(':') ? song.id : 'search:${song.id}';
    final query = cleanSearchQuery(song.title, song.artist);
    final cacheKey = '$videoId|$query';
    if (_videoStreamCache.containsKey(cacheKey)) return;

    try {
      final result = await getVideoStreams(videoId, query: query);
      if (result.isNotEmpty && result['streams'] != null && (result['streams'] as List).isNotEmpty) {
        _videoStreamCache[cacheKey] = result;
      }
    } catch (_) {}
  }

  /// Clear cached streams for a specific video ID
  static void clearVideoStreamCache(String videoId) {
    _videoStreamCache.removeWhere((key, value) => key.startsWith('$videoId|'));
  }

  /// Get Video Streams
  static Future<Map<String, dynamic>> getVideoStreams(String videoId, {String? query, bool bypassCache = false}) async {
    final cacheKey = '$videoId|${query ?? ""}';
    if (!bypassCache && _videoStreamCache.containsKey(cacheKey)) {
      return _videoStreamCache[cacheKey]!;
    }

    debugPrint('[BackendApiService] getVideoStreams called with videoId=$videoId, query=$query');
    String actualVideoId = videoId;
    
    // Client-side resolution for Saavn searches
    String cleanId = actualVideoId.contains(':') ? actualVideoId.split(':').last : actualVideoId;
    if (actualVideoId.startsWith('search:') || (query != null && query.isNotEmpty && cleanId.length != 11)) {
      try {
        final searchQuery = query ?? actualVideoId.replaceFirst('search:', '');
        final searchResults = await _yt.search.search(searchQuery);
        if (searchResults.isNotEmpty) {
          actualVideoId = 'youtube:${searchResults.first.id.value}';
        }
      } catch (e) {
        debugPrint('[BackendApiService] Client-side search resolution failed: $e');
      }
    }

    try {
      // 1. FAST PATH: If we have the 4K yt-dlp Render proxy configured, try it first.
      if (ytDlpBackendUrl.isNotEmpty) {
        final ytDlpData = await _fetchFromYtDlpBackend(actualVideoId);
        if (ytDlpData['streams'] != null && (ytDlpData['streams'] as List).isNotEmpty) {
          debugPrint('[BackendApiService] Successfully fetched streams directly from Render yt-dlp proxy!');
          _videoStreamCache[cacheKey] = ytDlpData;
          return ytDlpData;
        }
      }

      // 2. PIPED API FAST FAILOVER: High-speed, zero-cost public Piped instances with auto-failover
      final updatedCleanId = actualVideoId.contains(':') ? actualVideoId.split(':').last : actualVideoId;
      final pipedData = await _fetchFromPipedApi(updatedCleanId);
      if (pipedData['streams'] != null && (pipedData['streams'] as List).isNotEmpty) {
        debugPrint('[BackendApiService] Successfully fetched streams from Piped API network!');
        _videoStreamCache[cacheKey] = pipedData;
        return pipedData;
      }

      // 3. CLOUDFLARE WORKER API
      final queryParams = <String, String>{};
      if (actualVideoId.isNotEmpty && !actualVideoId.startsWith('search:')) {
        queryParams['id'] = actualVideoId;
      }
      if (query != null && query.isNotEmpty) {
        queryParams['query'] = query;
      }
      if (bypassCache) {
        queryParams['bypassCache'] = 'true';
      }

      final uri = Uri.parse('$baseUrl/api/v1/video').replace(queryParameters: queryParams);
      final response = await httpClient.get(uri, headers: _proxyHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List streamsList = data['streams'] ?? [];
        if (streamsList.isNotEmpty) {
          final res = {
            'title': data['title'] ?? 'Music Video',
            'streams': streamsList,
            'audioUrl': data['audioUrl'] ?? '',
          };
          _videoStreamCache[cacheKey] = res;
          return res;
        }
      }
    } catch (e) {
      debugPrint('[BackendApiService] getVideoStreams error: $e');
    }
    
    // 4. Direct fallback
    final fallbackRes = await _directYoutubeExplodeStreamFallback(videoId, query: query);
    if (fallbackRes.isNotEmpty && fallbackRes['streams'] != null && (fallbackRes['streams'] as List).isNotEmpty) {
      _videoStreamCache[cacheKey] = fallbackRes;
    }
    return fallbackRes;
  }

  // IMPORTANT: Paste your Render URL here once it's deployed (e.g. 'https://it-feels-yt-proxy.onrender.com')
  static String? _testYtDlpUrl;
  static String get ytDlpBackendUrl => _testYtDlpUrl ?? (dotenv.isInitialized ? dotenv.env['YT_DLP_BASE_URL'] : null) ?? 'https://it-feels-android.onrender.com';
  static set ytDlpBackendUrl(String val) => _testYtDlpUrl = val;

  static final List<String> _pipedInstances = [
    'https://pipedapi.adminforge.de',
    'https://pipedapi.tokhmi.xyz',
    'https://pipedapi.palmo.fr',
    'https://pipedapi.drgns.space',
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.reallyaweso.me',
    'https://api.piped.privacydev.net',
    'https://pipedapi.mha.fi',
  ];

  /// Piped API Multi-Instance Failover Engine
  static Future<Map<String, dynamic>> _fetchFromPipedApi(String videoId) async {
    final cleanId = videoId.contains(':') ? videoId.split(':')[1] : videoId;
    if (cleanId.isEmpty || cleanId.length != 11) {
      return {'title': 'Music Video', 'streams': []};
    }

    for (final instance in _pipedInstances) {
      try {
        final uri = Uri.parse('$instance/streams/$cleanId');
        final response = await httpClient.get(uri).timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final title = data['title'] ?? 'Music Video';
          final videoStreams = data['videoStreams'] as List? ?? [];
          final audioStreams = data['audioStreams'] as List? ?? [];

          final Map<String, Map<String, dynamic>> uniqueQualities = {};
          for (var stream in videoStreams) {
            final qualityLabel = stream['quality']?.toString() ?? (stream['height'] != null ? '${stream['height']}p' : null);
            final url = stream['url']?.toString();
            if (qualityLabel != null && url != null) {
              final formattedQuality = qualityLabel.contains('p') ? qualityLabel : '${qualityLabel}p';
              if (!uniqueQualities.containsKey(formattedQuality)) {
                uniqueQualities[formattedQuality] = {
                  'quality': formattedQuality,
                  'url': url,
                  'mimeType': stream['mimeType'] ?? '',
                  'videoOnly': stream['videoOnly'] ?? false,
                };
              }
            }
          }

          String audioUrl = '';
          if (audioStreams.isNotEmpty) {
            audioUrl = audioStreams.first['url']?.toString() ?? '';
          }

          if (uniqueQualities.isNotEmpty) {
            debugPrint('[BackendApiService] Successfully resolved streams via Piped instance: $instance');
            return {
              'title': title,
              'streams': uniqueQualities.values.toList(),
              'audioUrl': audioUrl,
            };
          }
        }
      } catch (e) {
        debugPrint('[BackendApiService] Piped instance ($instance) failed: $e');
        continue; // Failover to next public instance
      }
    }

    return {'title': 'Music Video', 'streams': []};
  } 
  
  static Future<Map<String, dynamic>> _fetchFromYtDlpBackend(String videoId) async {
    if (ytDlpBackendUrl.isEmpty) return {'title': 'Music Video', 'streams': []};
    
    final cleanId = videoId.contains(':') ? videoId.split(':').last : videoId;
    final uri = Uri.parse('$ytDlpBackendUrl/api/streams?videoId=$cleanId');
    
    int retries = 3;
    int delaySeconds = 5;
    
    for (int i = 0; i < retries; i++) {
      try {
        final response = await httpClient.get(uri).timeout(const Duration(seconds: 60));
        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          debugPrint('[BackendApiService] yt-dlp backend non-200 response: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('[BackendApiService] yt-dlp backend error (attempt ${i+1}/$retries): $e');
        if (i < retries - 1) {
          await Future.delayed(Duration(seconds: delaySeconds));
          delaySeconds *= 2; // Exponential backoff: 5s, 10s, 20s
          continue;
        }
      }
    }
    
    return {'title': 'Music Video', 'streams': []};
  }

  /// Client-side direct stream fallback using youtube_explode_dart
  static Future<Map<String, dynamic>> _directYoutubeExplodeStreamFallback(String videoId, {String? query}) async {
    debugPrint('[BackendApiService] _directYoutubeExplodeStreamFallback called with videoId=$videoId, query=$query');
    try {
      String cleanId = videoId.contains(':') ? videoId.split(':')[1] : videoId;
      
      // We still keep this fallback just in case the initial resolution failed
      if (cleanId.isEmpty || videoId.startsWith('search:') || cleanId.length != 11) {
        final searchQuery = query ?? videoId.replaceFirst('search:', '');
        final searchResults = await _yt.search.search(searchQuery);
        if (searchResults.isNotEmpty) {
          cleanId = searchResults.first.id.value;
        } else {
          return {'title': 'Music Video', 'streams': []};
        }
      }
      
      // If the yt-dlp proxy is configured, prioritize it for 4K video streams!
      if (ytDlpBackendUrl.isNotEmpty) {
        final ytDlpData = await _fetchFromYtDlpBackend(cleanId);
        if (ytDlpData['streams'] != null && (ytDlpData['streams'] as List).isNotEmpty) {
          debugPrint('[BackendApiService] Successfully fetched 4K streams from yt-dlp proxy!');
          return ytDlpData;
        } else {
           throw Exception("yt-dlp backend failed to extract streams. It might be cold-starting or facing a temporary block.");
        }
      } else {
         throw Exception("ytDlpBackendUrl is not configured. Cannot extract YouTube streams securely.");
      }

    } catch (e) {
      debugPrint('[BackendApiService] _directYoutubeExplodeStreamFallback error: $e');
    }
    return {'title': 'Music Video', 'streams': []};
  }

  /// Search Videos for Dedicated Video Tab
  static Future<List<Map<String, dynamic>>> searchVideos(String query) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/videos/search').replace(queryParameters: {'query': query});
      final response = await httpClient.get(uri, headers: _proxyHeaders).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List list = data['videos'] ?? [];
        if (list.isNotEmpty) {
          return list.map((item) => Map<String, dynamic>.from(item)).toList();
        }
      }
    } catch (e) {
      debugPrint('[BackendApiService] searchVideos proxy error: $e');
    }

    // Direct InnerTube client fallback
    return _directInnerTubeVideoSearch(query);
  }

  /// Get Trending Videos for Dedicated Video Tab
  static Future<List<Map<String, dynamic>>> getTrendingVideos() async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/videos/trending');
      final response = await httpClient.get(uri, headers: _proxyHeaders).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List list = data['videos'] ?? [];
        if (list.isNotEmpty) {
          return list.map((item) => Map<String, dynamic>.from(item)).toList();
        }
      }
    } catch (e) {
      debugPrint('[BackendApiService] getTrendingVideos proxy error: $e');
    }

    // Direct InnerTube client fallback
    return _directInnerTubeTrendingVideos();
  }

  /// Direct InnerTube Video Search
  static Future<List<Map<String, dynamic>>> _directInnerTubeVideoSearch(String query, {int limit = 20}) async {
    try {
      final uri = Uri.parse('https://www.youtube.com/youtubei/v1/search');
      final response = await httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'context': {
            'client': {
              'clientName': 'WEB',
              'clientVersion': '2.20240101.00.00',
              'hl': 'en',
              'gl': 'US',
            },
          },
          'query': query,
          'params': 'EgIQAQ%3D%3D',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final contents = data['contents']?['twoColumnSearchResultsRenderer']?['primaryContents']?['sectionListRenderer']?['contents'] ?? [];

        final List<Map<String, dynamic>> videos = [];
        for (final section in contents) {
          final items = section['itemSectionRenderer']?['contents'] ?? [];
          for (final item in items) {
            final renderer = item['videoRenderer'];
            if (renderer == null || renderer['videoId'] == null) continue;

            final videoId = renderer['videoId'];
            final title = renderer['title']?['runs']?[0]?['text'] ?? 'YouTube Video';
            final uploader = renderer['ownerText']?['runs']?[0]?['text'] ?? renderer['shortBylineText']?['runs']?[0]?['text'] ?? 'YouTube Creator';
            final thumbnail = renderer['thumbnail']?['thumbnails']?.last?['url'] ?? 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
            final views = renderer['viewCountText']?['simpleText'] ?? renderer['shortViewCountText']?['simpleText'] ?? 'Popular';
            final uploadedAt = renderer['publishedTimeText']?['simpleText'] ?? 'Recently';

            videos.add({
              'id': 'youtube:$videoId',
              'title': title,
              'uploader': uploader,
              'duration': 0,
              'thumbnail': thumbnail,
              'views': views,
              'uploadedAt': uploadedAt,
            });

            if (videos.length >= limit) break;
          }
        }
        return videos;
      }
    } catch (e) {
      debugPrint('[BackendApiService] Direct InnerTube video search error: $e');
    }
    return [];
  }

  /// Direct InnerTube Trending Videos
  static Future<List<Map<String, dynamic>>> _directInnerTubeTrendingVideos({int limit = 20}) async {
    try {
      final uri = Uri.parse('https://www.youtube.com/youtubei/v1/browse');
      final response = await httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'context': {
            'client': {
              'clientName': 'WEB',
              'clientVersion': '2.20240101.00.00',
              'hl': 'en',
              'gl': 'US',
            },
          },
          'browseId': 'FEtrending',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tabs = data['contents']?['twoColumnBrowseResultsRenderer']?['tabs'] ?? [];
        final firstTab = tabs[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'] ?? [];

        final List<Map<String, dynamic>> videos = [];
        for (final section in firstTab) {
          final items = section['itemSectionRenderer']?['contents'] ?? section['shelfRenderer']?['content']?['expandedShelfContentsRenderer']?['items'] ?? [];
          for (final item in items) {
            final renderer = item['videoRenderer'];
            if (renderer == null || renderer['videoId'] == null) continue;

            final videoId = renderer['videoId'];
            final title = renderer['title']?['runs']?[0]?['text'] ?? 'Trending Video';
            final uploader = renderer['ownerText']?['runs']?[0]?['text'] ?? 'YouTube Creator';
            final thumbnail = renderer['thumbnail']?['thumbnails']?.last?['url'] ?? 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
            final views = renderer['viewCountText']?['simpleText'] ?? renderer['shortViewCountText']?['simpleText'] ?? 'Trending';
            final uploadedAt = renderer['publishedTimeText']?['simpleText'] ?? 'Today';

            videos.add({
              'id': 'youtube:$videoId',
              'title': title,
              'uploader': uploader,
              'duration': 0,
              'thumbnail': thumbnail,
              'views': views,
              'uploadedAt': uploadedAt,
            });

            if (videos.length >= limit) break;
          }
        }
        return videos;
      }
    } catch (e) {
      debugPrint('[BackendApiService] Direct InnerTube trending videos error: $e');
    }
    return [];
  }

  /// Deserializes normalized JSON from serverless proxy into Flutter Song model
  static Song _songFromProxyJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ?? '';
    final saavnId = rawId.contains(':') ? rawId.split(':').last : rawId;

    return Song(
      id: rawId.startsWith('saavn:') ? rawId : 'saavn:$rawId',
      saavnId: saavnId,
      title: json['title']?.toString() ?? 'Unknown Title',
      artist: json['artist']?.toString() ?? 'Unknown Artist',
      album: json['album']?.toString() ?? '',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      coverArt: json['coverArt']?.toString() ?? '',
      streamUrl: json['streamUrl']?.toString(),
      encryptedMediaUrl: json['encryptedMediaUrl']?.toString(),
      hasLyrics: json['hasLyrics'] == true,
      language: json['language']?.toString() ?? 'unknown',
      year: (json['year'] as num?)?.toInt() ?? 2024,
      isExplicit: json['explicit'] == true,
      addedAt: DateTime.now(),
      searchVector: Song.generateSearchVector(
        json['title']?.toString() ?? '',
        json['artist']?.toString() ?? '',
        json['album']?.toString() ?? '',
      ),
    );
  }

  /// Fallback direct JioSaavn search
  static Future<List<Song>> _directSaavnSearch(String query, {int page = 1, int limit = 20}) async {
    final uri = Uri.parse(
      'https://www.jiosaavn.com/api.php?__call=search.getResults&p=$page&n=$limit&q=${Uri.encodeComponent(query)}&_format=json&_marker=0&api_version=4',
    );
    final response = await httpClient.get(uri);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'] ?? [];
      return results.map((e) => Song.fromJson(e)).toList();
    }
    return [];
  }
  /// Fetch Related Videos for 'Up Next' Queue
  static Future<List<Map<String, dynamic>>> getRelatedVideos(String videoId, {String? query}) async {
    debugPrint('[BackendApiService] getRelatedVideos called with videoId=$videoId, query=$query');
    String cleanId = videoId.contains(':') ? videoId.split(':')[1] : videoId;
    final yt = YoutubeExplode();
    final List<Map<String, dynamic>> videos = [];
    
    try {
      if (videoId.startsWith('search:') || cleanId.isEmpty || cleanId.length != 11) {
        final searchQuery = query ?? videoId.replaceFirst('search:', '');
        final searchResults = await yt.search.search(searchQuery);
        if (searchResults.isNotEmpty) {
          cleanId = searchResults.first.id.value;
        } else {
          return [];
        }
      }

      final targetVideo = await yt.videos.get(VideoId(cleanId));
      final related = await yt.videos.getRelatedVideos(targetVideo);
      if (related != null) {
        for (final video in related) {
          videos.add({
            'id': 'youtube:${video.id.value}',
            'title': video.title,
            'uploader': video.author,
            'duration': video.duration?.inSeconds ?? 0,
            'thumbnail': video.thumbnails.highResUrl,
            'views': '${_formatViews(video.engagement.viewCount)} views',
            'uploadedAt': '', // Not always provided by related API
          });
        }
      }
    } catch (e) {
      debugPrint('[BackendApiService] getRelatedVideos error: $e');
    } finally {
      yt.close();
    }
    return videos;
  }

  /// Helper to format view counts
  static String _formatViews(int views) {
    if (views >= 1000000000) return '${(views / 1000000000).toStringAsFixed(1)}B';
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K';
    return views.toString();
  }

  /// Fetch Channel Avatar URL
  static Future<String?> getChannelAvatar(String channelId) async {
    final yt = YoutubeExplode();
    try {
      final channel = await yt.channels.get(ChannelId(channelId));
      return channel.logoUrl;
    } catch (e) {
      debugPrint('[BackendApiService] getChannelAvatar error: $e');
      return null;
    } finally {
      yt.close();
    }
  }
}
