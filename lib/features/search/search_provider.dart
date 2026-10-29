import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';

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
  late final IMusicRepository apiService;
  Timer? _debounceTimer;

  @override
  SearchState build() {
    apiService = locator<IMusicRepository>();
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    _loadRecentSearches();
    return const SearchState();
  }

  void clear() {
    _debounceTimer?.cancel();
    state = const SearchState();
    _loadRecentSearches();
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

  int _calculateSongRelevance(String query, Song song, int originalIndex) {
    final qLower = query.toLowerCase().trim();
    final titleLower = song.title.toLowerCase().trim();
    final artistLower = song.artist.toLowerCase().trim();
    final albumLower = song.album.toLowerCase().trim();

    int score = 0;

    // Clean title without parentheticals or featured artists: e.g. "Blinding Lights (feat. ...)" -> "blinding lights"
    final cleanTitle = titleLower
        .replaceAll(RegExp(r'\s*\(.*?\)\s*'), ' ')
        .replaceAll(RegExp(r'\s*\[.*?\]\s*'), ' ')
        .trim();

    // Exact Title Matches
    if (titleLower == qLower || cleanTitle == qLower) {
      score += 150;
    } else if (titleLower.startsWith(qLower) || cleanTitle.startsWith(qLower)) {
      score += 90;
    } else if (titleLower.contains(qLower) || cleanTitle.contains(qLower)) {
      score += 50;
    }

    // Exact Artist Matches
    if (artistLower == qLower) {
      score += 110;
    } else if (artistLower.startsWith(qLower)) {
      score += 70;
    } else if (artistLower.contains(qLower)) {
      score += 40;
    }

    if (albumLower.contains(qLower)) {
      score += 25;
    }

    // Token Overlap
    final qTokens = qLower.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (qTokens.length > 1) {
      int matched = 0;
      for (final token in qTokens) {
        if (titleLower.contains(token) || artistLower.contains(token)) matched++;
      }
      score += ((matched / qTokens.length) * 35).round();
    }

    // HEAVY PENALTIES FOR UNWANTED MODIFIERS (Remix, Cover, Slowed, Reverb, Lofi, Instrumental, etc.)
    // Unless the user explicitly included those words in their search query!
    final hasRemixInQuery = qLower.contains('remix') || qLower.contains('mix');
    if (!hasRemixInQuery && (titleLower.contains('remix') || titleLower.contains(' mix'))) {
      score -= 90;
    }

    final hasCoverInQuery = qLower.contains('cover');
    if (!hasCoverInQuery && titleLower.contains('cover')) {
      score -= 100;
    }

    final hasSlowedInQuery = qLower.contains('slowed') || qLower.contains('reverb');
    if (!hasSlowedInQuery && (titleLower.contains('slowed') || titleLower.contains('reverb'))) {
      score -= 90;
    }

    final hasLofiInQuery = qLower.contains('lofi') || qLower.contains('lo-fi');
    if (!hasLofiInQuery && (titleLower.contains('lofi') || titleLower.contains('lo-fi'))) {
      score -= 90;
    }

    final hasInstrumentalInQuery = qLower.contains('instrumental') || qLower.contains('karaoke');
    if (!hasInstrumentalInQuery &&
        (titleLower.contains('instrumental') ||
         titleLower.contains('karaoke') ||
         titleLower.contains('tribute') ||
         titleLower.contains('ringtone') ||
         titleLower.contains('flute version') ||
         titleLower.contains('piano version'))) {
      score -= 130;
    }

    final hasAcousticInQuery = qLower.contains('acoustic') || qLower.contains('unplugged');
    if (!hasAcousticInQuery && (titleLower.contains('acoustic') || titleLower.contains('unplugged'))) {
      score -= 40;
    }

    // Natural Search Engine Priority Preservation
    score += (25 - originalIndex).clamp(0, 25);

    return score;
  }

  int _calculateAlbumRelevance(String query, Playlist album) {
    final qLower = query.toLowerCase().trim();
    final titleLower = album.title.toLowerCase().trim();

    int score = 0;

    // Exact Title Match
    if (titleLower == qLower) {
      score += 160;
    } else if (titleLower.startsWith(qLower)) {
      score += 100;
    } else if (titleLower.contains(qLower)) {
      score += 60;
    }

    // Token Overlap
    final qTokens = qLower.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (qTokens.length > 1) {
      int matched = 0;
      for (final token in qTokens) {
        if (titleLower.contains(token)) matched++;
      }
      score += ((matched / qTokens.length) * 40).round();
    }

    // Song Count Weight: Prioritize multi-song albums over single-song singles
    if (album.songCount > 1) {
      score += 50; // true album with multiple songs
      if (album.songCount >= 5) score += 20; // full album
    } else if (album.songCount == 1) {
      score -= 40; // penalize single-song clutter
    }

    return score;
  }

  int _calculateArtistRelevance(String query, String target) {
    if (target.isEmpty) return 0;
    final qLower = query.toLowerCase().trim();
    final tLower = target.toLowerCase().trim();

    if (qLower == tLower) return 150;
    if (tLower.startsWith(qLower)) return 100;
    if (tLower.contains(qLower)) return 60;

    final qTokens = qLower.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    int matched = 0;
    for (final token in qTokens) {
      if (tLower.contains(token)) matched++;
    }
    if (qTokens.isNotEmpty) {
      return ((matched / qTokens.length) * 50).round();
    }
    return 0;
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
        final podcastFuture = locator<IMusicRepository>().searchPodcasts(newQuery);

        final results = await resultsFuture;
        final topSongs = await songsFuture;
        final nativeSongs = await nativeSongsFuture;
        final podcasts = await podcastFuture;

        if (state.query != newQuery) return;

        var albums = List<Playlist>.from(results['albums'] ?? []);
        var playlists = List<Playlist>.from(results['playlists'] ?? []);
        var artists = List<Map<String, dynamic>>.from(results['artists'] ?? []);
        
        // Merge and deduplicate songs
        final Set<String> seenIds = {};
        final List<Song> combinedSongs = [];
        
        for (final s in topSongs) {
          if (!seenIds.contains(s.id)) {
            combinedSongs.add(s);
            seenIds.add(s.id);
          }
        }
        final resultSongs = List<Song>.from(results['songs'] ?? []);
        for (final s in resultSongs) {
          if (!seenIds.contains(s.id)) {
            combinedSongs.add(s);
            seenIds.add(s.id);
          }
        }

        // Score and sort songs
        final indexedSongs = combinedSongs.asMap().entries.toList();
        indexedSongs.sort((a, b) {
          final scoreA = _calculateSongRelevance(newQuery, a.value, a.key);
          final scoreB = _calculateSongRelevance(newQuery, b.value, b.key);
          return scoreB.compareTo(scoreA);
        });
        List<Song> songs = indexedSongs.map((e) => e.value).toList();

        // Sort artists by relevance
        artists.sort((a, b) {
          final scoreA = _calculateArtistRelevance(newQuery, a['title'] ?? '');
          final scoreB = _calculateArtistRelevance(newQuery, b['title'] ?? '');
          return scoreB.compareTo(scoreA);
        });

        // If an overwhelmingly matching artist was explicitly searched (score >= 120), enrich catalog
        if (artists.isNotEmpty) {
          final bestArtistScore = _calculateArtistRelevance(newQuery, artists.first['title'] ?? '');
          if (bestArtistScore >= 120) {
            try {
              final artistId = artists.first['id'].toString();
              final artistData = await apiService.fetchArtistDetails(artistId);
              if (state.query == newQuery) {
                final artistTopSongs = artistData['topSongs'] as List<Song>? ?? [];
                final artistAlbums = artistData['albums'] as List<Playlist>? ?? [];
                
                for (final song in artistTopSongs) {
                  if (!seenIds.contains(song.id)) {
                    combinedSongs.add(song);
                    seenIds.add(song.id);
                  }
                }

                final Set<String> albumIds = albums.map((a) => a.id).toSet();
                for (final alb in artistAlbums) {
                  if (!albumIds.contains(alb.id)) {
                    albums.add(alb);
                    albumIds.add(alb.id);
                  }
                }
              }
            } catch (e) {
              debugPrint('[SearchNotifier] Artist detail enrichment error: $e');
            }
          }
        }

        // Sort albums by relevance to the query
        albums.sort((a, b) {
          final scoreA = _calculateAlbumRelevance(newQuery, a);
          final scoreB = _calculateAlbumRelevance(newQuery, b);
          return scoreB.compareTo(scoreA);
        });

        // Prepend Native Catalog Songs and tag them
        if (nativeSongs.isNotEmpty) {
          final taggedNativeSongs = nativeSongs.map((s) => s.copyWith(album: '${s.album} (IT-Feels)')).toList();
          final nativeIds = taggedNativeSongs.map((s) => s.id).toSet();
          songs.removeWhere((s) => nativeIds.contains(s.id));
          int insertIndex = songs.isNotEmpty ? 1 : 0;
          songs.insertAll(insertIndex, taggedNativeSongs);
        }

        // Fetch videos if settings allow
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
