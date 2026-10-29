import 'package:http/http.dart' as http;
import 'package:it_feels_music/core/utils/string_utils.dart';
import 'package:it_feels_music/core/utils/des_decryptor.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/models/cache_models.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/datasources/local_cache_data_source.dart';
import 'package:it_feels_music/data/services/addon_manager.dart';
import 'package:it_feels_music/services/database_service.dart';

abstract class IMusicRepository {
  Future<List<Song>> fetchRecommendations({String? songId, String? artist});
  Future<List<Song>> fetchArtistTopTracks(String artistId);
  Future<List<Song>> searchNativeCatalog(String query);
  Future<Map<String, dynamic>?> fetchNativeHomeFeed();
  Future<List<Song>> search(String query, {int page = 1, int limit = 20});
  Future<String?> getStreamUrl(Song song);
  Future<Map<String, dynamic>?> getLyrics(
    String track,
    String artist, {
    String? album,
    int? duration,
  });
  Future<Map<String, dynamic>?> executeAiAction(String prompt);
  Future<Map<String, dynamic>> getVideoStreams(
    String videoId, {
    String? query,
    bool bypassCache = false,
  });
  Future<List<Map<String, dynamic>>> searchVideos(String query);
  Future<List<Map<String, dynamic>>> getTrendingVideos({int limit = 20});
  Future<List<Map<String, dynamic>>> directInnerTubeVideoSearch(
    String query, {
    int limit = 20,
  });
  Future<List<Map<String, dynamic>>> getRelatedVideos(
    String videoId, {
    String? query,
  });
  Future<String?> getChannelAvatar(String channelId);

  // Fallback UI Methods (to replace deleted services)
  Future<Map<String, dynamic>> getPlaylistDetails(String token, {int? page, int? count});
  Future<Map<String, dynamic>> fetchPlaylistDetails(String token, {int? page, int? count});
  Future<Map<String, dynamic>> getAlbumDetails(String token);
  Future<Map<String, dynamic>> fetchAlbumDetails(String token);
  Future<List<Song>> searchSongs(String query, {int page = 1, int count = 20});
  Future<List<Song>> getTrending();
  Future<List<dynamic>> getTopArtists();
  Future<List<Song>> getPlaylistTracks(String id);
  Future<List<Song>> searchPodcasts(String query, {int count = 10});
  Future<String?> resolveStream(Song song);
  Future<List<Song>> getRecommendedSongs(Song song);
  Future<void> preloadStreamUrl(Song song);
  Future<Map<String, dynamic>> searchAll(String query);
  Future<Map<String, dynamic>> fetchArtistDetails(String token, {int? page, int? count});
  Future<List<Playlist>> searchAlbums(String query, {int? page, int? count});
  Future<List<Playlist>> searchPlaylists(String query, {int? page, int? count});
  Future<Song?> fetchSongDetails(String token);
  Future<List<Song>> getTopStations();
  Future<List<Song>> searchStations(String query);
  Future<Map<String, dynamic>> getCharts();
  Future<Map<String, dynamic>> getChartsByLanguage(String language);
  Future<List<Playlist>> getFeaturedPlaylistsByLanguage(String language);
  Future<Map<String, dynamic>> fetchHomepageData({Function(String)? onError});
}

class MusicRepository implements IMusicRepository {
  final LocalCacheDataSource cacheDataSource;
  final Map<String, String> _streamCache = {};

  MusicRepository({
    LocalCacheDataSource? cacheDataSource,
  })  : cacheDataSource = cacheDataSource ?? LocalCacheDataSource();

  static const List<String> _radioMirrors = [
    'https://de1.api.radio-browser.info/json',
    'https://nl1.api.radio-browser.info/json',
    'https://at1.api.radio-browser.info/json',
  ];

  static const Map<String, String> _radioHeaders = {
    'User-Agent': 'ITFeels/3.6.16 (https://github.com/Allrounder687/it-feels-android)',
    'Accept': 'application/json',
  };

