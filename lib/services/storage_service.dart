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
