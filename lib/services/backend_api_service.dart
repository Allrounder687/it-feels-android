import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../data/models/song_model.dart';
import '../core/utils/des_decryptor.dart';

class BackendApiService {
  // Configurable proxy base URL (defaults to user's live Cloudflare Worker URL)
  static String baseUrl = 'https://it-feels-proxy.cleverfox687.workers.dev'; 
  static bool useProxyBackend = false; // Toggle to switch between direct & proxy mode

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

      final response = await http.get(uri).timeout(const Duration(seconds: 8));
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

      final response = await http.get(uri).timeout(const Duration(seconds: 5));
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

      final response = await http.get(uri).timeout(const Duration(seconds: 6));
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

  /// Fetch MP4 Video Streams with Age Restriction Bypass
  static Future<Map<String, dynamic>> getVideoStreams(String videoId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/video').replace(queryParameters: {'id': videoId});
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'title': data['title'] ?? 'Music Video',
          'streams': data['streams'] ?? [],
          'audioUrl': data['audioUrl'] ?? '',
        };
      }
    } catch (e) {
      debugPrint('[BackendApiService] getVideoStreams error: $e');
    }
    return {'title': 'Music Video', 'streams': []};
  }

  /// Search Videos for Dedicated Video Tab
  static Future<List<Map<String, dynamic>>> searchVideos(String query) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/videos/search').replace(queryParameters: {'query': query});
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
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
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
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
      final response = await http.post(
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
      final response = await http.post(
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
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'] ?? [];
      return results.map((e) => Song.fromJson(e)).toList();
    }
    return [];
  }
}
