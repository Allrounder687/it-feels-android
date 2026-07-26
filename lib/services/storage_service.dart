import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/song_model.dart';

class StorageService {
  static const String _favKey = 'favorite_songs_json_v1';
  static const String _downKey = 'downloaded_songs_json_v1';
  static const String _wifiQualityKey = 'wifi_quality_setting';
  static const String _mobileQualityKey = 'mobile_quality_setting';
  static const String _downloadQualityKey = 'download_quality_setting';
  static const String _themeKey = 'primary_theme_setting';
  static const String _customPlaylistsKey = 'custom_playlists_v1';
  static const String _playbackStateKey = 'playback_state_v1';
  static const String _artistHistoryKey = 'artist_history_v1';
  static const String _recentSongsKey = 'recent_songs_v1';

  /// Learning Engine: Artist History
  static Future<void> saveListeningHistory(Map<String, int> artistCounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_artistHistoryKey, json.encode(artistCounts));
  }

  static Future<Map<String, int>> loadListeningHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_artistHistoryKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as int));
    } catch (e) {
      return {};
    }
  }

  /// Learning Engine: Recently Played
  static Future<void> saveRecentlyPlayed(List<Song> songs) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = songs.map((s) => {
      'id': s.id,
      'saavnId': s.saavnId,
      'title': s.title,
      'artist': s.artist,
      'album': s.album,
      'duration': s.duration,
      'coverArt': s.coverArt,
      'encryptedMediaUrl': s.encryptedMediaUrl,
      'hasLyrics': s.hasLyrics,
    }).toList();
    await prefs.setString(_recentSongsKey, json.encode(jsonList));
  }

  static Future<List<Song>> loadRecentlyPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentSongsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = json.decode(raw) as List<dynamic>;
      return decoded.map((item) => Song.fromJson(Map<String, dynamic>.from(item))).toList();
    } catch (e) {
      return [];
    }
  }

  /// Playback Memory State
  static Future<void> savePlaybackState(List<Song> queue, int currentIndex) async {
    final prefs = await SharedPreferences.getInstance();
    if (queue.isEmpty) {
      await prefs.remove(_playbackStateKey);
      return;
    }
    final jsonList = queue
        .map((s) => {
              'id': s.id,
              'saavnId': s.saavnId,
              'title': s.title,
              'artist': s.artist,
              'album': s.album,
              'duration': s.duration,
              'coverArt': s.coverArt,
              'encryptedMediaUrl': s.encryptedMediaUrl,
              'hasLyrics': s.hasLyrics,
            })
        .toList();
    
    final state = {
      'currentIndex': currentIndex,
      'queue': jsonList,
    };
    await prefs.setString(_playbackStateKey, json.encode(state));
  }

  static Future<Map<String, dynamic>?> loadPlaybackState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_playbackStateKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = json.decode(raw);
      final List<dynamic> rawQueue = decoded['queue'] ?? [];
      final queue = rawQueue.map((item) => Song.fromJson(Map<String, dynamic>.from(item))).toList();
      return {
        'currentIndex': decoded['currentIndex'] ?? 0,
        'queue': queue,
      };
    } catch (e) {
      return null;
    }
  }

  /// Custom Playlists
  static Future<void> saveCustomPlaylists(String jsonString) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customPlaylistsKey, jsonString);
  }

  static Future<String?> loadCustomPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customPlaylistsKey);
  }

  /// Default Category
  static Future<void> saveDefaultCategory(String category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_category', category);
  }

  static Future<String> loadDefaultCategory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('default_category') ?? 'Bollywood';
  }

  /// Save favorites list
  static Future<void> saveFavorites(List<Song> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = favorites
        .map((s) => {
              'id': s.id,
              'saavnId': s.saavnId,
              'title': s.title,
              'artist': s.artist,
              'album': s.album,
              'duration': s.duration,
              'coverArt': s.coverArt,
              'encryptedMediaUrl': s.encryptedMediaUrl,
              'hasLyrics': s.hasLyrics,
            })
        .toList();
    await prefs.setString(_favKey, json.encode(jsonList));
  }

  /// Load favorites list
  static Future<List<Song>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final List<dynamic> decoded = json.decode(raw);
      return decoded.map((item) => Song.fromJson(Map<String, dynamic>.from(item))).toList();
    } catch (e) {
      return [];
    }
  }

  /// Save hidden songs list
  static Future<void> saveHiddenSongs(List<Song> hiddenSongs) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = hiddenSongs
        .map((s) => {
              'id': s.id,
              'saavnId': s.saavnId,
              'title': s.title,
              'artist': s.artist,
              'album': s.album,
              'duration': s.duration,
              'coverArt': s.coverArt,
              'encryptedMediaUrl': s.encryptedMediaUrl,
              'hasLyrics': s.hasLyrics,
            })
        .toList();
    await prefs.setString('hidden_songs_json_v1', json.encode(jsonList));
  }

  /// Load hidden songs list
  static Future<List<Song>> loadHiddenSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('hidden_songs_json_v1');
    if (raw == null || raw.isEmpty) return [];

    try {
      final List<dynamic> decoded = json.decode(raw);
      return decoded.map((item) => Song.fromJson(Map<String, dynamic>.from(item))).toList();
    } catch (e) {
      return [];
    }
  }

  /// Save downloaded songs list
  static Future<void> saveDownloads(List<Song> downloads) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = downloads
        .map((s) => {
              'id': s.id,
              'saavnId': s.saavnId,
              'title': s.title,
              'artist': s.artist,
              'album': s.album,
              'duration': s.duration,
              'coverArt': s.coverArt,
              'encryptedMediaUrl': s.encryptedMediaUrl,
              'hasLyrics': s.hasLyrics,
            })
        .toList();
    await prefs.setString(_downKey, json.encode(jsonList));
  }

  /// Load downloaded songs list
  static Future<List<Song>> loadDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_downKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final List<dynamic> decoded = json.decode(raw);
      return decoded.map((item) => Song.fromJson(Map<String, dynamic>.from(item))).toList();
    } catch (e) {
      return [];
    }
  }

  /// Quality & Theme Settings
  static Future<void> saveSettings({
    required String wifiQuality,
    required String mobileQuality,
    required String downloadQuality,
    required String theme,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wifiQualityKey, wifiQuality);
    await prefs.setString(_mobileQualityKey, mobileQuality);
    await prefs.setString(_downloadQualityKey, downloadQuality);
    await prefs.setString(_themeKey, theme);
  }

  static Future<Map<String, String>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'wifiQuality': prefs.getString(_wifiQualityKey) ?? '320 kbps (Very High)',
      'mobileQuality': prefs.getString(_mobileQualityKey) ?? '160 kbps (High)',
      'downloadQuality': prefs.getString(_downloadQualityKey) ?? '320 kbps (Very High)',
      'theme': prefs.getString(_themeKey) ?? 'Midnight Dark',
    };
  }
}
