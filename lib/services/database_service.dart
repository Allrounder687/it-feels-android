import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../data/models/song_model.dart';

class DatabaseService {
  static late Isar _isar;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [SongSchema],
      directory: dir.path,
    );
  }

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

  Future<void> incrementPlayCount(String saavnId) async {
    await _isar.writeTxn(() async {
      final song = await _isar.songs.where().idEqualTo(saavnId).findFirst();
      if (song != null) {
        song.playCount += 1;
        song.lastPlayedAt = DateTime.now();
        await _isar.songs.put(song);
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
