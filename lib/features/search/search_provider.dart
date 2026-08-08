import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/data/services/podcast_provider.dart';
import 'package:it_feels_music/services/backend_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class SearchState {
  final String query;
  final List<Song> songs;
  final List<Playlist> albums;
  final List<Playlist> playlists;
  final List<Map<String, dynamic>> artists;
  final List<Map<String, dynamic>> videos;
  final List<Song> podcasts;
  final bool isSearching;
  final bool isLoadingMore;
  final int songPage;
  final int albumPage;
  final int playlistPage;
  final bool hasMoreSongs;
  final bool hasMoreAlbums;
  final bool hasMorePlaylists;
  final List<String> recentSearches;

  const SearchState({
    this.query = '',
    this.songs = const [],
    this.albums = const [],
    this.playlists = const [],
    this.artists = const [],
    this.videos = const [],
    this.podcasts = const [],
    this.isSearching = false,
    this.isLoadingMore = false,
    this.songPage = 1,
    this.albumPage = 1,
    this.playlistPage = 1,
    this.hasMoreSongs = true,
    this.hasMoreAlbums = true,
    this.hasMorePlaylists = true,
    this.recentSearches = const [],
  });

  SearchState copyWith({
    String? query,
    List<Song>? songs,
    List<Playlist>? albums,
    List<Playlist>? playlists,
    List<Map<String, dynamic>>? artists,
    List<Map<String, dynamic>>? videos,
    List<Song>? podcasts,
    bool? isSearching,
    bool? isLoadingMore,
    int? songPage,
    int? albumPage,
    int? playlistPage,
    bool? hasMoreSongs,
    bool? hasMoreAlbums,
    bool? hasMorePlaylists,
    List<String>? recentSearches,
  }) {
    return SearchState(
      query: query ?? this.query,
      songs: songs ?? this.songs,
      albums: albums ?? this.albums,
      playlists: playlists ?? this.playlists,
      artists: artists ?? this.artists,
      videos: videos ?? this.videos,
      podcasts: podcasts ?? this.podcasts,
      isSearching: isSearching ?? this.isSearching,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      songPage: songPage ?? this.songPage,
      albumPage: albumPage ?? this.albumPage,
      playlistPage: playlistPage ?? this.playlistPage,
      hasMoreSongs: hasMoreSongs ?? this.hasMoreSongs,
      hasMoreAlbums: hasMoreAlbums ?? this.hasMoreAlbums,
      hasMorePlaylists: hasMorePlaylists ?? this.hasMorePlaylists,
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

  Future<void> removeRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> recent = prefs.getStringList('recent_searches') ?? [];
    recent.remove(query);
    await prefs.setStringList('recent_searches', recent);
    state = state.copyWith(recentSearches: recent);
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
        videos: const [],
        podcasts: const [],
        isSearching: false,
        isLoadingMore: false,
        songPage: 1,
        albumPage: 1,
        playlistPage: 1,
        hasMoreSongs: true,
        hasMoreAlbums: true,
        hasMorePlaylists: true,
      );
      return;
    }

    state = state.copyWith(
      query: newQuery, 
      isSearching: true,
      songPage: 1,
      albumPage: 1,
      playlistPage: 1,
      hasMoreSongs: true,
      hasMoreAlbums: true,
      hasMorePlaylists: true,
    );

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (state.query != newQuery) return;

      _addRecentSearch(newQuery);

      try {
        final resultsFuture = apiService.searchAll(newQuery);
        final songsFuture = apiService.searchSongs(newQuery, count: 50);
        final nativeSongsFuture = BackendApiService.searchNativeCatalog(newQuery);
        final podcastFuture = locator<PodcastProvider>().searchPodcasts(newQuery);

        final results = await resultsFuture;
        final topSongs = await songsFuture;
        final nativeSongs = await nativeSongsFuture;
        final podcasts = await podcastFuture;

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

        // Fetch videos if settings allow (handled by UI, but we can pre-fetch a few)
        final videos = await BackendApiService.searchVideos(newQuery);

        state = state.copyWith(
          songs: songs,
          albums: albums,
          playlists: playlists,
          artists: artists,
          videos: videos,
          podcasts: podcasts,
          isSearching: false,
        );
      } catch (e) {
        debugPrint('[SearchNotifier] Search error: $e');
        state = state.copyWith(isSearching: false);
      }
    });
  }

  Future<void> loadMore(int categoryIndex) async {
    if (state.query.isEmpty || state.isSearching || state.isLoadingMore) return;

    state = state.copyWith(isLoadingMore: true);
    
    try {
      // 1: SONGS, 3: ALBUMS, 4: PLAYLISTS, 5: VIDEOS (we won't paginate videos for now due to backend limits)
      if (categoryIndex == 1 && state.hasMoreSongs) {
        final nextPage = state.songPage + 1;
        final moreSongs = await apiService.searchSongs(state.query, page: nextPage, count: 50);
        if (moreSongs.isEmpty) {
          state = state.copyWith(hasMoreSongs: false, isLoadingMore: false);
        } else {
          state = state.copyWith(
            songs: [...state.songs, ...moreSongs],
            songPage: nextPage,
            isLoadingMore: false,
          );
        }
      } else if (categoryIndex == 3 && state.hasMoreAlbums) {
        final nextPage = state.albumPage + 1;
        final moreAlbums = await apiService.searchAlbums(state.query, page: nextPage, count: 30);
        if (moreAlbums.isEmpty) {
          state = state.copyWith(hasMoreAlbums: false, isLoadingMore: false);
        } else {
          state = state.copyWith(
            albums: [...state.albums, ...moreAlbums],
            albumPage: nextPage,
            isLoadingMore: false,
          );
        }
      } else if (categoryIndex == 4 && state.hasMorePlaylists) {
        final nextPage = state.playlistPage + 1;
        final morePlaylists = await apiService.searchPlaylists(state.query, page: nextPage, count: 30);
        if (morePlaylists.isEmpty) {
          state = state.copyWith(hasMorePlaylists: false, isLoadingMore: false);
        } else {
          state = state.copyWith(
            playlists: [...state.playlists, ...morePlaylists],
            playlistPage: nextPage,
            isLoadingMore: false,
          );
        }
      } else {
        state = state.copyWith(isLoadingMore: false);
      }
    } catch (e) {
      debugPrint('[SearchNotifier] loadMore error: $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

typedef SearchProvider = SearchNotifier;
