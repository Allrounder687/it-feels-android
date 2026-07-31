import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/models/custom_playlist.dart';
import 'package:it_feels_music/services/storage_service.dart';

@immutable
class CustomPlaylistState {
  final List<CustomPlaylist> playlists;

  const CustomPlaylistState({this.playlists = const []});

  CustomPlaylistState copyWith({List<CustomPlaylist>? playlists}) {
    return CustomPlaylistState(playlists: playlists ?? this.playlists);
  }
}

class CustomPlaylistNotifier extends Notifier<CustomPlaylistState> {
  @override
  CustomPlaylistState build() {
    _init();
    return const CustomPlaylistState();
  }

  Future<void> _init() async {
    final jsonStr = await StorageService.loadCustomPlaylists();
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = json.decode(jsonStr);
        final loaded = decoded.map((item) => CustomPlaylist.fromJson(item)).toList();
        state = state.copyWith(playlists: loaded);
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final jsonList = state.playlists.map((p) => p.toJson()).toList();
    await StorageService.saveCustomPlaylists(json.encode(jsonList));
  }

  Future<void> createPlaylist(String title) async {
    final newPlaylist = CustomPlaylist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      createdAt: DateTime.now(),
      songs: [],
    );
    final updated = List<CustomPlaylist>.from(state.playlists)..add(newPlaylist);
    state = state.copyWith(playlists: updated);
    await _save();
  }

  Future<void> createPlaylistWithSongs(String title, List<Song> songs) async {
    final newPlaylist = CustomPlaylist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      createdAt: DateTime.now(),
      songs: List.from(songs),
    );
    final updated = List<CustomPlaylist>.from(state.playlists)..add(newPlaylist);
    state = state.copyWith(playlists: updated);
    await _save();
  }

  Future<void> renamePlaylist(String id, String newTitle) async {
    final idx = state.playlists.indexWhere((p) => p.id == id);
    if (idx != -1) {
      final updated = List<CustomPlaylist>.from(state.playlists);
      updated[idx].title = newTitle;
      state = state.copyWith(playlists: updated);
      await _save();
    }
  }

  Future<void> deletePlaylist(String id) async {
    final updated = List<CustomPlaylist>.from(state.playlists)..removeWhere((p) => p.id == id);
    state = state.copyWith(playlists: updated);
    await _save();
  }

  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    final idx = state.playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      if (!state.playlists[idx].songs.any((s) => s.id == song.id)) {
        final updated = List<CustomPlaylist>.from(state.playlists);
        updated[idx].songs.add(song);
        state = state.copyWith(playlists: updated);
        await _save();
      }
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final idx = state.playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final updated = List<CustomPlaylist>.from(state.playlists);
      updated[idx].songs.removeWhere((s) => s.id == songId);
      state = state.copyWith(playlists: updated);
      await _save();
    }
  }
}

typedef CustomPlaylistProvider = CustomPlaylistNotifier;
