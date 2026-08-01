import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/services/backend_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class SearchState {
  final String query;
  final List<Song> songs;
  final List<Playlist> albums;
  final List<Playlist> playlists;
  final List<Map<String, dynamic>> artists;
  final bool isSearching;
  final List<String> recentSearches;

  const SearchState({
    this.query = '',
    this.songs = const [],
    this.albums = const [],
    this.playlists = const [],
    this.artists = const [],
    this.isSearching = false,
    this.recentSearches = const [],
  });

  SearchState copyWith({
    String? query,
    List<Song>? songs,
    List<Playlist>? albums,
    List<Playlist>? playlists,
    List<Map<String, dynamic>>? artists,
    bool? isSearching,
    List<String>? recentSearches,
  }) {
    return SearchState(
      query: query ?? this.query,
      songs: songs ?? this.songs,
      albums: albums ?? this.albums,
      playlists: playlists ?? this.playlists,
      artists: artists ?? this.artists,
      isSearching: isSearching ?? this.isSearching,
      recentSearches: recentSearches ?? this.recentSearches,
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
    _loadRecentSearches();
    return const SearchState();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final recent = prefs.getStringList('recent_searches') ?? [];
    state = state.copyWith(recentSearches: recent);
  }

  Future<void> _addRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    List<String> recent = prefs.getStringList('recent_searches') ?? [];
    
    // Remove if exists to push to top
    recent.remove(query);
    recent.insert(0, query);
    
    // Cap at 10 items
    if (recent.length > 10) {
      recent = recent.sublist(0, 10);
    }
    
    await prefs.setStringList('recent_searches', recent);
    state = state.copyWith(recentSearches: recent);
  }

  Future<void> clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_searches');
    state = state.copyWith(recentSearches: []);
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

      _addRecentSearch(newQuery);

      try {
        final resultsFuture = apiService.searchAll(newQuery);
        final songsFuture = apiService.searchSongs(newQuery, count: 50);
        final nativeSongsFuture = BackendApiService.searchNativeCatalog(newQuery);

        final results = await resultsFuture;
        final topSongs = await songsFuture;
        final nativeSongs = await nativeSongsFuture;

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

        // Prepend Native Catalog Songs and tag them
        if (nativeSongs.isNotEmpty) {
          final taggedNativeSongs = nativeSongs.map((s) => s.copyWith(album: '${s.album} (IT-Feels)')).toList();
          
          // Filter out duplicates (if native result is same as saavn result by id or name)
          final nativeIds = taggedNativeSongs.map((s) => s.id).toSet();
          songs.removeWhere((s) => nativeIds.contains(s.id));
          // Insert native songs right below the #1 global Saavn result to preserve relevance balance
          int insertIndex = songs.isNotEmpty ? 1 : 0;
          songs.insertAll(insertIndex, taggedNativeSongs);
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
