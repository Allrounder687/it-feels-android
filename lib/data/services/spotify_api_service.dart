import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:it_feels_music/data/models/track_ref.dart';
import 'package:it_feels_music/services/backend_api_service.dart';
import 'package:it_feels_music/data/models/song_model.dart';

class SpotifyApiService {
  static final SpotifyApiService _instance = SpotifyApiService._internal();
  factory SpotifyApiService() => _instance;
  SpotifyApiService._internal();

  static const String _baseUrl = 'https://api.spotify.com/v1';
  static const String _market = 'IN';
  
  String? _accessToken;
  DateTime? _tokenExpiry;
  bool _isFetchingToken = false;

  Future<String?> _getToken() async {
    if (_accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken;
    }

    if (_isFetchingToken) {
      await Future.delayed(const Duration(milliseconds: 500));
      return _getToken();
    }

    _isFetchingToken = true;
    try {
      final proxyUrl = Uri.parse('${BackendApiService.baseUrl}/spotify/token');
      final response = await http.get(proxyUrl).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        _tokenExpiry = DateTime.now().add(Duration(seconds: data['expires_in'] - 60));
        return _accessToken;
      }
    } catch (e) {
      debugPrint('[SpotifyApiService] Error fetching token from proxy: $e');
    } finally {
      _isFetchingToken = false;
    }
    
    return null;
  }

  Future<http.Response> _getWithRetry(Uri uri) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Failed to acquire Spotify token');
    }

    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };

    int attempts = 0;
    while (attempts < 3) {
      final response = await http.get(uri, headers: headers);
      
      if (response.statusCode == 429) {
        final retryAfter = int.tryParse(response.headers['retry-after'] ?? '2') ?? 2;
        debugPrint('[SpotifyApiService] Rate limited (429). Retrying after $retryAfter seconds.');
        await Future.delayed(Duration(seconds: retryAfter));
        attempts++;
        continue;
      }
      return response;
    }
    throw Exception('Spotify API rate limit exceeded after retries.');
  }

  Future<List<Playlist>> getFeaturedPlaylists() async {
    try {
      final uri = Uri.parse('$_baseUrl/browse/featured-playlists?country=$_market&limit=10');
      final response = await _getWithRetry(uri);
      
      if (response.statusCode == 200) {
        final data = await compute(jsonDecode, response.body);
        final items = data['playlists']?['items'] as List? ?? [];
        
        return items.where((item) => item != null).map((item) => Playlist(
          id: item['id'],
          title: item['name'] ?? 'Playlist',
          coverArt: (item['images'] != null && (item['images'] as List).isNotEmpty) ? item['images'][0]['url'] : '',
          songCount: item['tracks']?['total'] ?? 0,
          type: 'playlist',
        )).toList();
      }
    } catch (e) {
      debugPrint('[SpotifyApiService] Error fetching featured playlists: $e');
    }
    return [];
  }

  Future<List<Playlist>> getNewReleases() async {
    try {
      final uri = Uri.parse('$_baseUrl/browse/new-releases?country=$_market&limit=10');
      final response = await _getWithRetry(uri);
      
      if (response.statusCode == 200) {
        final data = await compute(jsonDecode, response.body);
        final items = data['albums']?['items'] as List? ?? [];
        
        return items.map((item) => Playlist(
          id: item['id'],
          title: item['name'] ?? 'Album',
          coverArt: (item['images'] != null && (item['images'] as List).isNotEmpty) ? item['images'][0]['url'] : '',
          songCount: item['total_tracks'] ?? 0,
          type: 'album',
        )).toList();
      }
    } catch (e) {
      debugPrint('[SpotifyApiService] Error fetching new releases: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final uri = Uri.parse('$_baseUrl/browse/categories?country=$_market&limit=20');
      final response = await _getWithRetry(uri);
      
      if (response.statusCode == 200) {
        final data = await compute(jsonDecode, response.body);
        final items = data['categories']?['items'] as List? ?? [];
        
        return items.map((item) => {
          'id': item['id'],
          'name': item['name'],
          'image': (item['icons'] != null && (item['icons'] as List).isNotEmpty) ? item['icons'][0]['url'] : '',
        }).toList();
      }
    } catch (e) {
      debugPrint('[SpotifyApiService] Error fetching categories: $e');
    }
    return [];
  }

  Future<List<TrackRef>> getPlaylistTracks(String playlistId) async {
    try {
      final uri = Uri.parse('$_baseUrl/playlists/$playlistId/tracks?market=$_market&limit=50');
      final response = await _getWithRetry(uri);
      
      if (response.statusCode == 200) {
        final data = await compute(jsonDecode, response.body);
        final items = data['items'] as List? ?? [];
        
        return items.where((item) => item['track'] != null).map((item) {
          return TrackRef.fromJson(item['track']);
        }).toList();
      }
    } catch (e) {
      debugPrint('[SpotifyApiService] Error fetching playlist tracks: $e');
    }
    return [];
  }

  Future<List<TrackRef>> getAlbumTracks(String albumId) async {
    try {
      final uri = Uri.parse('$_baseUrl/albums/$albumId?market=$_market');
      final response = await _getWithRetry(uri);
      
      if (response.statusCode == 200) {
        final data = await compute(jsonDecode, response.body);
        final items = data['tracks']?['items'] as List? ?? [];
        final albumImages = data['images'] as List? ?? [];
        final albumArtUrl = albumImages.isNotEmpty ? albumImages[0]['url'] : '';
        
        return items.map((item) {
          // Album tracks response doesn't include the album object inside the track
          item['album'] = {'name': data['name'], 'images': albumImages};
          return TrackRef.fromJson(item);
        }).toList();
      }
    } catch (e) {
      debugPrint('[SpotifyApiService] Error fetching album tracks: $e');
    }
    return [];
  }
}
