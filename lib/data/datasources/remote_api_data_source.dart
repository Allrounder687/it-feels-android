import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/utils/string_utils.dart';

/// Remote API data source wrapping Cloudflare Edge Worker proxy endpoints.
class RemoteApiDataSource {
  final http.Client httpClient;
  final String baseUrl;

  RemoteApiDataSource({
    http.Client? httpClient,
    this.baseUrl = 'https://it-feels-proxy.cleverfox687.workers.dev',
  }) : httpClient = httpClient ?? http.Client();

  /// Fetches recommendations from edge proxy.
  Future<List<Song>> fetchRecommendations({required String artist}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/recommendations?artist=${Uri.encodeComponent(artist)}');
      final res = await httpClient.get(uri);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic> && decoded['recommendations'] is List) {
          return (decoded['recommendations'] as List)
              .map((item) => songFromProxyJson(item as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Searches proxy catalogue.
  Future<List<Song>?> searchProxy(String query) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/search?query=${Uri.encodeComponent(query)}');
      final res = await httpClient.get(uri);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic> && decoded['results'] is List) {
          return (decoded['results'] as List)
              .map((item) => songFromProxyJson(item as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}
    return null;
  }

  /// Resolves stream URL for a song.
  Future<String?> getStreamUrl(Song song) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/stream?id=${song.id}');
      final res = await httpClient.get(uri);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic> && decoded['streamUrl'] != null) {
          return decoded['streamUrl'].toString();
        }
      }
    } catch (_) {}
    return song.streamUrl;
  }

  /// Fetches lyrics from proxy.
  Future<Map<String, String>?> getLyrics(String track, String artist) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/lyrics?track=${Uri.encodeComponent(track)}&artist=${Uri.encodeComponent(artist)}');
      final res = await httpClient.get(uri);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic> && decoded['lyrics'] is Map) {
          final lyrics = decoded['lyrics'] as Map<String, dynamic>;
          final plain = lyrics['plainLyrics']?.toString() ?? lyrics['plain']?.toString() ?? '';
          final synced = lyrics['syncedLyrics']?.toString() ?? lyrics['synced']?.toString() ?? '';
          return {'plain': plain, 'synced': synced};
        }
      }
    } catch (_) {}
    return null;
  }

  /// Maps a proxy JSON payload into a clean Song instance.
  Song songFromProxyJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ?? '';
    final saavnId = rawId.contains(':') ? rawId.split(':').last : rawId;
    return Song(
      id: rawId,
      saavnId: saavnId,
      title: StringUtils.cleanText(json['title']?.toString() ?? ''),
      artist: StringUtils.cleanText(json['artist']?.toString() ?? 'Unknown Artist'),
      album: StringUtils.cleanText(json['album']?.toString() ?? ''),
      duration: json['duration'] is int ? json['duration'] as int : 0,
      coverArt: json['coverArt']?.toString() ?? json['image']?.toString() ?? '',
      streamUrl: json['streamUrl']?.toString(),
      addedAt: DateTime.now(),
    );
  }
}
