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

  /// Search all categories (songs, albums, playlists)
  Future<Map<String, dynamic>> searchAll(String query) async {
    if (query.trim().isEmpty) {
      return {'songs': <Song>[], 'albums': <Playlist>[], 'playlists': <Playlist>[]};
    }

    try {
      final url = Uri.parse(
          '$_baseUrl?__call=autocomplete.get&_format=json&_marker=0&api_version=4&ctx=web6dot0&query=${Uri.encodeComponent(query)}');

      final response = await http.get(url, headers: _headers);
      if (response.statusCode != 200) {
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
      debugPrint('[JioSaavnApiService] Search error: $e');
      return {'songs': <Song>[], 'albums': <Playlist>[], 'playlists': <Playlist>[]};
    }
  }

  /// Search for songs on JioSaavn
  Future<List<Song>> searchSongs(String query) async {
    final res = await searchAll(query);
    return res['songs'] as List<Song>;
  }

  /// Get Homepage Data (Trending songs, charts, playlists)
  Future<Map<String, dynamic>> fetchHomepageData() async {
    try {
      final url = Uri.parse(
          '$_baseUrl?__call=content.getHomepageData&_format=json&_marker=0&api_version=4&ctx=web6dot0');

      final response = await http.get(url, headers: _headers);
      if (response.statusCode != 200) {
        return {'trending': <Song>[], 'playlists': <Playlist>[]};
      }

      final data = json.decode(response.body);
      final List<Song> trendingSongs = [];
      final List<Playlist> playlists = [];

      if (data['charts'] is List && (data['charts'] as List).isNotEmpty) {
        final firstChart = data['charts'][0];
        final chartId = firstChart['id'] ?? firstChart['listid'];
        if (chartId != null) {
          final chartPlaylist = await fetchPlaylistDetails(chartId.toString());
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

      return {
        'trending': trendingSongs,
        'playlists': playlists,
      };
    } catch (e) {
      debugPrint('[JioSaavnApiService] Homepage error: $e');
      return {'trending': <Song>[], 'playlists': <Playlist>[]};
    }
  }

  /// Fetch playlist tracks
  Future<Map<String, dynamic>> fetchPlaylistDetails(String listId) async {
    try {
      final url = Uri.parse(
          '$_baseUrl?__call=playlist.getDetails&_format=json&cc=in&_marker=0&api_version=4&ctx=web6dot0&listid=$listId');

      final response = await http.get(url, headers: _headers);
      if (response.statusCode != 200) return {'name': '', 'songs': <Song>[]};

      final data = json.decode(response.body);
      final String playlistName = Song.cleanText(data['listname'] ?? data['title'] ?? data['name'] ?? 'Playlist');
      final rawSongs = data['songs'] ?? data['list'] ?? [];

      final List<Song> songs = [];
      if (rawSongs is List) {
        for (var item in rawSongs) {
          songs.add(Song.fromJson(item));
        }
      }

      return {
        'name': playlistName,
        'songs': songs,
        'image': (data['image'] ?? '').toString().replaceAll('150x150', '500x500'),
      };
    } catch (e) {
      debugPrint('[JioSaavnApiService] Playlist error: $e');
      return {'name': '', 'songs': <Song>[]};
    }
  }

  /// Fetch album tracks
  Future<Map<String, dynamic>> fetchAlbumDetails(String albumId) async {
    try {
      final url = Uri.parse(
          '$_baseUrl?__call=content.getAlbumDetails&_format=json&cc=in&_marker=0&api_version=4&ctx=web6dot0&albumid=$albumId');

      final response = await http.get(url, headers: _headers);
      if (response.statusCode != 200) return {'name': '', 'songs': <Song>[]};

      final data = json.decode(response.body);
      final String albumName = Song.cleanText(data['title'] ?? data['name'] ?? 'Album');
      final rawSongs = data['songs'] ?? data['list'] ?? [];

      final List<Song> songs = [];
      if (rawSongs is List) {
        for (var item in rawSongs) {
          songs.add(Song.fromJson(item));
        }
      }

      return {
        'name': albumName,
        'songs': songs,
        'image': (data['image'] ?? '').toString().replaceAll('150x150', '500x500'),
      };
    } catch (e) {
      debugPrint('[JioSaavnApiService] Album error: $e');
      return {'name': '', 'songs': <Song>[]};
    }
  }

  /// Resolve streamable 320kbps audio URL for a song
  Future<String?> getStreamUrl(Song song) async {
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
        }
      }

      if (encUrl == null || encUrl.isEmpty) {
        debugPrint('[JioSaavnApiService] No encrypted URL found for ${song.saavnId}');
        return null;
      }

      final decrypted = DesDecryptor.decrypt(encUrl);
      final finalUrl = DesDecryptor.get320kbpsUrl(decrypted);

      if (finalUrl != null) {
        _streamCache[song.saavnId] = finalUrl;
        return finalUrl;
      }
    } catch (e) {
      debugPrint('[JioSaavnApiService] Stream resolution error for ${song.saavnId}: $e');
    }

    return null;
  }
}
