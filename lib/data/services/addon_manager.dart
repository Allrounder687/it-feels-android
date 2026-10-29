import 'package:it_feels_music/core/utils/string_utils.dart';
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

  final Map<String, JavascriptRuntime> _activeRuntimesMap = {};

  List<JavascriptRuntime> get _activeRuntimes => _activeRuntimesMap.values.toList();

  bool get hasPlugins => _activeRuntimesMap.isNotEmpty;
  
  final ValueNotifier<bool> hasPluginsNotifier = ValueNotifier(false);

  static const String defaultPluginSource = '''
const BACKEND_URL = "https://it-feels-backend.cleverfox687.workers.dev";

function getSearchUrl(query) {
    return BACKEND_URL + "/api/v1/search?query=" + encodeURIComponent(query);
}

function getSearchPlaylistsUrl(query) {
    return "https://www.jiosaavn.com/api.php?__call=search.getPlaylistResults&_format=json&_marker=0&api_version=4&p=1&n=20&q=" + encodeURIComponent(query);
}

function getSearchAlbumsUrl(query) {
    return "https://www.jiosaavn.com/api.php?__call=search.getAlbumResults&_format=json&_marker=0&api_version=4&p=1&n=20&q=" + encodeURIComponent(query);
}

function getSearchAllUrl(query) {
    return "https://www.jiosaavn.com/api.php?__call=autocomplete.get&_format=json&_marker=0&api_version=4&ctx=web6dot0&query=" + encodeURIComponent(query);
}

function getArtistDetailsUrl(id) {
    return "https://www.jiosaavn.com/api.php?__call=artist.getArtistPageDetails&_format=json&_marker=0&api_version=4&artistId=" + encodeURIComponent(id);
}

function getPlaylistTracksUrl(id) {
    return "https://www.jiosaavn.com/api.php?__call=playlist.getDetails&_format=json&cc=in&_marker=0&api_version=4&ctx=web6dot0&listid=" + encodeURIComponent(id);
}

function getAlbumTracksUrl(id) {
    return "https://www.jiosaavn.com/api.php?__call=content.getAlbumDetails&_format=json&_marker=0&api_version=4&albumid=" + encodeURIComponent(id);
}

function getSearchPodcastsUrl(query) {
    return BACKEND_URL + "/api/v1/search/podcasts?query=" + encodeURIComponent(query);
}

function getStreamUrl(id, query) {
    if (query) {
        return BACKEND_URL + "/api/v1/video/stream?id=" + encodeURIComponent(id) + "&query=" + encodeURIComponent(query);
    }
    return BACKEND_URL + "/api/v1/video/stream?id=" + encodeURIComponent("search:" + id);
}

function getHomeFeedUrl() {
    return BACKEND_URL + "/api/v1/home";
}

function getChartsUrl() {
    return BACKEND_URL + "/api/v1/charts/trending";
}

function getLyricsUrl(track, artist) {
    return BACKEND_URL + "/api/v1/lyrics?track=" + encodeURIComponent(track) + "&artist=" + encodeURIComponent(artist);
}
''';

  Future<void> initialize() async {
    try {
      _activeRuntimesMap.clear();

      final dir = await getApplicationDocumentsDirectory();
      final pluginsDir = Directory('${dir.path}/plugins');
      if (!await pluginsDir.exists()) {
        await pluginsDir.create(recursive: true);
      }

      var files = pluginsDir.listSync().where((f) => f.path.endsWith('.js')).toList();
      if (files.isEmpty) {
        // Automatically install default plugin so user never experiences an empty app
        await installDefaultPlugin();
        files = pluginsDir.listSync().where((f) => f.path.endsWith('.js')).toList();
      }

      for (var file in files) {
        await _loadPlugin(file);
      }

      // If no valid plugins could be loaded from disk, provide fallback baseline runtime
      if (_activeRuntimesMap.isEmpty) {
        _loadBaselineRuntime();
      }

      hasPluginsNotifier.value = _activeRuntimesMap.isNotEmpty;
    } catch (e) {
      debugPrint('[AddonManager] Init error: $e');
      if (_activeRuntimesMap.isEmpty) {
        _loadBaselineRuntime();
      }
      hasPluginsNotifier.value = _activeRuntimesMap.isNotEmpty;
    }
  }

  void _loadBaselineRuntime() {
    try {
      if (_activeRuntimesMap.containsKey('__baseline__')) return;
      final baselineRuntime = getJavascriptRuntime();
      baselineRuntime.evaluate(defaultPluginSource);
      _activeRuntimesMap['__baseline__'] = baselineRuntime;
      debugPrint('[AddonManager] Loaded fallback baseline runtime');
    } catch (e) {
      debugPrint('[AddonManager] Error loading baseline runtime: $e');
    }
  }

  Future<bool> installDefaultPlugin() async {
    final defaultPluginUrl = "https://raw.githubusercontent.com/Allrounder687/it-feels-provider-backend/main/backend_addon.js";
    final success = await installPluginFromUrl(defaultPluginUrl, "default_backend.js");
    if (!success) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final pluginsDir = Directory('${dir.path}/plugins');
        if (!await pluginsDir.exists()) {
          await pluginsDir.create(recursive: true);
        }
        final file = File('${pluginsDir.path}/default_backend.js');
        await file.writeAsString(defaultPluginSource);
        _activeRuntimesMap.remove(file.path);
        _activeRuntimesMap.remove('__baseline__');
        await _loadPlugin(file);
        hasPluginsNotifier.value = _activeRuntimesMap.isNotEmpty;
        return true;
      } catch (e) {
        debugPrint('[AddonManager] Error writing fallback default plugin: $e');
      }
    }
    return success;
  }

  Future<bool> installPluginFromUrl(String url, String filename) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final pluginsDir = Directory('${dir.path}/plugins');
        if (!await pluginsDir.exists()) {
          await pluginsDir.create(recursive: true);
        }
        
        String safeName = filename.endsWith('.js') ? filename : '$filename.js';
        final file = File('${pluginsDir.path}/$safeName');
        await file.writeAsString(response.body);
        
        _activeRuntimesMap.remove(file.path);
        _activeRuntimesMap.remove('__baseline__');
        await _loadPlugin(file);
        hasPluginsNotifier.value = _activeRuntimesMap.isNotEmpty;
        return true;
      }
    } catch (e) {
      debugPrint('[AddonManager] Error installing plugin from URL: $e');
    }
    return false;
  }

  Future<void> uninstallAllPlugins() async {
    _activeRuntimesMap.clear();
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
    final key = file.path;
    if (_activeRuntimesMap.containsKey(key)) {
      debugPrint('[AddonManager] Plugin already loaded, skipping duplicate: $key');
      return;
    }
    try {
      String source = await File(file.path).readAsString();

      // Polyfills for complete Saavn API structuring in JavaScript addon engine
      if (!source.contains('getPlaylistTracksUrl')) {
        source += '''
          function getPlaylistTracksUrl(id) {
              return "https://www.jiosaavn.com/api.php?__call=playlist.getDetails&_format=json&cc=in&_marker=0&api_version=4&ctx=web6dot0&listid=" + encodeURIComponent(id);
          }
        ''';
      }
      if (!source.contains('getAlbumTracksUrl')) {
        source += '''
          function getAlbumTracksUrl(id) {
              return "https://www.jiosaavn.com/api.php?__call=content.getAlbumDetails&_format=json&_marker=0&api_version=4&albumid=" + encodeURIComponent(id);
          }
        ''';
      }
      if (!source.contains('getSearchAlbumsUrl')) {
        source += '''
          function getSearchAlbumsUrl(query) {
              return "https://www.jiosaavn.com/api.php?__call=search.getAlbumResults&_format=json&_marker=0&api_version=4&p=1&n=20&q=" + encodeURIComponent(query);
          }
        ''';
      }
      if (!source.contains('getSearchAllUrl')) {
        source += '''
          function getSearchAllUrl(query) {
              return "https://www.jiosaavn.com/api.php?__call=autocomplete.get&_format=json&_marker=0&api_version=4&ctx=web6dot0&query=" + encodeURIComponent(query);
          }
        ''';
      }
      if (!source.contains('getArtistDetailsUrl')) {
        source += '''
          function getArtistDetailsUrl(id) {
              return "https://www.jiosaavn.com/api.php?__call=artist.getArtistPageDetails&_format=json&_marker=0&api_version=4&artistId=" + encodeURIComponent(id);
          }
        ''';
      }

      final JavascriptRuntime runtime = getJavascriptRuntime();
      
      runtime.evaluate(source);
      _activeRuntimesMap[key] = runtime;
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
            final rawList = data['results'] ?? data['songs']?['data'] ?? (data is List ? data : null);
            if (rawList is List) {
              for (var item in rawList) {
                if (item is Map<String, dynamic>) {
                  allResults.add(Song.fromJson(item));
                }
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
            final rawList = data['results'] ?? data['playlists']?['data'] ?? (data is List ? data : null);
            if (rawList is List) {
              for (var item in rawList) {
                if (item is Map<String, dynamic>) {
                  allResults.add(Playlist(
                    id: item['id']?.toString() ?? '',
                    title: StringUtils.cleanText(item['title']?.toString() ?? item['name']?.toString() ?? ''),
                    type: item['type']?.toString() ?? 'playlist',
                    coverArt: item['image']?.toString() ?? item['coverArt']?.toString() ?? '',
                    songCount: int.tryParse(item['more_info']?['song_count']?.toString() ?? item['songCount']?.toString() ?? '0') ?? 0,
                    songs: [],
                  ));
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] searchPlaylists error in plugin: $e');
      }
    }

    if (allResults.isEmpty && query.isNotEmpty) {
      try {
        final fallbackUrl = 'https://www.jiosaavn.com/api.php?__call=search.getPlaylistResults&_format=json&_marker=0&api_version=4&p=1&n=20&q=${Uri.encodeComponent(query)}';
        final response = await http.get(Uri.parse(fallbackUrl));
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final rawList = data['results'] ?? data['playlists']?['data'] ?? (data is List ? data : null);
          if (rawList is List) {
            for (var item in rawList) {
              if (item is Map<String, dynamic>) {
                allResults.add(Playlist(
                  id: item['id']?.toString() ?? '',
                  title: StringUtils.cleanText(item['title']?.toString() ?? item['name']?.toString() ?? ''),
                  type: item['type']?.toString() ?? 'playlist',
                  coverArt: item['image']?.toString() ?? item['coverArt']?.toString() ?? '',
                  songCount: int.tryParse(item['more_info']?['song_count']?.toString() ?? item['songCount']?.toString() ?? '0') ?? 0,
                  songs: [],
                ));
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] Fallback searchPlaylists error: $e');
      }
    }
    return allResults;
  }

  Future<List<Playlist>> searchAlbums(String query) async {
    List<Playlist> allResults = [];
    for (var runtime in _activeRuntimes) {
      try {
        final jsResult = runtime.evaluate("typeof getSearchAlbumsUrl === 'function' ? getSearchAlbumsUrl('${query.replaceAll("'", "\\'")}') : null");
        final searchUrl = jsResult.stringResult.replaceAll('"', '');
        
        if (searchUrl != 'null' && searchUrl.isNotEmpty) {
          debugPrint('[AddonManager] Fetching searchAlbums from: $searchUrl');
          final response = await http.get(Uri.parse(searchUrl));
          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            final rawList = data['results'] ?? data['albums']?['data'] ?? (data is List ? data : null);
            if (rawList is List) {
              for (var item in rawList) {
                if (item is Map<String, dynamic>) {
                  allResults.add(Playlist(
                    id: item['id']?.toString() ?? '',
                    title: StringUtils.cleanText(item['title']?.toString() ?? item['name']?.toString() ?? ''),
                    type: 'album',
                    coverArt: item['image']?.toString() ?? item['coverArt']?.toString() ?? '',
                    songCount: int.tryParse(item['more_info']?['song_count']?.toString() ?? item['songCount']?.toString() ?? '0') ?? 0,
                    songs: [],
                  ));
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] searchAlbums error in plugin: $e');
      }
    }

    if (allResults.isEmpty && query.isNotEmpty) {
      try {
        final fallbackUrl = 'https://www.jiosaavn.com/api.php?__call=search.getAlbumResults&_format=json&_marker=0&api_version=4&p=1&n=20&q=${Uri.encodeComponent(query)}';
        final response = await http.get(Uri.parse(fallbackUrl));
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final rawList = data['results'] ?? data['albums']?['data'] ?? (data is List ? data : null);
          if (rawList is List) {
            for (var item in rawList) {
              if (item is Map<String, dynamic>) {
                allResults.add(Playlist(
                  id: item['id']?.toString() ?? '',
                  title: StringUtils.cleanText(item['title']?.toString() ?? item['name']?.toString() ?? ''),
                  type: 'album',
                  coverArt: item['image']?.toString() ?? item['coverArt']?.toString() ?? '',
                  songCount: int.tryParse(item['more_info']?['song_count']?.toString() ?? item['songCount']?.toString() ?? '0') ?? 0,
                  songs: [],
                ));
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] Fallback searchAlbums error: $e');
      }
    }
    return allResults;
  }

  Future<Map<String, dynamic>> searchAll(String query) async {
    final Map<String, dynamic> result = {
      'songs': <Song>[],
      'albums': <Playlist>[],
      'playlists': <Playlist>[],
      'artists': <Map<String, dynamic>>[],
    };

    for (var runtime in _activeRuntimes) {
      try {
        final jsResult = runtime.evaluate("typeof getSearchAllUrl === 'function' ? getSearchAllUrl('${query.replaceAll("'", "\\'")}') : null");
        final searchUrl = jsResult.stringResult.replaceAll('"', '');

        if (searchUrl != 'null' && searchUrl.isNotEmpty) {
          debugPrint('[AddonManager] Fetching searchAll from: $searchUrl');
          final response = await http.get(Uri.parse(searchUrl));
          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));

            // Parse Songs
            final rawSongs = data['songs']?['data'];
            if (rawSongs is List) {
              for (var item in rawSongs) {
                if (item is Map<String, dynamic>) {
                  result['songs'].add(Song.fromJson(item));
                }
              }
            }

            // Parse Albums
            final rawAlbums = data['albums']?['data'];
            if (rawAlbums is List) {
              for (var item in rawAlbums) {
                if (item is Map<String, dynamic>) {
                  result['albums'].add(Playlist(
                    id: item['id']?.toString() ?? '',
                    title: StringUtils.cleanText(item['title']?.toString() ?? item['name']?.toString() ?? ''),
                    type: 'album',
                    coverArt: item['image']?.toString() ?? '',
                    songCount: int.tryParse(item['more_info']?['song_count']?.toString() ?? '0') ?? 0,
                    songs: [],
                  ));
                }
              }
            }

            // Parse Playlists
            final rawPlaylists = data['playlists']?['data'];
            if (rawPlaylists is List) {
              for (var item in rawPlaylists) {
                if (item is Map<String, dynamic>) {
                  result['playlists'].add(Playlist(
                    id: item['id']?.toString() ?? '',
                    title: StringUtils.cleanText(item['title']?.toString() ?? item['name']?.toString() ?? ''),
                    type: 'playlist',
                    coverArt: item['image']?.toString() ?? '',
                    songCount: int.tryParse(item['more_info']?['song_count']?.toString() ?? '0') ?? 0,
                    songs: [],
                  ));
                }
              }
            }

            // Parse TopQuery / Artists
            final topQuery = data['topquery']?['data'];
            if (topQuery is List) {
              for (var item in topQuery) {
                if (item is Map<String, dynamic> && item['type'] == 'artist') {
                  result['artists'].add({
                    'id': item['id']?.toString() ?? '',
                    'title': StringUtils.cleanText(item['title']?.toString() ?? ''),
                    'image': item['image']?.toString() ?? '',
                    'description': item['description']?.toString() ?? 'Artist',
                  });
                }
              }
            }
            final rawArtists = data['artists']?['data'];
            if (rawArtists is List) {
              for (var item in rawArtists) {
                if (item is Map<String, dynamic>) {
                  final id = item['id']?.toString() ?? '';
                  if (!(result['artists'] as List).any((a) => a['id'] == id)) {
                    result['artists'].add({
                      'id': id,
                      'title': StringUtils.cleanText(item['title']?.toString() ?? ''),
                      'image': item['image']?.toString() ?? '',
                      'description': item['description']?.toString() ?? 'Artist',
                    });
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] searchAll error in plugin: $e');
      }
    }

    if (result['songs']!.isEmpty && result['albums']!.isEmpty && query.isNotEmpty) {
      try {
        final fallbackUrl = 'https://www.jiosaavn.com/api.php?__call=autocomplete.get&_format=json&_marker=0&api_version=4&ctx=web6dot0&query=${Uri.encodeComponent(query)}';
        final response = await http.get(Uri.parse(fallbackUrl));
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final rawSongs = data['songs']?['data'];
          if (rawSongs is List) {
            for (var item in rawSongs) {
              if (item is Map<String, dynamic>) {
                result['songs'].add(Song.fromJson(item));
              }
            }
          }
          final rawAlbums = data['albums']?['data'];
          if (rawAlbums is List) {
            for (var item in rawAlbums) {
              if (item is Map<String, dynamic>) {
                result['albums'].add(Playlist(
                  id: item['id']?.toString() ?? '',
                  title: StringUtils.cleanText(item['title']?.toString() ?? item['name']?.toString() ?? ''),
                  type: 'album',
                  coverArt: item['image']?.toString() ?? '',
                  songCount: int.tryParse(item['more_info']?['song_count']?.toString() ?? '0') ?? 0,
                  songs: [],
                ));
              }
            }
          }
          final rawPlaylists = data['playlists']?['data'];
          if (rawPlaylists is List) {
            for (var item in rawPlaylists) {
              if (item is Map<String, dynamic>) {
                result['playlists'].add(Playlist(
                  id: item['id']?.toString() ?? '',
                  title: StringUtils.cleanText(item['title']?.toString() ?? item['name']?.toString() ?? ''),
                  type: 'playlist',
                  coverArt: item['image']?.toString() ?? '',
                  songCount: int.tryParse(item['more_info']?['song_count']?.toString() ?? '0') ?? 0,
                  songs: [],
                ));
              }
            }
          }
          final rawArtists = data['artists']?['data'];
          if (rawArtists is List) {
            for (var item in rawArtists) {
              if (item is Map<String, dynamic>) {
                final id = item['id']?.toString() ?? '';
                if (!(result['artists'] as List).any((a) => a['id'] == id)) {
                  result['artists'].add({
                    'id': id,
                    'title': StringUtils.cleanText(item['title']?.toString() ?? ''),
                    'image': item['image']?.toString() ?? '',
                    'description': item['description']?.toString() ?? 'Artist',
                  });
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] Fallback searchAll error: $e');
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> getArtistDetails(String id) async {
    final Map<String, dynamic> result = {
      'topSongs': <Song>[],
      'albums': <Playlist>[],
      'image': null,
      'name': null,
      'bio': null,
    };

    for (var runtime in _activeRuntimes) {
      try {
        final jsResult = runtime.evaluate("typeof getArtistDetailsUrl === 'function' ? getArtistDetailsUrl('${id.replaceAll("'", "\\'")}') : null");
        final url = jsResult.stringResult.replaceAll('"', '');

        if (url != 'null' && url.isNotEmpty) {
          debugPrint('[AddonManager] Fetching artist details from: $url');
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            result['image'] = data['image'];
            result['name'] = data['name'];
            result['bio'] = data['bio'];

            final rawSongs = data['topSongs']?['songs'] ?? data['topSongs'];
            if (rawSongs is List) {
              for (var item in rawSongs) {
                if (item is Map<String, dynamic>) {
                  result['topSongs'].add(Song.fromJson(item));
                }
              }
            }

            final rawAlbums = data['topAlbums']?['albums'] ?? data['topAlbums'];
            if (rawAlbums is List) {
              for (var item in rawAlbums) {
                if (item is Map<String, dynamic>) {
                  result['albums'].add(Playlist(
                    id: item['id']?.toString() ?? '',
                    title: StringUtils.cleanText(item['title']?.toString() ?? item['name']?.toString() ?? ''),
                    type: 'album',
                    coverArt: item['image']?.toString() ?? '',
                    songCount: int.tryParse(item['more_info']?['song_count']?.toString() ?? '0') ?? 0,
                    songs: [],
                  ));
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] getArtistDetails error in plugin: $e');
      }
    }

    if (result['topSongs']!.isEmpty && result['albums']!.isEmpty && id.isNotEmpty) {
      try {
        final fallbackUrl = 'https://www.jiosaavn.com/api.php?__call=artist.getArtistPageDetails&_format=json&_marker=0&api_version=4&artistId=${Uri.encodeComponent(id)}';
        final response = await http.get(Uri.parse(fallbackUrl));
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          result['image'] = data['image'];
          result['name'] = StringUtils.cleanText(data['name']?.toString() ?? '');
          result['bio'] = data['bio'];

          final rawSongs = data['topSongs']?['songs'] ?? data['topSongs'];
          if (rawSongs is List) {
            for (var item in rawSongs) {
              if (item is Map<String, dynamic>) {
                result['topSongs'].add(Song.fromJson(item));
              }
            }
          }

          final rawAlbums = data['topAlbums']?['albums'] ?? data['topAlbums'];
          if (rawAlbums is List) {
            for (var item in rawAlbums) {
              if (item is Map<String, dynamic>) {
                result['albums'].add(Playlist(
                  id: item['id']?.toString() ?? '',
                  title: StringUtils.cleanText(item['title']?.toString() ?? item['name']?.toString() ?? ''),
                  type: 'album',
                  coverArt: item['image']?.toString() ?? '',
                  songCount: int.tryParse(item['more_info']?['song_count']?.toString() ?? '0') ?? 0,
                  songs: [],
                ));
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] Fallback getArtistDetails error: $e');
      }
    }
    return result;
  }

    Future<List<Song>> _fetchSongsFromContents(String contents) async {
    final list = <Song>[];
    if (contents.isEmpty) return list;
    try {
      final songDetailsUrl = 'https://www.jiosaavn.com/api.php?__call=song.getDetails&pids=${Uri.encodeComponent(contents)}&_format=json&_marker=0&api_version=4&ctx=web6dot0';
      final resp = await http.get(Uri.parse(songDetailsUrl)).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final sData = jsonDecode(utf8.decode(resp.bodyBytes));
        final sList = sData['songs'] ?? (sData is List ? sData : null);
        if (sList is List) {
          for (var item in sList) {
            if (item is Map<String, dynamic>) {
              list.add(Song.fromJson(item));
            }
          }
        } else if (sData is Map<String, dynamic>) {
          for (var item in sData.values) {
            if (item is Map<String, dynamic>) {
              list.add(Song.fromJson(item));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AddonManager] Failed fetching song IDs from contents: $e');
    }
    return list;
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
            final rawList = data['tracks'] ?? data['list'] ?? data['songs'];
            if (rawList is List && rawList.isNotEmpty) {
              for (var item in rawList) {
                if (item is Map<String, dynamic>) {
                  allResults.add(Song.fromJson(item));
                }
              }
            } else {
              final contents = data['more_info']?['contents']?.toString() ?? data['contents']?.toString() ?? '';
              if (contents.isNotEmpty) {
                allResults = await _fetchSongsFromContents(contents);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] getPlaylistTracks error in plugin: $e');
      }
    }

    if (allResults.isEmpty && id.isNotEmpty) {
      try {
        final fallbackUrl = 'https://www.jiosaavn.com/api.php?__call=playlist.getDetails&_format=json&cc=in&_marker=0&api_version=4&ctx=web6dot0&listid=${Uri.encodeComponent(id)}';
        debugPrint('[AddonManager] Fallback getPlaylistTracks from: $fallbackUrl');
        final response = await http.get(Uri.parse(fallbackUrl));
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final rawList = data['list'] ?? data['tracks'] ?? data['songs'];
          if (rawList is List && rawList.isNotEmpty) {
            for (var item in rawList) {
              if (item is Map<String, dynamic>) {
                allResults.add(Song.fromJson(item));
              }
            }
          } else {
            final contents = data['more_info']?['contents']?.toString() ?? data['contents']?.toString() ?? '';
            if (contents.isNotEmpty) {
              allResults = await _fetchSongsFromContents(contents);
            }
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] Fallback getPlaylistTracks error: $e');
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
            final rawList = data['tracks'] ?? data['list'] ?? data['songs'] ?? (data is List ? data : null);
            if (rawList is List) {
              for (var item in rawList) {
                if (item is Map<String, dynamic>) {
                  allResults.add(Song.fromJson(item));
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] getAlbumTracks error in plugin: $e');
      }
    }

    if (allResults.isEmpty && id.isNotEmpty) {
      try {
        final fallbackUrl = 'https://www.jiosaavn.com/api.php?__call=content.getAlbumDetails&_format=json&_marker=0&api_version=4&albumid=${Uri.encodeComponent(id)}';
        debugPrint('[AddonManager] Fallback getAlbumTracks from: $fallbackUrl');
        final response = await http.get(Uri.parse(fallbackUrl));
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final rawList = data['list'] ?? data['songs'] ?? data['tracks'];
          if (rawList is List && rawList.isNotEmpty) {
            for (var item in rawList) {
              if (item is Map<String, dynamic>) {
                allResults.add(Song.fromJson(item));
              }
            }
          } else {
            final contents = data['more_info']?['contents']?.toString() ?? data['contents']?.toString() ?? '';
            if (contents.isNotEmpty) {
              allResults = await _fetchSongsFromContents(contents);
            }
          }
        }
      } catch (e) {
        debugPrint('[AddonManager] Fallback getAlbumTracks error: $e');
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

  Future<Map<String, dynamic>> getChartsByLanguage(String language) async {
    final lang = language.toLowerCase();
    try {
      final url = 'https://www.jiosaavn.com/api.php?__call=content.getCharts&_format=json&cc=in&api_version=4';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Cookie': 'L=$lang;',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final rawList = data is List ? data : (data['data'] as List? ?? []);
        final playlists = <Playlist>[];
        for (var item in rawList) {
          if (item is Map<String, dynamic>) {
            playlists.add(Playlist.fromJson(item));
          }
        }

        List<Song> topTracks = [];
        if (playlists.isNotEmpty) {
          final topChartId = playlists.first.id;
          topTracks = await getPlaylistTracks(topChartId);
          if (topTracks.isEmpty && playlists.length > 1) {
            topTracks = await getPlaylistTracks(playlists[1].id);
          }
        }

        return {
          'tracks': topTracks,
          'playlists': playlists,
        };
      }
    } catch (e) {
      debugPrint('[AddonManager] getChartsByLanguage error: $e');
    }
    return {'tracks': <Song>[], 'playlists': <Playlist>[]};
  }

  Future<List<Playlist>> getFeaturedPlaylistsByLanguage(String language) async {
    final lang = language.toLowerCase();
    try {
      final url = 'https://www.jiosaavn.com/api.php?__call=content.getFeaturedPlaylists&_format=json&cc=in&api_version=4';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Cookie': 'L=$lang;',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final rawList = data is List ? data : (data['data'] as List? ?? data['list'] as List? ?? []);
        final playlists = <Playlist>[];
        for (var item in rawList) {
          if (item is Map<String, dynamic>) {
            playlists.add(Playlist.fromJson(item));
          }
        }
        return playlists;
      }
    } catch (e) {
      debugPrint('[AddonManager] getFeaturedPlaylistsByLanguage error: $e');
    }
    return [];
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
