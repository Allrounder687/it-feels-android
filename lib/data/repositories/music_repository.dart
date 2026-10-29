import 'dart:async';
import 'dart:convert';
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
  Future<Map<String, dynamic>> fetchHomepageData({Function(String)? onError});
}

class MusicRepository implements IMusicRepository {
  final LocalCacheDataSource cacheDataSource;

  MusicRepository({
    LocalCacheDataSource? cacheDataSource,
  })  : cacheDataSource = cacheDataSource ?? LocalCacheDataSource();

  @override
  Future<List<Song>> getTopStations() async => [];
  
  @override
  Future<List<Song>> searchStations(String query) async => [];

  @override
  Future<Map<String, dynamic>> getCharts() async {
    final addonManager = AddonManager();
    return await addonManager.getCharts();
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
    final artist = song.artist.split(',').first.split('-').first.trim();
    if (artist.isNotEmpty && artist != 'Unknown Artist') {
      return await searchSongs(artist, count: 15);
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>> searchAll(String query) async {
    final songs = await searchSongs(query, count: 30);
    final playlists = await searchPlaylists(query, count: 20);

    final albums = playlists.where((p) => p.type.toLowerCase() == 'album').toList();
    final regularPlaylists = playlists.where((p) => p.type.toLowerCase() != 'album').toList();

    List<Playlist> finalAlbums = albums;
    if (finalAlbums.isEmpty && query.isNotEmpty) {
      final queryAlbums = await searchPlaylists('$query Album', count: 10);
      finalAlbums = queryAlbums;
    }

    return {
      'songs': songs,
      'albums': finalAlbums,
      'playlists': regularPlaylists.isNotEmpty ? regularPlaylists : playlists,
      'artists': <Map<String, dynamic>>[],
    };
  }

  @override
  Future<Map<String, dynamic>> fetchArtistDetails(String token, {int? page, int? count}) async {
    final songs = await searchSongs(token, count: 30);
    final albums = await searchAlbums(token, count: 10);
    return {
      'topSongs': songs,
      'albums': albums,
    };
  }

  @override
  Future<List<Playlist>> searchAlbums(String query, {int? page, int? count}) async {
    final cleanQuery = query.trim();
    final searchParam = cleanQuery.toLowerCase().endsWith('album') || cleanQuery.toLowerCase().endsWith('albums')
        ? cleanQuery
        : '$cleanQuery Albums';
    final results = await searchPlaylists(searchParam, page: page, count: count);
    if (results.isNotEmpty) return results;
    return await searchPlaylists(cleanQuery, page: page, count: count);
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
      return addonResults;
    }
    
    // Strict Legal Compliance: The app no longer falls back to any hardcoded
    // scraping logic. It relies exclusively on Addons.
    return [];
  }

  final Map<String, String> _streamCache = {};

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
