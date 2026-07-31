import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';

@immutable
class SearchState {
  final String query;
  final List<Song> songs;
  final List<Playlist> albums;
  final List<Playlist> playlists;
  final List<Map<String, dynamic>> artists;
  final bool isSearching;

  const SearchState({
    this.query = '',
    this.songs = const [],
    this.albums = const [],
    this.playlists = const [],
    this.artists = const [],
    this.isSearching = false,
  });

  SearchState copyWith({
    String? query,
    List<Song>? songs,
    List<Playlist>? albums,
    List<Playlist>? playlists,
    List<Map<String, dynamic>>? artists,
    bool? isSearching,
  }) {
    return SearchState(
      query: query ?? this.query,
      songs: songs ?? this.songs,
      albums: albums ?? this.albums,
      playlists: playlists ?? this.playlists,
      artists: artists ?? this.artists,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}

class SearchNotifier extends Notifier<SearchState> {
  late final MusicApiService apiService;
  Timer? _debounceTimer;

  @override
  SearchState build() {
    apiService = locator<MusicApiService>();
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    return const SearchState();
  }

  void search(String newQuery, {BuildContext? context}) {
    _debounceTimer?.cancel();

    if (newQuery.trim().isEmpty) {
      state = state.copyWith(
        query: '',
        songs: const [],
        albums: const [],
        playlists: const [],
        artists: const [],
        isSearching: false,
      );
      return;
    }

    state = state.copyWith(query: newQuery, isSearching: true);

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (state.query != newQuery) return;

      try {
        final resultsFuture = apiService.searchAll(newQuery);
        final songsFuture = apiService.searchSongs(newQuery, count: 50);

        final results = await resultsFuture;
        final topSongs = await songsFuture;

        if (state.query != newQuery) return;

        var albums = List<Playlist>.from(results['albums'] ?? []);
        var playlists = List<Playlist>.from(results['playlists'] ?? []);
        var artists = List<Map<String, dynamic>>.from(results['artists'] ?? []);
        List<Song> songs = [];

        if (artists.isNotEmpty && artists.first['id'] != null && artists.first['id'].toString().isNotEmpty) {
          final artistId = artists.first['id'].toString();
          final artistData = await apiService.fetchArtistDetails(artistId);
          
          if (state.query != newQuery) return;

          if (artistData['topSongs'] != null && (artistData['topSongs'] as List).isNotEmpty) {
            songs = artistData['topSongs'] as List<Song>;
            if (artistData['albums'] != null && (artistData['albums'] as List).isNotEmpty) {
              albums.insertAll(0, artistData['albums'] as List<Playlist>);
            }
          }
        } else {
          songs = topSongs.isNotEmpty ? topSongs : List<Song>.from(results['songs'] ?? []);
        }

        state = state.copyWith(
          songs: songs,
          albums: albums,
          playlists: playlists,
          artists: artists,
          isSearching: false,
        );
      } catch (e) {
        debugPrint('[SearchNotifier] Search error: $e');
        state = state.copyWith(isSearching: false);
      }
    });
  }
}

typedef SearchProvider = SearchNotifier;
