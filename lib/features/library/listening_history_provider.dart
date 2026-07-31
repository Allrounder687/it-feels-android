import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/services/storage_service.dart';
import 'package:it_feels_music/services/database_service.dart';

@immutable
class ListeningHistoryState {
  final Map<String, int> artistCounts;
  final List<Song> recentlyPlayed;

  const ListeningHistoryState({
    this.artistCounts = const {},
    this.recentlyPlayed = const [],
  });

  List<String> getTopArtists({int limit = 3}) {
    if (artistCounts.isEmpty) return [];
    
    var sortedKeys = artistCounts.keys.toList(growable: false)
      ..sort((k1, k2) => artistCounts[k2]!.compareTo(artistCounts[k1]!));
      
    if (sortedKeys.length > limit) {
      return sortedKeys.sublist(0, limit);
    }
    return sortedKeys;
  }

  ListeningHistoryState copyWith({
    Map<String, int>? artistCounts,
    List<Song>? recentlyPlayed,
  }) {
    return ListeningHistoryState(
      artistCounts: artistCounts ?? this.artistCounts,
      recentlyPlayed: recentlyPlayed ?? this.recentlyPlayed,
    );
  }
}

class ListeningHistoryNotifier extends Notifier<ListeningHistoryState> {
  @override
  ListeningHistoryState build() {
    _init();
    return const ListeningHistoryState();
  }

  Future<void> _init() async {
    final counts = await StorageService.loadListeningHistory();
    final recent = await StorageService.loadRecentlyPlayed();
    state = state.copyWith(artistCounts: counts, recentlyPlayed: recent);
  }

  void logSong(Song song) {
    if (song.artist.isEmpty || song.artist == 'Unknown Artist') return;

    DatabaseService().incrementPlayCount(song);

    final recent = List<Song>.from(state.recentlyPlayed);
    recent.removeWhere((s) => s.id == song.id);
    recent.insert(0, song);
    
    final updatedRecent = recent.length > 30 ? recent.sublist(0, 30) : recent;
    StorageService.saveRecentlyPlayed(updatedRecent);

    final counts = Map<String, int>.from(state.artistCounts);
    final artists = song.artist.split(',').map((a) => a.trim()).where((a) => a.isNotEmpty).toList();
    for (var artist in artists) {
      counts[artist] = (counts[artist] ?? 0) + 1;
    }
    
    StorageService.saveListeningHistory(counts);
    state = state.copyWith(artistCounts: counts, recentlyPlayed: updatedRecent);
  }
}

typedef ListeningHistoryProvider = ListeningHistoryNotifier;
