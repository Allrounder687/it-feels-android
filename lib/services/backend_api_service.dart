import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../data/models/song_model.dart';
import '../core/utils/des_decryptor.dart';

class BackendApiService {
  // Configurable proxy base URL (defaults to user's live Cloudflare Worker URL)
  static String baseUrl = 'https://it-feels-proxy.cleverfox687.workers.dev'; 
  static bool useProxyBackend = false; // Toggle to switch between direct & proxy mode

  static const Map<String, String> _proxyHeaders = {
    'X-Feels-Secret': 'development_secret_123',
  };

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

      final response = await http.get(uri, headers: _proxyHeaders).timeout(const Duration(seconds: 8));
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

      final response = await http.get(uri, headers: _proxyHeaders).timeout(const Duration(seconds: 5));
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

      final response = await http.get(uri, headers: _proxyHeaders).timeout(const Duration(seconds: 6));
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
      final response = await http.post(
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
      final response = await http.post(
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
      await http.post(
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

  /// Fetch MP4 Video Streams with Age Restriction Bypass
  static Future<Map<String, dynamic>> getVideoStreams(String videoId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/video').replace(queryParameters: {'id': videoId});
      final response = await http.get(uri, headers: _proxyHeaders).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List streamsList = data['streams'] ?? [];
        if (streamsList.isNotEmpty) {
          return {
            'title': data['title'] ?? 'Music Video',
            'streams': streamsList,
            'audioUrl': data['audioUrl'] ?? '',
          };
        }
      }
    } catch (e) {
      debugPrint('[BackendApiService] getVideoStreams error: $e');
    }
    
    // Direct youtube_explode_dart client fallback
    return _directYoutubeExplodeStreamFallback(videoId);
  }

  /// Client-side direct stream fallback using youtube_explode_dart
  static Future<Map<String, dynamic>> _directYoutubeExplodeStreamFallback(String videoId) async {
    final cleanId = videoId.contains(':') ? videoId.split(':')[1] : videoId;
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(cleanId);
      final videoInfo = await yt.videos.get(cleanId);
      
      final muxedStreams = manifest.muxed;
      if (muxedStreams.isNotEmpty) {
        final streamsList = muxedStreams.map((s) => {
          'quality': s.videoQuality.name,
          'url': s.url.toString(),
          'hasAudio': true,
        }).toList();
        
        return {
          'title': videoInfo.title,
          'streams': streamsList,
          'audioUrl': manifest.audioOnly.withHighestBitrate().url.toString(),
        };
      }
    } catch (e) {
      debugPrint('[BackendApiService] YoutubeExplode fallback error: $e');
    } finally {
      yt.close();
    }
    return {'title': 'Music Video', 'streams': []};
  }

  /// Search Videos for Dedicated Video Tab
  static Future<List<Map<String, dynamic>>> searchVideos(String query) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/videos/search').replace(queryParameters: {'query': query});
      final response = await http.get(uri, headers: _proxyHeaders).timeout(const Duration(seconds: 6));
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
      final response = await http.get(uri, headers: _proxyHeaders).timeout(const Duration(seconds: 6));
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
  /// Fetch Related Videos for 'Up Next' Queue
  static Future<List<Map<String, dynamic>>> getRelatedVideos(String videoId) async {
    final cleanId = videoId.contains(':') ? videoId.split(':')[1] : videoId;
    final yt = YoutubeExplode();
    final List<Map<String, dynamic>> videos = [];
    
    try {
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
