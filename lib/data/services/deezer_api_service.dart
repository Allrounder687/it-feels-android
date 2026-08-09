import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/services/backend_api_service.dart';

class DeezerApiService {
  String get _baseUrl => '${BackendApiService.baseUrl}/api/v1/deezer';

  Song _parseTrack(Map<String, dynamic> track) {
    return Song(
      id: 'dz_${track['id']}',
      saavnId: '',
      title: track['title']?.toString() ?? 'Unknown Title',
      artist: track['artist']?['name']?.toString() ?? 'Unknown Artist',
      album: track['album']?['title']?.toString() ?? 'Unknown Album',
      duration: int.tryParse(track['duration']?.toString() ?? '0') ?? 0,
      coverArt: track['album']?['cover_xl']?.toString() ?? track['album']?['cover_medium']?.toString() ?? '',
      genre: '',
      year: DateTime.now().year,
      language: '',
      isExplicit: track['explicit_lyrics'] ?? false,
      playCount: 0,
      skipCount: 0,
      addedAt: DateTime.now(),
      isFavorite: false,
      offlineStatus: OfflineStatus.none,
      searchVector: [],
    );
  }

  Playlist _parsePlaylist(Map<String, dynamic> item) {
    return Playlist(
      id: 'dz_${item['id']}',
      title: item['title']?.toString() ?? 'Playlist',
      coverArt: item['picture_xl']?.toString() ?? item['picture_medium']?.toString() ?? '',
      songCount: item['nb_tracks'] ?? 0,
      type: item['type'] ?? 'playlist',
    );
  }

  Future<dynamic> _get(String endpoint) async {
    final uri = Uri.parse('$_baseUrl/$endpoint');
    final response = await http.get(
      uri,
      headers: {
        'X-Feels-Secret': dotenv.isInitialized ? (dotenv.env['API_SECRET'] ?? 'development_secret_123') : 'development_secret_123',
      },
    );
    if (response.statusCode == 200) {
      return compute(jsonDecode, response.body);
    }
    throw Exception('Deezer API Error: ${response.statusCode}');
  }

  /// Get Deezer Global Charts
  Future<Map<String, dynamic>> getCharts() async {
    try {
      final data = await _get('chart');
      
      List<Song> tracks = (data['tracks']?['data'] as List?)?.map((t) => _parseTrack(t as Map<String, dynamic>)).toList() ?? <Song>[];
      
      // Fallback: If global chart returns no tracks (due to IP geo-blocks in India), fetch the Global Top 100 Playlist explicitly
      if (tracks.isEmpty) {
        try {
          final top100Data = await _get('playlist/3155776842');
          tracks = (top100Data['tracks']?['data'] as List?)?.map((t) => _parseTrack(t as Map<String, dynamic>)).toList() ?? <Song>[];
        } catch (e) {
          debugPrint('[DeezerApiService] getCharts fallback Error: $e');
        }
      }

      final playlists = (data['playlists']?['data'] as List?)?.map((p) => _parsePlaylist(p as Map<String, dynamic>)).toList() ?? <Playlist>[];
      
      return {
        'tracks': tracks,
        'playlists': playlists,
      };
    } catch (e) {
      debugPrint('[DeezerApiService] getCharts Error: $e');
      return {'tracks': <Song>[], 'playlists': <Playlist>[]};
    }
  }

  /// Get Editorial Selections
  Future<List<Playlist>> getEditorialPlaylists(String genreId) async {
    try {
      final data = await _get('editorial/$genreId/selection');
      return (data['data'] as List?)?.map((p) => _parsePlaylist(p)).toList() ?? <Playlist>[];
    } catch (e) {
      debugPrint('[DeezerApiService] getEditorialPlaylists Error: $e');
      return [];
    }
  }

  /// Search Playlists
  Future<List<Playlist>> searchPlaylists(String query, {int limit = 10}) async {
    try {
      final data = await _get('search/playlist?q=${Uri.encodeComponent(query)}&limit=$limit');
      return (data['data'] as List?)?.map((p) => _parsePlaylist(p as Map<String, dynamic>)).toList() ?? <Playlist>[];
    } catch (e) {
      debugPrint('[DeezerApiService] searchPlaylists Error: $e');
      return [];
    }
  }

  /// Fetch full Playlist Details (Tracks)
  Future<Map<String, dynamic>> fetchPlaylistDetails(String id) async {
    try {
      final data = await _get('playlist/$id');
      final tracks = (data['tracks']?['data'] as List?)
              ?.map((t) => _parseTrack(t as Map<String, dynamic>))
              .toList() ??
          <Song>[];
          
      return {
        'name': data['title']?.toString() ?? 'Deezer Playlist',
        'image': data['picture_xl']?.toString() ?? data['picture_medium']?.toString() ?? '',
        'songs': tracks,
      };
    } catch (e) {
      debugPrint('[DeezerApiService] fetchPlaylistDetails Error: $e');
      return {'songs': <Song>[]};
    }
  }
}