  Song _mapRadioStationToSong(Map<String, dynamic> json) {
    String name = StringUtils.cleanText(json['name']?.toString() ?? 'Unknown Station');
    if (name.trim().isEmpty) name = 'Live Radio';

    String country = StringUtils.cleanText(json['country']?.toString() ?? 'Global Radio');
    String tags = json['tags']?.toString() ?? '';
    List<String> tagList = tags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    String genre = tagList.isNotEmpty ? tagList.first : 'Radio';

    String favicon = json['favicon']?.toString() ?? '';
    if (favicon.isEmpty) {
      favicon = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=random';
    }

    final streamUrl = json['url_resolved']?.toString() ?? json['url']?.toString() ?? '';

    return Song(
      id: 'radio:${json['stationuuid'] ?? json['changeuuid'] ?? name}',
      saavnId: '',
      title: name,
      artist: country,
      album: genre,
      duration: 0,
      coverArt: favicon,
      addedAt: DateTime.now(),
      genre: genre,
      encryptedMediaUrl: streamUrl,
    );
  }

  @override
  Future<List<Song>> getTopStations({int limit = 50}) async {
    for (final base in _radioMirrors) {
      try {
        final url = Uri.parse('$base/stations/topclick/$limit');
        final response = await http.get(url, headers: _radioHeaders).timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
          final stations = data.whereType<Map<String, dynamic>>().map(_mapRadioStationToSong).toList();
          if (stations.isNotEmpty) return stations;
        }
      } catch (e) {
        debugPrint('[MusicRepository] Top stations error from $base: $e');
      }
    }
    return [];
  }
  
  @override
  Future<List<Song>> searchStations(String query, {int limit = 40}) async {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) return getTopStations();

    for (final base in _radioMirrors) {
      try {
        final url = Uri.parse('$base/stations/search?name=${Uri.encodeComponent(cleanQ)}&limit=$limit');
        final response = await http.get(url, headers: _radioHeaders).timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
          List<Song> results = data.whereType<Map<String, dynamic>>().map(_mapRadioStationToSong).toList();
          
          if (results.length < 10) {
            try {
              final countryUrl = Uri.parse('$base/stations/bycountry/${Uri.encodeComponent(cleanQ)}?limit=$limit');
              final cResp = await http.get(countryUrl, headers: _radioHeaders).timeout(const Duration(seconds: 4));
              if (cResp.statusCode == 200) {
                final List<dynamic> cData = jsonDecode(utf8.decode(cResp.bodyBytes));
                final seen = results.map((s) => s.id).toSet();
                for (final item in cData.whereType<Map<String, dynamic>>()) {
                  final s = _mapRadioStationToSong(item);
                  if (seen.add(s.id)) {
                    results.add(s);
                  }
                }
              }
            } catch (_) {}

            try {
              final tagUrl = Uri.parse('$base/stations/bytag/${Uri.encodeComponent(cleanQ)}?limit=$limit');
              final tResp = await http.get(tagUrl, headers: _radioHeaders).timeout(const Duration(seconds: 4));
              if (tResp.statusCode == 200) {
                final List<dynamic> tData = jsonDecode(utf8.decode(tResp.bodyBytes));
                final seen = results.map((s) => s.id).toSet();
                for (final item in tData.whereType<Map<String, dynamic>>()) {
                  final s = _mapRadioStationToSong(item);
                  if (seen.add(s.id)) {
                    results.add(s);
                  }
                }
              }
            } catch (_) {}
          }

          if (results.isNotEmpty) return results;
        }
      } catch (e) {
        debugPrint('[MusicRepository] Search stations error from $base: $e');
      }
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>> getCharts() async {
    final addonManager = AddonManager();
    return await addonManager.getCharts();
  }

  @override
  Future<Map<String, dynamic>> getChartsByLanguage(String language) async {
    final addonManager = AddonManager();
    return await addonManager.getChartsByLanguage(language);
  }

  @override
  Future<List<Playlist>> getFeaturedPlaylistsByLanguage(String language) async {
    final addonManager = AddonManager();
    return await addonManager.getFeaturedPlaylistsByLanguage(language);
  }

  @override
  Future<Map<String, dynamic>> fetchHomepageData({Function(String)? onError}) async {
    final addonData = await AddonManager().getHomeFeed();
    if (addonData != null) return addonData;
    
    final cached = await cacheDataSource.getCachedHomeFeed();
    return cached ?? {};
  }

  @override
  Future<Map<String, dynamic>> getPlaylistDetails(String token, {int? page, int? count}) async {
    final songs = await getPlaylistTracks(token);
    return {'songs': songs};
  }

  @override
  Future<Map<String, dynamic>> fetchPlaylistDetails(String token, {int? page, int? count}) async {
    final songs = await getPlaylistTracks(token);
    return {'songs': songs};
  }

  @override
  Future<Map<String, dynamic>> getAlbumDetails(String token) async {
    final songs = await getAlbumTracks(token);
    return {'songs': songs};
  }
  
  @override
  Future<Map<String, dynamic>> fetchAlbumDetails(String token) async {
    final songs = await getAlbumTracks(token);
    return {'songs': songs};
  }

  Future<List<Song>> getAlbumTracks(String id) async {
    final addonManager = AddonManager();
    return await addonManager.getAlbumTracks(id);
  }

  @override
  Future<List<Song>> searchSongs(String query, {int page = 1, int count = 20}) async {
    return search(query, page: page, limit: count);
  }

  @override
  Future<List<Song>> getTrending() async => [];

  @override
  Future<List<dynamic>> getTopArtists() async => [];

  @override
  Future<List<Song>> getPlaylistTracks(String id) async {
    final addonManager = AddonManager();
    return await addonManager.getPlaylistTracks(id);
  }

  @override
  Future<List<Song>> searchPodcasts(String query, {int count = 10}) async {
    final queryKey = 'search_podcasts_v2_$query';
    final cached = await locator<DatabaseService>().getCachedSearch(queryKey);
    if (cached != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(cached.responseJson);
        return jsonList.map((e) => Song.fromJson(e as Map<String, dynamic>)).take(count).toList();
      } catch (e) {
        debugPrint('[MusicRepository] Failed to parse cached podcasts: $e');
      }
    }

    final addonManager = AddonManager();
    final results = await addonManager.searchPodcasts(query);
    
    if (results.isNotEmpty) {
      final cacheObj = CachedSearch()
        ..queryKey = queryKey
        ..responseJson = jsonEncode(results.map((s) => s.toJson()).toList())
        ..cachedAt = DateTime.now()
        ..expiryTime = DateTime.now().add(const Duration(hours: 24));
      await locator<DatabaseService>().saveCachedSearch(cacheObj);
    }
    
    return results.take(count).toList();
  }

  @override
  Future<String?> resolveStream(Song song) async => null;

  @override
  Future<List<Song>> getRecommendedSongs(Song song) async {
    List<Song> recommendations = [];

    // 1. Try JioSaavn direct song recommendations API (song station)
    if (song.saavnId.isNotEmpty) {
      try {
        final recoUrl = 'https://www.jiosaavn.com/api.php?__call=reco.getrecos&_format=json&_marker=0&api_version=4&ctx=web6dot0&pid=${Uri.encodeComponent(song.saavnId)}';
        final response = await http.get(Uri.parse(recoUrl)).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final rawList = data is List ? data : (data['list'] ?? data['songs']);
          if (rawList is List && rawList.isNotEmpty) {
            for (final item in rawList) {
              if (item is Map<String, dynamic>) {
                final s = Song.fromJson(item);
                // Filter out current song & instrumental/karaoke noise
                final tLower = s.title.toLowerCase();
                if (s.id != song.id &&
                    !tLower.contains('instrumental') &&
                    !tLower.contains('karaoke') &&
                    !tLower.contains('ringtone')) {
                  recommendations.add(s);
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[MusicRepository] reco.getrecos error: $e');
      }
    }

    // 2. If recommendations are still empty, search artist top hits
    if (recommendations.isEmpty) {
      final artist = song.artist.split(',').first.split('-').first.trim();
      if (artist.isNotEmpty && artist != 'Unknown Artist') {
        final artistHits = await searchSongs('$artist Hits', count: 20);
        for (final s in artistHits) {
          final tLower = s.title.toLowerCase();
          if (s.id != song.id &&
              !tLower.contains('instrumental') &&
              !tLower.contains('karaoke') &&
              !tLower.contains('ringtone')) {
            recommendations.add(s);
          }
        }
      }
    }

    return recommendations.take(15).toList();
  }

  @override
  Future<Map<String, dynamic>> searchAll(String query) async {
    final addonManager = AddonManager();
    
    // 1. Fetch autocomplete all-in-one results (songs, albums, playlists, artists)
    final autoData = await addonManager.searchAll(query);
    List<Song> songs = List<Song>.from(autoData['songs'] ?? []);
    List<Playlist> albums = List<Playlist>.from(autoData['albums'] ?? []);
    List<Playlist> playlists = List<Playlist>.from(autoData['playlists'] ?? []);
    List<Map<String, dynamic>> artists = List<Map<String, dynamic>>.from(autoData['artists'] ?? []);

    // 2. Fetch direct song results if autocomplete songs are limited
    final directSongs = await searchSongs(query, count: 30);
    final existingSongIds = songs.map((s) => s.id).toSet();
    for (final s in directSongs) {
      if (!existingSongIds.contains(s.id)) {
        songs.add(s);
        existingSongIds.add(s.id);
      }
    }

    // 3. Fetch direct album results to ensure albums tab is richly populated
    if (albums.length < 10) {
      final directAlbums = await searchAlbums(query, count: 20);
      final existingAlbumIds = albums.map((a) => a.id).toSet();
      for (final a in directAlbums) {
        if (!existingAlbumIds.contains(a.id)) {
          albums.add(a);
          existingAlbumIds.add(a.id);
        }
      }
    }

    // 4. Fetch direct playlists if needed
    if (playlists.length < 10) {
      final directPlaylists = await searchPlaylists(query, count: 20);
      final existingPlaylistIds = playlists.map((p) => p.id).toSet();
      for (final p in directPlaylists) {
        if (!existingPlaylistIds.contains(p.id) && p.type.toLowerCase() != 'album') {
          playlists.add(p);
          existingPlaylistIds.add(p.id);
        }
      }
    }

    return {
      'songs': songs,
      'albums': albums,
      'playlists': playlists,
      'artists': artists,
    };
  }

  @override
  Future<Map<String, dynamic>> fetchArtistDetails(String token, {int? page, int? count}) async {
    final addonManager = AddonManager();
    final artistData = await addonManager.getArtistDetails(token);
    
    final topSongs = List<Song>.from(artistData['topSongs'] ?? []);
    final albums = List<Playlist>.from(artistData['albums'] ?? []);

    if (topSongs.isNotEmpty || albums.isNotEmpty) {
      return {
        'topSongs': topSongs,
        'albums': albums,
        'image': artistData['image'],
        'name': artistData['name'],
        'bio': artistData['bio'],
      };
    }

    // Fallback: If token was an artist name rather than an ID, search by text
    final fallbackSongs = await searchSongs(token, count: 30);
    final fallbackAlbums = await searchAlbums(token, count: 10);
    return {
      'topSongs': fallbackSongs,
      'albums': fallbackAlbums,
    };
  }

  @override
  Future<List<Playlist>> searchAlbums(String query, {int? page, int? count}) async {
    final queryKey = 'search_albums_v2_$query';
    final cached = await locator<DatabaseService>().getCachedSearch(queryKey);
    if (cached != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(cached.responseJson);
        final results = jsonList.map((e) => Playlist.fromJson(e as Map<String, dynamic>)).toList();
        if (count != null) return results.take(count).toList();
        return results;
      } catch (e) {
        debugPrint('[MusicRepository] Failed to parse cached albums: $e');
      }
    }

    final addonManager = AddonManager();
    var results = await addonManager.searchAlbums(query);
    
    // Fallback if specific album endpoint returned empty
    if (results.isEmpty) {
      final cleanQuery = query.trim();
      final searchParam = cleanQuery.toLowerCase().endsWith('album') || cleanQuery.toLowerCase().endsWith('albums')
          ? cleanQuery
          : '$cleanQuery Albums';
      final playlistResults = await addonManager.searchPlaylists(searchParam);
      results = playlistResults.where((p) => p.type.toLowerCase() == 'album').toList();
      if (results.isEmpty) {
        results = playlistResults;
      }
    }

    if (results.isNotEmpty) {
      final cacheObj = CachedSearch()
        ..queryKey = queryKey
        ..responseJson = jsonEncode(results.map((p) => p.toJson()).toList())
        ..cachedAt = DateTime.now()
        ..expiryTime = DateTime.now().add(const Duration(hours: 24));
      await locator<DatabaseService>().saveCachedSearch(cacheObj);
    }

    if (count != null) {
      return results.take(count).toList();
    }
    return results;
  }

  @override
  Future<List<Playlist>> searchPlaylists(String query, {int? page, int? count}) async {
    final queryKey = 'search_playlists_v2_$query';
    final cached = await locator<DatabaseService>().getCachedSearch(queryKey);
    if (cached != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(cached.responseJson);
        final results = jsonList.map((e) => Playlist.fromJson(e as Map<String, dynamic>)).toList();
        if (count != null) return results.take(count).toList();
        return results;
      } catch (e) {
        debugPrint('[MusicRepository] Failed to parse cached playlists: $e');
      }
    }

    final addonManager = AddonManager();
    final results = await addonManager.searchPlaylists(query);
    
    if (results.isNotEmpty) {
      final cacheObj = CachedSearch()
        ..queryKey = queryKey
        ..responseJson = jsonEncode(results.map((p) => p.toJson()).toList())
        ..cachedAt = DateTime.now()
        ..expiryTime = DateTime.now().add(const Duration(hours: 24));
      await locator<DatabaseService>().saveCachedSearch(cacheObj);
    }

    if (count != null) {
      return results.take(count).toList();
    }
    return results;
  }

  @override
  Future<Song?> fetchSongDetails(String token) async => null;

  @override
  Future<List<Song>> fetchRecommendations({String? songId, String? artist}) async {
    if (artist != null && artist.isNotEmpty && artist != 'Unknown Artist') {
      return await searchSongs(artist.split(',').first.trim(), count: 15);
    }
    return [];
  }

  @override
  Future<List<Song>> fetchArtistTopTracks(String artistId) async {
    final details = await fetchArtistDetails(artistId);
    final songs = details['topSongs'] as List<Song>?;
    if (songs != null && songs.isNotEmpty) {
      return songs;
    }
    return await searchSongs(artistId, count: 25);
  }

  @override
  Future<List<Song>> searchNativeCatalog(String query) async {
    final cached = await cacheDataSource.getCachedSearchResults(query);
    return cached ?? [];
  }

  @override
  Future<Map<String, dynamic>?> fetchNativeHomeFeed() async {
    return cacheDataSource.getCachedHomeFeed();
  }

  @override
  Future<List<Song>> search(String query, {int page = 1, int limit = 20}) async {
    final queryKey = 'search_songs_v2_$query';
    final cached = await locator<DatabaseService>().getCachedSearch(queryKey);
    if (cached != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(cached.responseJson);
        return jsonList.map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('[MusicRepository] Failed to parse cached search songs: $e');
      }
    }

    final addonManager = AddonManager();
    final addonResults = await addonManager.search(query);
    if (addonResults.isNotEmpty) {
      final cacheObj = CachedSearch()
        ..queryKey = queryKey
        ..responseJson = jsonEncode(addonResults.map((s) => s.toJson()).toList())
        ..cachedAt = DateTime.now()
        ..expiryTime = DateTime.now().add(const Duration(hours: 24));
      await locator<DatabaseService>().saveCachedSearch(cacheObj);
    }
    return addonResults;
  }

  @override
  Future<void> preloadStreamUrl(Song song) async {
    if (_streamCache.containsKey(song.id)) return;
    try {
      final url = await getStreamUrl(song);
      if (url != null && url.isNotEmpty) {
        _streamCache[song.id] = url;
      }
    } catch (_) {}
  }

  @override
  Future<String?> getStreamUrl(Song song) async {
    // 0. Radio station direct stream
    if (song.id.startsWith('radio:') && song.encryptedMediaUrl != null && song.encryptedMediaUrl!.isNotEmpty) {
      return song.encryptedMediaUrl;
    }

    // 1. Direct streamUrl if present
    if (song.streamUrl != null && song.streamUrl!.isNotEmpty) {
      return song.streamUrl;
    }

    // 2. If song has a local downloaded file path, return it directly for instant offline playback
    if (song.encryptedMediaUrl != null && song.encryptedMediaUrl!.isNotEmpty) {
      if (!song.encryptedMediaUrl!.startsWith('http://') && !song.encryptedMediaUrl!.startsWith('https://')) {
        try {
          final localFile = File(song.encryptedMediaUrl!);
          if (await localFile.exists()) {
            return localFile.path;
          }
        } catch (_) {}

        // 3. Instant TripleDES decryption for JioSaavn media
        try {
          final decryptedUrl = await DesDecryptor.decrypt(song.encryptedMediaUrl!);
          if (decryptedUrl != null && decryptedUrl.isNotEmpty) {
            _streamCache[song.id] = decryptedUrl;
            return decryptedUrl;
          }
        } catch (_) {}
      }
    }

    if (_streamCache.containsKey(song.id)) {
      return _streamCache[song.id];
    }
    final addonManager = AddonManager();
    final addonStream = await addonManager.getStreamUrl(song);
    if (addonStream != null && addonStream.isNotEmpty) {
      _streamCache[song.id] = addonStream;
      return addonStream;
    }

    // Strict Legal Compliance: The app relies exclusively on Addons.
    return null;
  }

  @override
  Future<Map<String, dynamic>?> getLyrics(
    String track,
    String artist, {
    String? album,
    int? duration,
  }) async {
    final addonManager = AddonManager();
    return await addonManager.getLyrics(track, artist, album: album, duration: duration);
  }

  @override
  Future<Map<String, dynamic>?> executeAiAction(String prompt) async {
    return null;
  }

  @override
  Future<Map<String, dynamic>> getVideoStreams(
    String videoId, {
    String? query,
    bool bypassCache = false,
  }) async {
    return await AddonManager().getVideoStreams(videoId, query);
  }

  @override
  Future<List<Map<String, dynamic>>> searchVideos(String query) async {
    return await AddonManager().searchVideos(query);
  }

  @override
  Future<List<Map<String, dynamic>>> getTrendingVideos({int limit = 20}) async {
    return await AddonManager().getTrendingVideos();
  }

  @override
  Future<List<Map<String, dynamic>>> directInnerTubeVideoSearch(
    String query, {
    int limit = 20,
  }) async {
    return await AddonManager().searchVideos(query);
  }

  @override
  Future<List<Map<String, dynamic>>> getRelatedVideos(
    String videoId, {
    String? query,
  }) async {
    return [];
  }

  @override
  Future<String?> getChannelAvatar(String channelId) async {
    return null;
  }
}
