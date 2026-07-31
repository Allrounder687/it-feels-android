import 'package:flutter/material.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/services/storage_service.dart';

class HiddenSongsProvider extends ChangeNotifier {
  List<Song> _hiddenSongs = [];

  HiddenSongsProvider() {
    _init();
  }

  List<Song> get hiddenSongs => _hiddenSongs;

  bool isHidden(String songId) {
    return _hiddenSongs.any((s) => s.id == songId);
  }

  Future<void> _init() async {
    _hiddenSongs = await StorageService.loadHiddenSongs();
    notifyListeners();
  }

  Future<void> hideSong(Song song) async {
    if (!isHidden(song.id)) {
      _hiddenSongs.add(song);
      await StorageService.saveHiddenSongs(_hiddenSongs);
      notifyListeners();
    }
  }

  Future<void> unhideSong(String songId) async {
    if (isHidden(songId)) {
      _hiddenSongs.removeWhere((s) => s.id == songId);
      await StorageService.saveHiddenSongs(_hiddenSongs);
      notifyListeners();
    }
  }
}
