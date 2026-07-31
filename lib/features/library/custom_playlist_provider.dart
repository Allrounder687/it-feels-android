import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/models/custom_playlist.dart';
import 'package:it_feels_music/services/storage_service.dart';

class CustomPlaylistProvider extends ChangeNotifier {
  List<CustomPlaylist> _playlists = [];

  CustomPlaylistProvider() {
    _init();
  }

  List<CustomPlaylist> get playlists => _playlists;

  Future<void> _init() async {
    final jsonStr = await StorageService.loadCustomPlaylists();
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = json.decode(jsonStr);
        _playlists = decoded.map((item) => CustomPlaylist.fromJson(item)).toList();
        notifyListeners();
      } catch (e) {
        // Handle error
      }
    }
  }

  Future<void> _save() async {
    final jsonList = _playlists.map((p) => p.toJson()).toList();
    await StorageService.saveCustomPlaylists(json.encode(jsonList));
    notifyListeners();
  }

  Future<void> createPlaylist(String title) async {
    final newPlaylist = CustomPlaylist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      createdAt: DateTime.now(),
      songs: [],
    );
    _playlists.add(newPlaylist);
    await _save();
  }

  Future<void> createPlaylistWithSongs(String title, List<Song> songs) async {
    final newPlaylist = CustomPlaylist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      createdAt: DateTime.now(),
      songs: List.from(songs),
    );
    _playlists.add(newPlaylist);
    await _save();
  }

  Future<void> renamePlaylist(String id, String newTitle) async {
    final idx = _playlists.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _playlists[idx].title = newTitle;
      await _save();
    }
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    await _save();
  }

  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      // Prevent exact duplicates
      if (!_playlists[idx].songs.any((s) => s.id == song.id)) {
        _playlists[idx].songs.add(song);
        await _save();
      }
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      _playlists[idx].songs.removeWhere((s) => s.id == songId);
      await _save();
    }
  }
}
