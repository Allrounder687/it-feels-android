import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/services/storage_service.dart';

@immutable
class HiddenSongsState {
  final List<Song> hiddenSongs;

  const HiddenSongsState({this.hiddenSongs = const []});

  bool isHidden(String songId) {
    return hiddenSongs.any((s) => s.id == songId);
  }

  HiddenSongsState copyWith({List<Song>? hiddenSongs}) {
    return HiddenSongsState(
      hiddenSongs: hiddenSongs ?? this.hiddenSongs,
    );
  }
}

class HiddenSongsNotifier extends Notifier<HiddenSongsState> {
  @override
  HiddenSongsState build() {
    _init();
    return const HiddenSongsState();
  }

  Future<void> _init() async {
    final songs = await StorageService.loadHiddenSongs();
    state = state.copyWith(hiddenSongs: songs);
  }

  Future<void> hideSong(Song song) async {
    if (!state.isHidden(song.id)) {
      final updated = List<Song>.from(state.hiddenSongs)..add(song);
      state = state.copyWith(hiddenSongs: updated);
      await StorageService.saveHiddenSongs(updated);
    }
  }

  Future<void> unhideSong(String songId) async {
    if (state.isHidden(songId)) {
      final updated = List<Song>.from(state.hiddenSongs)..removeWhere((s) => s.id == songId);
      state = state.copyWith(hiddenSongs: updated);
      await StorageService.saveHiddenSongs(updated);
    }
  }
}

typedef HiddenSongsProvider = HiddenSongsNotifier;
