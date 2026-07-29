import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../data/models/song_model.dart';

class DatabaseService {
  static late Isar _isar;
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [SongSchema],
      directory: dir.path,
    );
    _isInitialized = true;
  }

  static bool get isInitialized => _isInitialized;
  Isar get isar => _isar;

  // ----------------------------------------------------
  // Basic CRUD
  // ----------------------------------------------------

  Future<void> saveSong(Song song) async {
    await _isar.writeTxn(() async {
      await _isar.songs.put(song); // Insert or update based on isarId/id
    });
  }

  Future<void> saveSongs(List<Song> songs) async {
    await _isar.writeTxn(() async {
      await _isar.songs.putAll(songs);
    });
  }

  Future<Song?> getSong(String saavnId) async {
    return await _isar.songs.where().idEqualTo(saavnId).findFirst();
  }

  // ----------------------------------------------------
  // Advanced Search (FTS)
  // ----------------------------------------------------

  Future<List<Song>> searchSongs(String query, {int limit = 20}) async {
    if (query.isEmpty) return [];

    final cleanQuery = Song.cleanText(query).toLowerCase();
    final queryWords = cleanQuery.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    if (queryWords.isEmpty) return [];

    // Search where searchVector contains any of the query words
    return await _isar.songs
        .filter()
        .anyOf(queryWords, (q, String word) => q.searchVectorElementStartsWith(word))
        .limit(limit)
        .findAll();
  }

  // ----------------------------------------------------
  // Smart Filters
  // ----------------------------------------------------

  Future<List<Song>> getOnRepeat({int limit = 30}) async {
    final twoWeeksAgo = DateTime.now().subtract(const Duration(days: 14));
    
    return await _isar.songs
        .filter()
        .playCountGreaterThan(10)
        .and()
        .lastPlayedAtGreaterThan(twoWeeksAgo)
        .sortByPlayCountDesc()
        .limit(limit)
        .findAll();
  }

  Future<List<Song>> getTopPlayedSongs({int limit = 20}) async {
    return await _isar.songs
        .filter()
        .playCountGreaterThan(0)
        .sortByPlayCountDesc()
        .limit(limit)
        .findAll();
  }

  Future<List<Song>> getForgottenFavorites({int limit = 30}) async {
    final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
    
    return await _isar.songs
        .filter()
        .isFavoriteEqualTo(true)
        .and()
        .lastPlayedAtLessThan(threeMonthsAgo)
        .sortByLastPlayedAt() // Ascending (oldest first)
        .limit(limit)
        .findAll();
  }

  Future<List<Song>> getDownloadedSongs() async {
    return await _isar.songs
        .filter()
        .offlineStatusEqualTo(OfflineStatus.downloaded)
        .sortByAddedAtDesc()
        .findAll();
  }

  // ----------------------------------------------------
  // Behavioral Methods
  // ----------------------------------------------------

  Future<void> incrementPlayCount(Song songObj) async {
    if (!DatabaseService.isInitialized) return;
    await _isar.writeTxn(() async {
      var song = await _isar.songs.where().idEqualTo(songObj.id).findFirst();
      if (song != null) {
        song.playCount += 1;
        song.lastPlayedAt = DateTime.now();
        await _isar.songs.put(song);
      } else {
        songObj.playCount = 1;
        songObj.lastPlayedAt = DateTime.now();
        await _isar.songs.put(songObj);
      }
    });
  }

  Future<void> toggleFavorite(String saavnId) async {
    await _isar.writeTxn(() async {
      final song = await _isar.songs.where().idEqualTo(saavnId).findFirst();
      if (song != null) {
        song.isFavorite = !song.isFavorite;
        await _isar.songs.put(song);
      }
    });
  }
}
