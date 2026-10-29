import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/services/local_proxy_server.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class AddonManager {
  static final AddonManager _instance = AddonManager._internal();
  factory AddonManager() => _instance;
  AddonManager._internal();

  final List<JavascriptRuntime> _activeRuntimes = [];

  bool get hasPlugins => _activeRuntimes.isNotEmpty;
  
  final ValueNotifier<bool> hasPluginsNotifier = ValueNotifier(false);

  Future<void> initialize() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final pluginsDir = Directory('${dir.path}/plugins');
      if (!await pluginsDir.exists()) {
        await pluginsDir.create();
      }

      final files = pluginsDir.listSync().where((f) => f.path.endsWith('.js')).toList();
      for (var file in files) {
        await _loadPlugin(file);
      }
      hasPluginsNotifier.value = _activeRuntimes.isNotEmpty;
    } catch (e) {
      debugPrint('[AddonManager] Init error: $e');
    }
  }

  Future<bool> installDefaultPlugin() async {
    final defaultPluginUrl = "https://raw.githubusercontent.com/Allrounder687/it-feels-provider-backend/main/backend_addon.js";
    return await installPluginFromUrl(defaultPluginUrl, "default_backend.js");
  }

  Future<bool> installPluginFromUrl(String url, String filename) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final pluginsDir = Directory('${dir.path}/plugins');
        if (!await pluginsDir.exists()) {
          await pluginsDir.create();
        }
        
        String safeName = filename.endsWith('.js') ? filename : '$filename.js';
        final file = File('${pluginsDir.path}/$safeName');
        await file.writeAsString(response.body);
        
        await _loadPlugin(file);
        hasPluginsNotifier.value = _activeRuntimes.isNotEmpty;
        return true;
      }
    } catch (e) {
      debugPrint('[AddonManager] Error installing plugin from URL: $e');
    }
    return false;
  }

  Future<void> uninstallAllPlugins() async {
    _activeRuntimes.clear();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final pluginsDir = Directory('${dir.path}/plugins');
      if (await pluginsDir.exists()) {
        final files = pluginsDir.listSync().where((f) => f.path.endsWith('.js'));
        for (var file in files) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('[AddonManager] Error uninstalling plugins: $e');
    }
    hasPluginsNotifier.value = false;
  }

  Future<void> _loadPlugin(FileSystemEntity file) async {
    try {
      String source = await File(file.path).readAsString();

      // Polyfill for missing playlist/album fetchers in older backend_addon.js
      if (!source.contains('getPlaylistTracksUrl') && source.contains('BACKEND_URL')) {
        source += '''
          
          function getPlaylistTracksUrl(id) {
              return BACKEND_URL + "/api/v1/playlist?id=" + encodeURIComponent(id);
          }
          function getAlbumTracksUrl(id) {
              return BACKEND_URL + "/api/v1/album?id=" + encodeURIComponent(id);
          }
        ''';
      }

      final JavascriptRuntime runtime = getJavascriptRuntime();
      
      runtime.evaluate(source);
      _activeRuntimes.add(runtime);
      debugPrint('[AddonManager] Loaded plugin: ${file.path}');
    } catch (e) {
      debugPrint('[AddonManager] Error loading plugin ${file.path}: $e');
    }
  }

  Future<List<Song>> search(String query) async {
    List<Song> allResults = [];
    for (var runtime in _activeRuntimes) {
      try {
        final jsResult = runtime.evaluate("typeof getSearchUrl === 'function' ? getSearchUrl('${query.replaceAll("'", "\\'")}') : null");
        final searchUrl = jsResult.stringResult.replaceAll('"', '');
        
        if (searchUrl != 'null' && searchUrl.isNotEmpty) {
          debugPrint('[AddonManager] Fetching search from: $searchUrl');
          final response = await http.get(Uri.parse(searchUrl));
          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            if (data['success'] == true && data['results'] != null) {
              for (var item in data['results']) {
                allResults.add(Song.fromJson(item));
              }
            }
          } else {
            debugPrint('[AddonManager] Search failed with status: ${response.statusCode} from $searchUrl');
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] Search error in plugin: $e');
      }
    }
    return allResults;
  }

  Future<List<Playlist>> searchPlaylists(String query) async {
    List<Playlist> allResults = [];
    for (var runtime in _activeRuntimes) {
      try {
        final jsResult = runtime.evaluate("typeof getSearchPlaylistsUrl === 'function' ? getSearchPlaylistsUrl('${query.replaceAll("'", "\\'")}') : null");
        final searchUrl = jsResult.stringResult.replaceAll('"', '');
        
        if (searchUrl != 'null' && searchUrl.isNotEmpty) {
          debugPrint('[AddonManager] Fetching searchPlaylists from: $searchUrl');
          final response = await http.get(Uri.parse(searchUrl));
          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            if (data['success'] == true && data['results'] != null) {
              for (var item in data['results']) {
                allResults.add(Playlist(
                  id: item['id']?.toString() ?? '',
                  title: item['title']?.toString() ?? '',
                  type: item['type']?.toString() ?? 'playlist',
                  coverArt: item['image']?.toString() ?? item['coverArt']?.toString() ?? '',
                  songCount: int.tryParse(item['songCount']?.toString() ?? '0') ?? 0,
                  songs: [],
                ));
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] searchPlaylists error in plugin: $e');
      }
    }
    return allResults;
  }

  Future<List<Song>> getPlaylistTracks(String id) async {
    List<Song> allResults = [];
    for (var runtime in _activeRuntimes) {
      try {
        final jsResult = runtime.evaluate("typeof getPlaylistTracksUrl === 'function' ? getPlaylistTracksUrl('${id.replaceAll("'", "\\'")}') : null");
        final searchUrl = jsResult.stringResult.replaceAll('"', '');
        
        if (searchUrl != 'null' && searchUrl.isNotEmpty) {
          debugPrint('[AddonManager] Fetching playlist tracks from: $searchUrl');
          final response = await http.get(Uri.parse(searchUrl));
          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            if (data['success'] == true && data['tracks'] != null) {
              for (var item in data['tracks']) {
                allResults.add(Song.fromJson(item));
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] getPlaylistTracks error in plugin: $e');
      }
    }
    return allResults;
  }

  Future<List<Song>> getAlbumTracks(String id) async {
    List<Song> allResults = [];
    for (var runtime in _activeRuntimes) {
      try {
        final jsResult = runtime.evaluate("typeof getAlbumTracksUrl === 'function' ? getAlbumTracksUrl('${id.replaceAll("'", "\\'")}') : null");
        final searchUrl = jsResult.stringResult.replaceAll('"', '');
        
        if (searchUrl != 'null' && searchUrl.isNotEmpty) {
          debugPrint('[AddonManager] Fetching album tracks from: $searchUrl');
          final response = await http.get(Uri.parse(searchUrl));
          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            if (data['success'] == true && data['tracks'] != null) {
              for (var item in data['tracks']) {
                allResults.add(Song.fromJson(item));
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] getAlbumTracks error in plugin: $e');
      }
    }
    return allResults;
  }

  Future<List<Song>> searchPodcasts(String query) async {
    List<Song> allResults = [];
    for (var runtime in _activeRuntimes) {
      try {
        final jsResult = runtime.evaluate("typeof getSearchPodcastsUrl === 'function' ? getSearchPodcastsUrl('${query.replaceAll("'", "\\'")}') : null");
        final searchUrl = jsResult.stringResult.replaceAll('"', '');
        
        if (searchUrl != 'null' && searchUrl.isNotEmpty) {
          debugPrint('[AddonManager] Fetching searchPodcasts from: $searchUrl');
          final response = await http.get(Uri.parse(searchUrl));
          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            if (data['success'] == true && data['results'] != null) {
              for (var item in data['results']) {
                allResults.add(Song.fromJson(item));
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] searchPodcasts error in plugin: $e');
      }
    }
    return allResults;
  }

  Future<List<Map<String, dynamic>>> searchVideos(String query) async {
    List<Map<String, dynamic>> allResults = [];
    for (var runtime in _activeRuntimes) {
      try {
        final jsResult = runtime.evaluate("typeof getSearchVideosUrl === 'function' ? getSearchVideosUrl('${query.replaceAll("'", "\\'")}') : null");
        final searchUrl = jsResult.stringResult.replaceAll('"', '');
        
        if (searchUrl != 'null' && searchUrl.isNotEmpty) {
          debugPrint('[AddonManager] Fetching searchVideos from: $searchUrl');
          final response = await http.get(Uri.parse(searchUrl));
          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            if (data['success'] == true && data['results'] != null) {
              allResults = List<Map<String, dynamic>>.from(data['results']);
            }
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] searchVideos error in plugin: $e');
      }
    }
    return allResults;
  }

  Future<List<Map<String, dynamic>>> getTrendingVideos() async {
    List<Map<String, dynamic>> allResults = [];
    for (var runtime in _activeRuntimes) {
      try {
        final jsResult = runtime.evaluate("typeof getTrendingVideosUrl === 'function' ? getTrendingVideosUrl() : null");
        final searchUrl = jsResult.stringResult.replaceAll('"', '');
        
        if (searchUrl != 'null' && searchUrl.isNotEmpty) {
          debugPrint('[AddonManager] Fetching trendingVideos from: $searchUrl');
          final response = await http.get(Uri.parse(searchUrl));
          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            if (data['success'] == true && data['results'] != null) {
              allResults = List<Map<String, dynamic>>.from(data['results']);
            }
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] trendingVideos error in plugin: $e');
      }
    }
    return allResults;
  }

  Future<Map<String, dynamic>> getCharts() async {
    Map<String, dynamic> allResults = {'tracks': <Song>[], 'playlists': <Playlist>[]};
    for (var runtime in _activeRuntimes) {
      try {
        final jsResult = runtime.evaluate("typeof getChartsUrl === 'function' ? getChartsUrl() : null");
        final url = jsResult.stringResult.replaceAll('"', '');
        
        if (url != 'null' && url.isNotEmpty) {
          debugPrint('[AddonManager] Fetching charts from: $url');
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            if (data['success'] == true && data['data'] != null) {
              final tracks = (data['data']['tracks'] as List? ?? []).map((e) => Song.fromJson(e)).toList();
              final playlists = (data['data']['playlists'] as List? ?? []).map((e) => Playlist.fromJson(e)).toList();
              allResults = {'tracks': tracks, 'playlists': playlists};
            }
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] getCharts error in plugin: $e');
      }
    }
    return allResults;
  }

  Future<String?> getStreamUrl(Song song) async {
    for (var runtime in _activeRuntimes) {
      try {
        final artistStr = song.artist == 'Unknown Artist' ? '' : song.artist;
        final query = '${song.title} $artistStr'.trim().replaceAll("'", "\\'");
        final jsResult = runtime.evaluate("typeof getStreamUrl === 'function' ? getStreamUrl('${song.id.replaceAll("'", "\\'")}', '$query') : null");
        final streamApiUrl = jsResult.stringResult.replaceAll('"', '');
        
        if (streamApiUrl != 'null' && streamApiUrl.isNotEmpty) {
          debugPrint('[AddonManager] Fetching stream from: $streamApiUrl');
          final response = await http.get(Uri.parse(streamApiUrl));
          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            if (data['success'] == true && data['audioUrl'] != null) {
              return LocalProxyServer.getProxyUrl(data['audioUrl']);
            }
          } else {
            debugPrint('[AddonManager] Stream failed with status: ${response.statusCode} from $streamApiUrl');
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] getStreamUrl error in plugin: $e');
      }
    }
    return null;
  }
  
  Future<Map<String, dynamic>> getVideoStreams(String videoId, String? query) async {
    for (var runtime in _activeRuntimes) {
      try {
        final safeQuery = query?.replaceAll("'", "\\'") ?? '';
        final jsResult = runtime.evaluate("typeof getStreamUrl === 'function' ? getStreamUrl('${videoId.replaceAll("'", "\\'")}', '$safeQuery') : null");
        final streamApiUrl = jsResult.stringResult.replaceAll('"', '');
        
        if (streamApiUrl != 'null' && streamApiUrl.isNotEmpty) {
          debugPrint('[AddonManager] Fetching video streams from: $streamApiUrl');
          final response = await http.get(Uri.parse(streamApiUrl));
          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            if (data['success'] == true && data['streams'] != null) {
              return data;
            }
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] getVideoStreams error in plugin: $e');
      }
    }
    return {'success': false, 'streams': []};
  }

  Future<Map<String, dynamic>?> getHomeFeed() async {
    for (var runtime in _activeRuntimes) {
      try {
        final jsResult = runtime.evaluate("typeof getHomeFeedUrl === 'function' ? getHomeFeedUrl() : null");
        final homeUrl = jsResult.stringResult.replaceAll('"', '');

        if (homeUrl != 'null' && homeUrl.isNotEmpty) {
          debugPrint('[AddonManager] Fetching home feed from: $homeUrl');
          final response = await http.get(Uri.parse(homeUrl));
          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            if (data['success'] == true && data['data'] != null) {
              return data['data']; 
            }
          } else {
            debugPrint('[AddonManager] HomeFeed failed with status: ${response.statusCode} from $homeUrl');
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] HomeFeed error in plugin: $e');
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> getLyrics(String track, String artist, {String? album, int? duration}) async {
    for (var runtime in _activeRuntimes) {
      try {
        final jsResult = runtime.evaluate("typeof getLyricsUrl === 'function' ? getLyricsUrl('${track.replaceAll("'", "\\'")}', '${artist.replaceAll("'", "\\'")}') : null");
        final url = jsResult.stringResult.replaceAll('"', '');
        
        if (url != 'null' && url.isNotEmpty) {
          debugPrint('[AddonManager] Fetching lyrics from: $url');
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            if (data['success'] == true) {
              return data['lyrics'];
            }
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] getLyrics error in plugin: $e');
      }
    }
    return null;
  }
}
