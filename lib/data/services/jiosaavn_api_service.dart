import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/utils/des_decryptor.dart';
import '../models/song_model.dart';

class JioSaavnApiService {
  static const String _baseUrl = 'https://www.jiosaavn.com/api.php';
  static final Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json',
  };

  final Map<String, String> _streamCache = {};
  final Map<String, dynamic> _homepageCache = {};
  final Map<String, dynamic> _playlistCache = {};
  final Map<String, dynamic> _albumCache = {};
  static const Duration _cacheDuration = Duration(minutes: 10);
  DateTime _homepageCacheExpiry = DateTime.now();
  final Map<String, DateTime> _playlistCacheExpiries = {};
  final Map<String, DateTime> _albumCacheExpiries = {};

  /// Search all categories (songs, albums, playlists)
  Future<Map<String, dynamic>> searchAll(String query, {Function(String message)? onError}) async {
    if (query.trim().isEmpty) {
      return {'songs': <Song>[], 'albums': <Playlist>[], 'playlists': <Playlist>[]};
    }

    try {
      final url = Uri.parse(
          '$_baseUrl?__call=autocomplete.get&_format=json&_marker=0&api_version=4&ctx=web6dot0&query=${Uri.encodeComponent(query)}');

      final response = await http.get(url, headers: _headers);
      if (response.statusCode != 200) {
        final errorMessage = 'Failed to search. Status code: ${response.statusCode}';
        onError?.call(errorMessage);
        debugPrint('[JioSaavnApiService] $errorMessage');
        return {'songs': <Song>[], 'albums': <Playlist>[], 'playlists': <Playlist>[]};
      }

      final data = json.decode(response.body);
      final List<Song> songs = [];
      final List<Playlist> albums = [];
      final List<Playlist> playlists = [];

      // Songs
      if (data['songs'] != null && data['songs']['data'] is List) {
        for (var item in data['songs']['data']) {
          songs.add(Song.fromJson(item));
        }
      }

      // Albums
      if (data['albums'] != null && data['albums']['data'] is List) {
        for (var item in data['albums']['data']) {
          albums.add(Playlist.fromJson({...item, 'type': 'album'}));
        }
      }

      // Playlists
      if (data['playlists'] != null && data['playlists']['data'] is List) {
        for (var item in data['playlists']['data']) {
          playlists.add(Playlist.fromJson({...item, 'type': 'playlist'}));
        }
      }

      return {
        'songs': songs,
        'albums': albums,
        'playlists': playlists,
      };
    } catch (e) {
      final errorMessage = 'Search error: $e';
      onError?.call('Failed to perform search. Please try again.');
      debugPrint('[JioSaavnApiService] $errorMessage');
      return {'songs': <Song>[], 'albums': <Playlist>[], 'playlists': <Playlist>[]};
    }
  }

  /// Search for songs on JioSaavn
  Future<List<Song>> searchSongs(String query, {Function(String message)? onError}) async {
    final res = await searchAll(query, onError: onError);
    return res['songs'] as List<Song>;
  }

  /// Get Homepage Data (Trending songs, charts, playlists)
  Future<Map<String, dynamic>> fetchHomepageData({Function(String message)? onError}) async {
    // Check cache first
    if (_homepageCache.isNotEmpty && DateTime.now().isBefore(_homepageCacheExpiry)) {
      return _homepageCache;
    }

    try {
      final url = Uri.parse(
          '$_baseUrl?__call=content.getHomepageData&_format=json&_marker=0&api_version=4&ctx=web6dot0');

      final response = await http.get(url, headers: _headers);
      if (response.statusCode != 200) {
        final errorMessage = 'Failed to fetch homepage data. Status code: ${response.statusCode}';
        onError?.call(errorMessage);
        debugPrint('[JioSaavnApiService] $errorMessage');
        return {'trending': <Song>[], 'playlists': <Playlist>[]};
      }

      final data = json.decode(response.body);
      final List<Song> trendingSongs = [];
      final List<Playlist> playlists = [];

      if (data['charts'] is List && (data['charts'] as List).isNotEmpty) {
        final firstChart = data['charts'][0];
        final chartId = firstChart['id'] ?? firstChart['listid'];
        if (chartId != null) {
          final chartPlaylist = await fetchPlaylistDetails(chartId.toString(), onError: onError);
          trendingSongs.addAll(chartPlaylist['songs'] as List<Song>);
        }
      }

      final sources = [
        {'data': data['charts'], 'type': 'playlist'},
        {'data': data['top_playlists'] ?? data['featured_playlists'], 'type': 'playlist'},
        {'data': data['new_albums'], 'type': 'album'},
      ];

      for (var src in sources) {
        if (src['data'] is List) {
          for (var item in src['data']) {
            playlists.add(Playlist.fromJson(item));
          }
        }
      }

      final result = {
        'trending': trendingSongs,
        'playlists': playlists,
      };
      // Store in cache with new expiry
      _homepageCache.clear();
      _homepageCache.addAll(result);
      _homepageCacheExpiry = DateTime.now().add(_cacheDuration);
      return result;
    } catch (e) {
      final errorMessage = 'Homepage error: $e';
      onError?.call('Failed to load homepage content. Please try again.');
      debugPrint('[JioSaavnApiService] $errorMessage');
      return {'trending': <Song>[], 'playlists': <Playlist>[]};
    }
  }

  /// Fetch playlist tracks
  Future<Map<String, dynamic>> fetchPlaylistDetails(String listId, {Function(String message)? onError}) async {
    // Check cache first
    if (_playlistCache.containsKey(listId) &&
        _playlistCacheExpiries.containsKey(listId) &&
        DateTime.now().isBefore(_playlistCacheExpiries[listId]!)) {
      return _playlistCache[listId];
    }

    try {
      final url = Uri.parse(
          '$_baseUrl?__call=playlist.getDetails&_format=json&cc=in&_marker=0&api_version=4&ctx=web6dot0&listid=$listId');

      final response = await http.get(url, headers: _headers);
      if (response.statusCode != 200) {
        final errorMessage = 'Failed to fetch playlist details for ID $listId. Status code: ${response.statusCode}';
        onError?.call(errorMessage);
        debugPrint('[JioSaavnApiService] $errorMessage');
        return {'name': '', 'songs': <Song>[]};
      }

      final data = json.decode(response.body);
      final String playlistName = Song.cleanText(data['listname'] ?? data['title'] ?? data['name'] ?? 'Playlist');
      final rawSongs = data['songs'] ?? data['list'] ?? [];

      final List<Song> songs = [];
      if (rawSongs is List) {
        for (var item in rawSongs) {
          songs.add(Song.fromJson(item));
        }
      }

      final result = {
        'name': playlistName,
        'songs': songs,
        'image': (data['image'] ?? '').toString().replaceAll('150x150', '500x500'),
      };
      // Store in cache with new expiry
      _playlistCache[listId] = result;
      _playlistCacheExpiries[listId] = DateTime.now().add(_cacheDuration);
      return result;
    } catch (e) {
      final errorMessage = 'Playlist error for ID $listId: $e';
      onError?.call('Failed to load playlist details. Please try again.');
      debugPrint('[JioSaavnApiService] $errorMessage');
      return {'name': '', 'songs': <Song>[]};
    }
  }

  /// Fetch album tracks
  Future<Map<String, dynamic>> fetchAlbumDetails(String albumId, {Function(String message)? onError}) async {
    // Check cache first
    if (_albumCache.containsKey(albumId) &&
        _albumCacheExpiries.containsKey(albumId) &&
        DateTime.now().isBefore(_albumCacheExpiries[albumId]!)) {
      return _albumCache[albumId];
    }

    try {
      final url = Uri.parse(
          '$_baseUrl?__call=content.getAlbumDetails&_format=json&cc=in&_marker=0&api_version=4&ctx=web6dot0&albumid=$albumId');

      final response = await http.get(url, headers: _headers);
      if (response.statusCode != 200) {
        final errorMessage = 'Failed to fetch album details for ID $albumId. Status code: ${response.statusCode}';
        onError?.call(errorMessage);
        debugPrint('[JioSaavnApiService] $errorMessage');
        return {'name': '', 'songs': <Song>[]};
      }

      final data = json.decode(response.body);
      final String albumName = Song.cleanText(data['title'] ?? data['name'] ?? 'Album');
      final rawSongs = data['songs'] ?? data['list'] ?? [];

      final List<Song> songs = [];
      if (rawSongs is List) {
        for (var item in rawSongs) {
          songs.add(Song.fromJson(item));
        }
      }

      final result = {
        'name': albumName,
        'songs': songs,
        'image': (data['image'] ?? '').toString().replaceAll('150x150', '500x500'),
      };
      // Store in cache with new expiry
      _albumCache[albumId] = result;
      _albumCacheExpiries[albumId] = DateTime.now().add(_cacheDuration);
      return result;
    } catch (e) {
      final errorMessage = 'Album error for ID $albumId: $e';
      onError?.call('Failed to load album details. Please try again.');
      debugPrint('[JioSaavnApiService] $errorMessage');
      return {'name': '', 'songs': <Song>[]};
    }
  }

  /// Resolve streamable 320kbps audio URL for a song
  Future<String?> getStreamUrl(Song song, {Function(String message)? onError}) async {
    if (_streamCache.containsKey(song.saavnId)) {
      return _streamCache[song.saavnId];
    }

    try {
      String? encUrl = song.encryptedMediaUrl;

      if (encUrl == null || encUrl.isEmpty) {
        final url = Uri.parse(
            '$_baseUrl?__call=song.getDetails&_format=json&cc=in&_marker=0&pids=${song.saavnId}');
        final response = await http.get(url, headers: _headers);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['songs'] is List && (data['songs'] as List).isNotEmpty) {
            encUrl = data['songs'][0]['more_info']?['encrypted_media_url'] ??
                data['songs'][0]['encrypted_media_url'];
          } else if (data[song.saavnId] != null) {
            encUrl = data[song.saavnId]['more_info']?['encrypted_media_url'] ??
                data[song.saavnId]['encrypted_media_url'];
          }
        } else {
          final errorMessage = 'Failed to fetch encrypted URL for ${song.saavnId}. Status code: ${response.statusCode}';
          onError?.call(errorMessage);
          debugPrint('[JioSaavnApiService] $errorMessage');
          return null;
        }
      }

      if (encUrl == null || encUrl.isEmpty) {
        final errorMessage = 'No encrypted URL found for ${song.saavnId}';
        onError?.call(errorMessage);
        debugPrint('[JioSaavnApiService] $errorMessage');
        return null;
      }

      final decrypted = await DesDecryptor.decrypt(encUrl, onError: onError);
      if (decrypted == null) {
        onError?.call('Failed to decrypt stream URL for ${song.title}');
        return null;
      }

      final finalUrl = DesDecryptor.get320kbpsUrl(decrypted);

      if (finalUrl != null) {
        _streamCache[song.saavnId] = finalUrl;
        return finalUrl;
      } else {
        final errorMessage = 'Failed to get 320kbps URL for ${song.saavnId}';
        onError?.call(errorMessage);
        debugPrint('[JioSaavnApiService] $errorMessage');
        return null;
      }
    } catch (e) {
      final errorMessage = 'Stream resolution error for ${song.saavnId}: $e';
      onError?.call('Failed to get stream URL for ${song.title}. Please try again.');
      debugPrint('[JioSaavnApiService] $errorMessage');
    }

    return null;
  }
}
