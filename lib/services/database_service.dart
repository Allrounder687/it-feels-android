import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'dart:isolate';
import 'package:it_feels_music/data/models/cache_models.dart';

class DatabaseService {
  static Isar? _isar;
  static bool _isInitialized = false;
  static const String _dbName = 'it_feels_db';

  static Future<void> init() async {
    if (isInitialized) return;

    try {
      if (Isar.instanceNames.contains(_dbName)) {
        final existing = Isar.getInstance(_dbName);
        if (existing != null && existing.isOpen) {
          try {
            existing.songs; // Probe collections
            existing.cachedStreams; 
            existing.cachedPalettes;
            _isar = existing;
            _isInitialized = true;
            return;
          } catch (_) {
            // Close leftover uninitialized native handle from previous hot restart
            await existing.close();
            _isar = null;
            _isInitialized = false;
          }
        }
      }

      final dir = await getApplicationDocumentsDirectory();
      final openedIsar = await Isar.open(
        [SongSchema, CachedStreamSchema, CachedPaletteSchema],
        directory: dir.path,
        name: _dbName,
        inspector: kDebugMode,
      );

      // Verify that schema collections are properly bound in this isolate
      try {
        openedIsar.songs;
        openedIsar.cachedStreams;
        openedIsar.cachedPalettes;
        _isar = openedIsar;
        _isInitialized = true;
      } catch (e) {
        await openedIsar.close();
        _isar = null;
        _isInitialized = false;
      }
    } catch (_) {
      // Handle concurrent isolate race (e.g. background FCM service isolate)
      await Future.delayed(const Duration(milliseconds: 200));
      try {
        final existing = Isar.getInstance(_dbName);
        if (existing != null && existing.isOpen) {
          existing.songs;
          _isar = existing;
          _isInitialized = true;
          return;
        }
      } catch (_) {}
      _isar = null;
      _isInitialized = false;
    }
  }

  static Future<void> ensureInitialized() async {
    if (!isInitialized) {
      await init();
    }
  }

  static bool get isInitialized {
    if (!_isInitialized || _isar == null || !_isar!.isOpen) return false;
    try {
      _isar!.songs;
      return true;
    } catch (_) {
      _isInitialized = false;
      _isar = null;
      return false;
    }
  }

  Isar? get isar => _isar;

  // ----------------------------------------------------
  // Basic CRUD
  // ----------------------------------------------------

  Future<void> saveSong(Song song) async {
    try {
      await ensureInitialized();
      if (!isInitialized) return;
      await _isar!.writeTxn(() async {
        await _isar!.songs.put(song); // Insert or update based on isarId/id
      });
    } catch (e) {
      debugPrint('[DatabaseService] saveSong error: $e');
    }
  }

  Future<void> saveSongs(List<Song> songs) async {
    try {
      await ensureInitialized();
      if (!isInitialized) return;
      await _isar!.writeTxn(() async {
        await _isar!.songs.putAll(songs);
      });
    } catch (e) {
      debugPrint('[DatabaseService] saveSongs error: $e');
    }
  }

  Future<Song?> getSong(String saavnId) async {
    try {
      await ensureInitialized();
      if (!isInitialized) return null;
      return await _isar!.songs.where().idEqualTo(saavnId).findFirst();
    } catch (e) {
      debugPrint('[DatabaseService] getSong error: $e');
      return null;
    }
  }

  // ----------------------------------------------------
  // Advanced Search (FTS)
  // ----------------------------------------------------

  Future<List<Song>> searchSongs(String query, {int limit = 20}) async {
    if (query.isEmpty) return [];
    try {
      await ensureInitialized();
      if (!isInitialized) return [];

      final cleanQuery = Song.cleanText(query).toLowerCase();
      final queryWords = cleanQuery.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

      if (queryWords.isEmpty) return [];

      // Search where searchVector contains any of the query words
      return await Isolate.run(() {
        final isar = Isar.getInstance('it_feels_db');
        if (isar == null) return <Song>[];
        return isar.songs
            .filter()
            .anyOf(queryWords, (q, String word) => q.searchVectorElementStartsWith(word))
            .limit(limit)
            .findAllSync();
      });
    } catch (e) {
      debugPrint('[DatabaseService] searchSongs error: $e');
      return [];
    }
  }

  // ----------------------------------------------------
  // Smart Filters
  // ----------------------------------------------------

  Future<List<Song>> getOnRepeat({int limit = 30}) async {
    try {
      await ensureInitialized();
      if (!isInitialized) return [];
      final twoWeeksAgo = DateTime.now().subtract(const Duration(days: 14));
      return await Isolate.run(() {
        final isar = Isar.getInstance('it_feels_db');
        if (isar == null) return <Song>[];
        return isar.songs
            .filter()
            .playCountGreaterThan(10)
            .and()
            .lastPlayedAtGreaterThan(twoWeeksAgo)
            .sortByPlayCountDesc()
            .limit(limit)
            .findAllSync();
      });
    } catch (e) {
      debugPrint('[DatabaseService] getOnRepeat error: $e');
      return [];
    }
  }

