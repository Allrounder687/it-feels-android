import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/song_model.dart';

class StorageService {
  static const String _favKey = 'favorite_songs_json_v1';

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
}
