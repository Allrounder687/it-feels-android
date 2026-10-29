import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/data/models/song_model.dart';


class LocalCacheDataSource {
  final SharedPreferences? _prefs;

  LocalCacheDataSource({this._prefs});

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Load cached native search results from device storage
  Future<List<Song>?> getCachedSearchResults(String query) async {
    try {
      final prefs = await _getPrefs();
      final cacheKey = 'offline_native_search_${query.toLowerCase()}';
      final cachedData = prefs.getString(cacheKey);

      if (cachedData != null) {
        try {
          debugPrint('[LocalCacheDataSource] Loaded Search Results from Offline Cache!');
          final data = await compute<String, dynamic>(jsonDecode, cachedData);
          if (data is Map && data['success'] == true && data['results'] is List) {
            final List results = data['results'];
            return results.map((item) {
              final map = Map<String, dynamic>.from(item);
              return Song(
                id: map['id']?.toString() ?? '',
                saavnId: map['id']?.toString() ?? '',
                title: map['title']?.toString() ?? '',
                artist: map['artist']?.toString() ?? '',
                album: map['album']?.toString() ?? 'Unknown',
                coverArt: map['image']?.toString() ?? map['albumArt']?.toString() ?? '',
                duration: int.tryParse(map['duration']?.toString() ?? '0') ?? 0,
                addedAt: DateTime.now(),
              );
            }).toList();
          }
        } catch (e) {
          debugPrint('[LocalCacheDataSource] Corrupted search cache detected, clearing: $e');
          await prefs.remove(cacheKey);
        }
      }
    } catch (e) {
      debugPrint('[LocalCacheDataSource] getCachedSearchResults error: $e');
    }
    return null;
  }

  /// Save raw JSON response for native search results
  Future<void> saveSearchResults(String query, String jsonBody) async {
    try {
      final prefs = await _getPrefs();
      final cacheKey = 'offline_native_search_${query.toLowerCase()}';
      await prefs.setString(cacheKey, jsonBody);
    } catch (e) {
      debugPrint('[LocalCacheDataSource] saveSearchResults error: $e');
    }
  }

  /// Load cached home feed from device storage
  Future<Map<String, dynamic>?> getCachedHomeFeed() async {
    try {
      final prefs = await _getPrefs();
      const cacheKey = 'offline_native_home_feed';
      final cachedData = prefs.getString(cacheKey);

      if (cachedData != null) {
        try {
          debugPrint('[LocalCacheDataSource] Loaded Home Feed from Offline Cache!');
          final parsed = await compute<String, dynamic>(jsonDecode, cachedData);
          return parsed is Map<String, dynamic> ? parsed : null;
        } catch (e) {
          debugPrint('[LocalCacheDataSource] Corrupted home feed cache detected, clearing: $e');
          await prefs.remove(cacheKey);
        }
      }
    } catch (e) {
      debugPrint('[LocalCacheDataSource] getCachedHomeFeed error: $e');
    }
    return null;
  }

  /// Save raw JSON response for home feed
  Future<void> saveHomeFeed(String jsonBody) async {
    try {
      final prefs = await _getPrefs();
      const cacheKey = 'offline_native_home_feed';
      await prefs.setString(cacheKey, jsonBody);
    } catch (e) {
      debugPrint('[LocalCacheDataSource] saveHomeFeed error: $e');
    }
  }
}