  Future<List<Song>> getTopPlayedSongs({int limit = 20}) async {
    try {
      await ensureInitialized();
      if (!isInitialized) return [];
      return await Isolate.run(() {
        final isar = Isar.getInstance('it_feels_db');
        if (isar == null) return <Song>[];
        return isar.songs
            .filter()
            .playCountGreaterThan(0)
            .sortByPlayCountDesc()
            .limit(limit)
            .findAllSync();
      });
    } catch (e) {
      debugPrint('[DatabaseService] getTopPlayedSongs error: $e');
      return [];
    }
  }

  Future<List<Song>> getForgottenFavorites({int limit = 30}) async {
    try {
      await ensureInitialized();
      if (!isInitialized) return [];
      final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
      return await Isolate.run(() {
        final isar = Isar.getInstance('it_feels_db');
        if (isar == null) return <Song>[];
        return isar.songs
            .filter()
            .isFavoriteEqualTo(true)
            .and()
            .lastPlayedAtLessThan(threeMonthsAgo)
            .sortByLastPlayedAt() // Ascending (oldest first)
            .limit(limit)
            .findAllSync();
      });
    } catch (e) {
      debugPrint('[DatabaseService] getForgottenFavorites error: $e');
      return [];
    }
  }

  Future<List<Song>> getAllFavorites({int offset = 0, int limit = 50}) async {
    try {
      await ensureInitialized();
      if (!isInitialized) return [];
      return await Isolate.run(() {
        final isar = Isar.getInstance('it_feels_db');
        if (isar == null) return <Song>[];
        return isar.songs
            .filter()
            .isFavoriteEqualTo(true)
            .sortByAddedAtDesc()
            .offset(offset)
            .limit(limit)
            .findAllSync();
      });
    } catch (e) {
      debugPrint('[DatabaseService] getAllFavorites error: $e');
      return [];
    }
  }

  Future<List<Song>> getDownloadedSongs({int offset = 0, int limit = 50}) async {
    try {
      await ensureInitialized();
      if (!isInitialized) return [];
      return await Isolate.run(() {
        final isar = Isar.getInstance('it_feels_db');
        if (isar == null) return <Song>[];
        return isar.songs
            .filter()
            .offlineStatusEqualTo(OfflineStatus.downloaded)
            .sortByAddedAtDesc()
            .offset(offset)
            .limit(limit)
            .findAllSync();
      });
    } catch (e) {
      debugPrint('[DatabaseService] getDownloadedSongs error: $e');
      return [];
    }
  }

  // ----------------------------------------------------
  // Behavioral Methods
  // ----------------------------------------------------

  Future<void> incrementPlayCount(Song songObj) async {
    try {
      await ensureInitialized();
      if (!isInitialized) return;
      await _isar!.writeTxn(() async {
        var song = await _isar!.songs.where().idEqualTo(songObj.id).findFirst();
        if (song != null) {
          song.playCount += 1;
          song.lastPlayedAt = DateTime.now();
          await _isar!.songs.put(song);
        } else {
          songObj.playCount = 1;
          songObj.lastPlayedAt = DateTime.now();
          await _isar!.songs.put(songObj);
        }
      });
    } catch (e) {
      debugPrint('[DatabaseService] incrementPlayCount error: $e');
    }
  }

  Future<void> toggleFavorite(String saavnId) async {
    try {
      await ensureInitialized();
      if (!isInitialized) return;
      await _isar!.writeTxn(() async {
        final song = await _isar!.songs.where().idEqualTo(saavnId).findFirst();
        if (song != null) {
          song.isFavorite = !song.isFavorite;
          await _isar!.songs.put(song);
        }
      });
    } catch (e) {
      debugPrint('[DatabaseService] toggleFavorite error: $e');
    }
  }

  static Future<List<Song>> getContinueWatching({int limit = 10}) async {
    try {
      await ensureInitialized();
      if (!isInitialized) return [];
      
      // Get songs that have a playback position set, ordered by lastPlayedAt descending
      return await Isolate.run(() {
        final isar = Isar.getInstance('it_feels_db');
        if (isar == null) return <Song>[];
        return isar.songs
            .filter()
            .playbackPositionMsGreaterThan(10000) // Must have played at least 10 seconds
            .sortByLastPlayedAtDesc()
            .limit(limit)
            .findAllSync();
      });
    } catch (e) {
      debugPrint('[DatabaseService] getContinueWatching error: $e');
      return [];
    }
  }
}
