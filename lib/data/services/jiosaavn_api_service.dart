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
    'Cookie': 'L=hindi; telugu; tamil; punjabi; english;',
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
        return {'songs': <Song>[], 'albums': <Playlist>[], 'playlists': <Playlist>[]};
      }

      final data = json.decode(response.body);
      final List<Song> songs = [];
      final List<Playlist> albums = [];
      final List<Playlist> playlists = [];
      final List<Map<String, dynamic>> artists = [];

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

      // Artists
      if (data['artists'] != null && data['artists']['data'] is List) {
        for (var item in data['artists']['data']) {
          artists.add({
            'id': item['id'] ?? '',
            'title': item['title'] ?? item['name'] ?? '',
            'image': (item['image'] ?? '').toString().replaceAll('50x50', '500x500'),
          });
        }
      }

      return {
        'songs': songs,
        'albums': albums,
        'playlists': playlists,
        'artists': artists,
      };
    } catch (e) {
      debugPrint('[JioSaavnApiService] Search error: $e');
      return {'songs': <Song>[], 'albums': <Playlist>[], 'playlists': <Playlist>[], 'artists': <Map<String, dynamic>>[]};
    }
  }

  /// Search for songs on JioSaavn (returns 40+ songs per query)
  Future<List<Song>> searchSongs(String query, {int page = 1, int count = 40, Function(String message)? onError}) async {
    if (query.trim().isEmpty) return [];

    try {
      final url = Uri.parse(
          '$_baseUrl?__call=search.getResults&_format=json&p=$page&n=$count&api_version=4&ctx=web6dot0&q=${Uri.encodeComponent(query)}');

      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rawSongs = data['results'] ?? data['songs'] ?? [];
        final List<Song> songs = [];
        if (rawSongs is List) {
          for (var item in rawSongs) {
            songs.add(Song.fromJson(item));
          }
        }
        if (songs.isNotEmpty) return songs;
      }
    } catch (e) {
      debugPrint('[JioSaavnApiService] searchSongs error: $e');
    }

    final res = await searchAll(query, onError: onError);
    return res['songs'] as List<Song>;
  }

  /// Search for playlists on JioSaavn
  Future<List<Playlist>> searchPlaylists(String query, {int page = 1, int count = 30}) async {
    try {
      final url = Uri.parse(
          '$_baseUrl?__call=search.getPlaylistResults&_format=json&p=$page&n=$count&api_version=4&ctx=web6dot0&q=${Uri.encodeComponent(query)}');
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rawResults = data['results'] ?? data['playlists'] ?? [];
        final List<Playlist> playlists = [];
        if (rawResults is List) {
          for (var item in rawResults) {
            playlists.add(Playlist.fromJson({...item, 'type': 'playlist'}));
          }
        }
        if (playlists.isNotEmpty) return playlists;
      }
    } catch (e) {
      debugPrint('[JioSaavnApiService] searchPlaylists error: $e');
    }
    final res = await searchAll(query);
    return res['playlists'] as List<Playlist>;
  }

  /// Search for albums on JioSaavn
  Future<List<Playlist>> searchAlbums(String query, {int page = 1, int count = 30}) async {
    try {
      final url = Uri.parse(
          '$_baseUrl?__call=search.getAlbumResults&_format=json&p=$page&n=$count&api_version=4&ctx=web6dot0&q=${Uri.encodeComponent(query)}');
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rawResults = data['results'] ?? data['albums'] ?? [];
        final List<Playlist> albums = [];
        if (rawResults is List) {
          for (var item in rawResults) {
            albums.add(Playlist.fromJson({...item, 'type': 'album'}));
          }
        }
        if (albums.isNotEmpty) return albums;
      }
    } catch (e) {
      debugPrint('[JioSaavnApiService] searchAlbums error: $e');
    }
    final res = await searchAll(query);
    return res['albums'] as List<Playlist>;
  }

  /// Get Homepage Data (Trending songs, charts, playlists)
  Future<Map<String, dynamic>> fetchHomepageData({Function(String message)? onError}) async {
    if (_homepageCache.isNotEmpty && DateTime.now().isBefore(_homepageCacheExpiry)) {
      return _homepageCache;
    }

    try {
      final url = Uri.parse(
          '$_baseUrl?__call=content.getHomepageData&_format=json&_marker=0&api_version=4&ctx=web6dot0&language=hindi,telugu,tamil,punjabi');

      final response = await http.get(url, headers: _headers);
      final List<Song> trendingSongs = [];
      final List<Playlist> playlists = [];

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // 1. Direct song items from new_albums or new_trending
        if (data['new_albums'] is List) {
          for (var item in data['new_albums']) {
            if (item['type'] == 'song' || item['song'] != null) {
              trendingSongs.add(Song.fromJson(item));
            } else {
              playlists.add(Playlist.fromJson({...item, 'type': 'album'}));
            }
          }
        }

        // 2. Playlists from charts & featured_playlists
        final playlistSources = [
          data['charts'],
          data['top_playlists'],
          data['featured_playlists'],
        ];

        for (var src in playlistSources) {
          if (src is List) {
            for (var item in src) {
              playlists.add(Playlist.fromJson(item));
            }
          }
        }

        // 3. Fetch details for first chart if trendingSongs is still empty
        if (trendingSongs.isEmpty && data['charts'] is List && (data['charts'] as List).isNotEmpty) {
          final chartId = data['charts'][0]['id'] ?? data['charts'][0]['listid'];
          if (chartId != null) {
            final chartData = await fetchPlaylistDetails(chartId.toString());
            trendingSongs.addAll(chartData['songs'] as List<Song>);
          }
        }
      }

      // Fallback: If JioSaavn homepage API returned empty trending list, fetch Trending Today playlist (110858205)
      if (trendingSongs.isEmpty) {
        final fallbackChart = await fetchPlaylistDetails('110858205');
        trendingSongs.addAll(fallbackChart['songs'] as List<Song>);
      }

      // Fallback 2: Search for top songs
      if (trendingSongs.isEmpty) {
        final fallbackSongs = await searchSongs('Arijit Singh');
        trendingSongs.addAll(fallbackSongs);
      }

      final result = {
        'trending': trendingSongs,
        'playlists': playlists,
      };

      _homepageCache.clear();
      _homepageCache.addAll(result);
      _homepageCacheExpiry = DateTime.now().add(_cacheDuration);
      return result;
    } catch (e) {
      debugPrint('[JioSaavnApiService] Homepage error: $e');
      // Emergency fallback
      final fallbackSongs = await searchSongs('Hindi');
      return {'trending': fallbackSongs, 'playlists': <Playlist>[]};
    }
  }

  /// Fetch playlist tracks
  Future<Map<String, dynamic>> fetchPlaylistDetails(String listId, {Function(String message)? onError}) async {
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
      _playlistCache[listId] = result;
      _playlistCacheExpiries[listId] = DateTime.now().add(_cacheDuration);
      return result;
    } catch (e) {
      debugPrint('[JioSaavnApiService] Playlist error for ID $listId: $e');
      return {'name': '', 'songs': <Song>[]};
    }
  }

  /// Fetch album tracks
  Future<Map<String, dynamic>> fetchAlbumDetails(String albumId, {Function(String message)? onError}) async {
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
      _albumCache[albumId] = result;
      _albumCacheExpiries[albumId] = DateTime.now().add(_cacheDuration);
      return result;
    } catch (e) {
      debugPrint('[JioSaavnApiService] Album error for ID $albumId: $e');
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
        }
      }

      if (encUrl == null || encUrl.isEmpty) {
        debugPrint('[JioSaavnApiService] No encrypted URL found for ${song.saavnId}');
        return null;
      }

      final decrypted = await DesDecryptor.decrypt(encUrl);
      if (decrypted == null) return null;



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
