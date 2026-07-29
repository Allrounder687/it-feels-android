import 'package:flutter/material.dart';
import '../data/models/song_model.dart';
import '../services/storage_service.dart';
import '../services/database_service.dart';

class ListeningHistoryProvider extends ChangeNotifier {
  Map<String, int> _artistCounts = {};
  List<Song> _recentlyPlayed = [];

  ListeningHistoryProvider() {
    _init();
  }

  Map<String, int> get artistCounts => _artistCounts;
  List<Song> get recentlyPlayed => _recentlyPlayed;

  Future<void> _init() async {
    _artistCounts = await StorageService.loadListeningHistory();
    _recentlyPlayed = await StorageService.loadRecentlyPlayed();
    notifyListeners();
  }

  void logSong(Song song) {
    if (song.artist.isEmpty || song.artist == 'Unknown Artist') return;

    // Log to Isar for advanced stats
    DatabaseService().incrementPlayCount(song);

    // 1. Update Recently Played
    // Remove if already exists to move to top
    _recentlyPlayed.removeWhere((s) => s.id == song.id);
    _recentlyPlayed.insert(0, song);
    
    // Keep only last 30 songs
    if (_recentlyPlayed.length > 30) {
      _recentlyPlayed = _recentlyPlayed.sublist(0, 30);
    }
    
    StorageService.saveRecentlyPlayed(_recentlyPlayed);

    // 2. Update Artist Counts
    // Handle multiple artists separated by commas
    final artists = song.artist.split(',').map((a) => a.trim()).where((a) => a.isNotEmpty).toList();
    for (var artist in artists) {
      if (_artistCounts.containsKey(artist)) {
        _artistCounts[artist] = _artistCounts[artist]! + 1;
      } else {
        _artistCounts[artist] = 1;
      }
    }
    
    StorageService.saveListeningHistory(_artistCounts);
    notifyListeners();
  }

  List<String> getTopArtists({int limit = 3}) {
    if (_artistCounts.isEmpty) return [];
    
    var sortedKeys = _artistCounts.keys.toList(growable: false)
      ..sort((k1, k2) => _artistCounts[k2]!.compareTo(_artistCounts[k1]!));
      
    if (sortedKeys.length > limit) {
      return sortedKeys.sublist(0, limit);
    }
    return sortedKeys;
  }
}
