import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/utils/error_reporter.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/models/feed_shelf.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';

import 'package:it_feels_music/services/lastfm_service.dart';
import 'package:it_feels_music/services/storage_service.dart';
import 'package:it_feels_music/services/database_service.dart';


@immutable
class HomeState {
  final List<Song> trendingSongs;
  final List<Playlist> topPlaylists;
  final List<Playlist> topAlbums;
  final List<Song> bollywoodSongs;
  final List<Playlist> bollywoodPlaylists;
  final List<Song> teluguSongs;
  final List<Playlist> teluguPlaylists;
  final List<Song> tamilSongs;
  final List<Playlist> tamilPlaylists;
  final List<Song> punjabiSongs;
  final List<Playlist> punjabiPlaylists;
  final List<Song> hollywoodSongs;
  final List<Playlist> hollywoodPlaylists;
  final List<Song> podcastSongs;
  final List<Playlist> podcastPlaylists;
  final List<Song> youSongs;
  final List<Playlist> youPlaylists;
  final String moodLanguage;
  final List<Playlist> moodPlaylists;
  final bool isLoadingMoods;
  final List<Playlist> chartPlaylists;
  final bool isLoadingCharts;
  final String selectedCategory;
  final bool isLoading;
  final List<Song> continueWatching;
  final Map<String, List<FeedShelf>> dynamicFeeds;
  final Map<String, bool> isLoadingFeed;
  final Map<String, int> feedPagesLoaded;

  const HomeState({
    this.trendingSongs = const [],
    this.topPlaylists = const [],
    this.topAlbums = const [],
    this.bollywoodSongs = const [],
    this.bollywoodPlaylists = const [],
    this.teluguSongs = const [],
    this.teluguPlaylists = const [],
    this.tamilSongs = const [],
    this.tamilPlaylists = const [],
    this.punjabiSongs = const [],
    this.punjabiPlaylists = const [],
    this.hollywoodSongs = const [],
    this.hollywoodPlaylists = const [],
    this.podcastSongs = const [],
    this.podcastPlaylists = const [],
    this.youSongs = const [],
    this.youPlaylists = const [],
    this.moodLanguage = 'English',
    this.moodPlaylists = const [],
    this.isLoadingMoods = false,
    this.chartPlaylists = const [],
    this.isLoadingCharts = false,
    this.selectedCategory = 'For You',
    this.isLoading = true,
    this.continueWatching = const [],
    this.dynamicFeeds = const {},
    this.isLoadingFeed = const {},
    this.feedPagesLoaded = const {},
  });

  List<Song> get currentCategorySongs {
    switch (selectedCategory) {
      case "For You":
        return youSongs;
      case "Podcasts":
        return podcastSongs;
      case "Music":
      case "Charts":
      default:
        return trendingSongs;
    }
  }

  List<Playlist> get currentCategoryPlaylists {
    switch (selectedCategory) {
      case "For You":
        return youPlaylists;
      case "Podcasts":
        return podcastPlaylists;
      case "Charts":
        return chartPlaylists;
      case "Music":
      default:
        return topPlaylists;
    }
  }

  HomeState copyWith({
    List<Song>? trendingSongs,
    List<Playlist>? topPlaylists,
    List<Playlist>? topAlbums,
    List<Song>? bollywoodSongs,
    List<Playlist>? bollywoodPlaylists,
    List<Song>? teluguSongs,
    List<Playlist>? teluguPlaylists,
    List<Song>? tamilSongs,
    List<Playlist>? tamilPlaylists,
    List<Song>? punjabiSongs,
    List<Playlist>? punjabiPlaylists,
    List<Song>? hollywoodSongs,
    List<Playlist>? hollywoodPlaylists,
    List<Song>? podcastSongs,
    List<Playlist>? podcastPlaylists,
    List<Song>? youSongs,
    List<Playlist>? youPlaylists,
    String? moodLanguage,
    List<Playlist>? moodPlaylists,
    bool? isLoadingMoods,
    List<Playlist>? chartPlaylists,
    bool? isLoadingCharts,
    String? selectedCategory,
    bool? isLoading,
    List<Song>? continueWatching,
    Map<String, List<FeedShelf>>? dynamicFeeds,
    Map<String, bool>? isLoadingFeed,
    Map<String, int>? feedPagesLoaded,
  }) {
    return HomeState(
      trendingSongs: trendingSongs ?? this.trendingSongs,
      topPlaylists: topPlaylists ?? this.topPlaylists,
      topAlbums: topAlbums ?? this.topAlbums,
      bollywoodSongs: bollywoodSongs ?? this.bollywoodSongs,
      bollywoodPlaylists: bollywoodPlaylists ?? this.bollywoodPlaylists,
      teluguSongs: teluguSongs ?? this.teluguSongs,
      teluguPlaylists: teluguPlaylists ?? this.teluguPlaylists,
      tamilSongs: tamilSongs ?? this.tamilSongs,
      tamilPlaylists: tamilPlaylists ?? this.tamilPlaylists,
      punjabiSongs: punjabiSongs ?? this.punjabiSongs,
      punjabiPlaylists: punjabiPlaylists ?? this.punjabiPlaylists,
      hollywoodSongs: hollywoodSongs ?? this.hollywoodSongs,
      hollywoodPlaylists: hollywoodPlaylists ?? this.hollywoodPlaylists,
      podcastSongs: podcastSongs ?? this.podcastSongs,
      podcastPlaylists: podcastPlaylists ?? this.podcastPlaylists,
      youSongs: youSongs ?? this.youSongs,
      youPlaylists: youPlaylists ?? this.youPlaylists,
      moodLanguage: moodLanguage ?? this.moodLanguage,
      moodPlaylists: moodPlaylists ?? this.moodPlaylists,
      isLoadingMoods: isLoadingMoods ?? this.isLoadingMoods,
      chartPlaylists: chartPlaylists ?? this.chartPlaylists,
      isLoadingCharts: isLoadingCharts ?? this.isLoadingCharts,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isLoading: isLoading ?? this.isLoading,
      continueWatching: continueWatching ?? this.continueWatching,
      dynamicFeeds: dynamicFeeds ?? this.dynamicFeeds,
      isLoadingFeed: isLoadingFeed ?? this.isLoadingFeed,
      feedPagesLoaded: feedPagesLoaded ?? this.feedPagesLoaded,
    );
  }
}

class HomeNotifier extends Notifier<HomeState> {
  late final IMusicRepository musicRepo;
  
  late final LastfmService lastfmService;

  @override
  HomeState build() {
    musicRepo = locator<IMusicRepository>();
    
    lastfmService = locator<LastfmService>();
    Future.microtask(() {
      _initCategory();
      loadHomepageData();
    });
    return const HomeState();
  }

  Future<void> _initCategory() async {
    final cat = await StorageService.loadDefaultCategory();
    state = state.copyWith(selectedCategory: cat);
    if ((state.dynamicFeeds[cat] ?? []).isEmpty) {
      loadMoreFeed();
    }
  }

  Future<void> selectCategory(String category) async {
    state = state.copyWith(selectedCategory: category);

    if (category == "Podcasts" && state.podcastPlaylists.isEmpty) {
      await fetchPodcasts();
    } else if (category == "For You" && state.moodPlaylists.isEmpty) {
      await fetchMoods();
    } else if (category == "Charts" && state.chartPlaylists.isEmpty) {
      await fetchCharts();
    } else if (category == "Music") {
      final futures = <Future>[];
      if (state.hollywoodSongs.isEmpty) futures.add(fetchHollywoodSongs());
      if (state.bollywoodSongs.isEmpty) futures.add(fetchBollywoodSongs());
      if (state.punjabiSongs.isEmpty) futures.add(fetchPunjabiSongs());
      if (state.teluguSongs.isEmpty) futures.add(fetchTeluguSongs());
      if (state.tamilSongs.isEmpty) futures.add(fetchTamilSongs());
      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }
    }

    // Auto load first feed page for category if empty
    if ((state.dynamicFeeds[category] ?? []).isEmpty) {
      loadMoreFeed();
    }
  }

  Future<void> loadMoreFeed() async {
    final cat = state.selectedCategory;
    if (state.isLoadingFeed[cat] == true) return;
    final int currentPage = state.feedPagesLoaded[cat] ?? 0;

    // STOP POINT for infinite scroll: Max 20 dynamic paginations per tab
    if (currentPage >= 20) return;

    state = state.copyWith(isLoadingFeed: {...state.isLoadingFeed, cat: true});

    try {
      final newShelves = await _generateShelvesForCategory(cat, currentPage);
      final currentFeeds = state.dynamicFeeds[cat] ?? [];

      state = state.copyWith(
        dynamicFeeds: {
          ...state.dynamicFeeds,
          cat: [...currentFeeds, ...newShelves],
        },
        isLoadingFeed: {...state.isLoadingFeed, cat: false},
        feedPagesLoaded: {...state.feedPagesLoaded, cat: currentPage + 1},
      );
    } catch (e) {
      debugPrint('[HomeNotifier] loadMoreFeed error: $e');
      state = state.copyWith(
        isLoadingFeed: {...state.isLoadingFeed, cat: false},
      );
    }
  }

  Future<List<FeedShelf>> _generateShelvesForCategory(
    String category,
    int page,
  ) async {
    final newShelves = <FeedShelf>[];

    try {
      if (category == 'Music') {
        // Endless scrolling through Curated Categories
        final offsets = [
          ['Pop', 'Hip Hop', 'R&B', 'Electronic', 'Rock'],
          ['Indie', 'Jazz', 'Classical', 'K-Pop', 'Chill'],
          ['Gaming', 'Workout', 'Romance', 'Party', 'Acoustic'],
          ['Country', 'Folk', 'Metal', 'Punk', 'Focus']
        ];
        final idx = page % offsets.length;
        final queries = offsets[idx];
        
        for (var query in queries) {
          final playlists = await musicRepo.searchPlaylists(query, count: 10);
          if (playlists.isNotEmpty) {
            newShelves.add(FeedShelf(title: '$query Trending', type: ShelfType.playlistCarousel, items: playlists));
          }
        }
      } else if (category == 'For You') {
        // Multi-source Recommendation Engine: Personal Mixes + Onboarding
        
        final favoriteArtists = await StorageService.getFavoriteArtists();
        final baseArtists = favoriteArtists.isNotEmpty 
            ? List<String>.from(favoriteArtists)
            : ['Arijit Singh', 'The Weeknd', 'Taylor Swift', 'Pritam', 'Travis Scott'];

        // Removed Last.fm integration for legal compliance
        
        // Mix in some vibe queries for variety
        final moodQueries = ['Daily Mix', 'New Releases', 'Discover', 'Chill', 'Acoustic', 'Top Hits', 'Focus', 'Workout'];
        
        // Randomly shuffle our pool to ensure infinite dynamic generation
        baseArtists.shuffle();
        moodQueries.shuffle();
        
        // Pick 2 artists and 2 moods per page to ensure enough content fills the screen for scrolling
        final selectedArtists = baseArtists.isNotEmpty ? baseArtists.take(2).toList() : ['Pop', 'Rock'];
        final selectedMoods = moodQueries.take(2).toList();
        
        for (int i = 0; i < 2; i++) {
           final artist = selectedArtists[i % selectedArtists.length];
           final mood = selectedMoods[i % selectedMoods.length];
           
           // Shelf 1: Artist based
           final artistPlaylists = await musicRepo.searchPlaylists(artist, count: 10);
           if (artistPlaylists.isNotEmpty) {
              newShelves.add(FeedShelf(
                 title: 'Because you like $artist',
                 type: ShelfType.playlistCarousel,
                 items: artistPlaylists,
              ));
           }
           
           // Shelf 2: Mood based or Dynamic combo
           final isCombo = (page + i) % 3 != 0;
           final dynamicQuery = isCombo ? '$artist $mood' : mood;
           final dynamicPlaylists = await musicRepo.searchPlaylists(dynamicQuery, count: 10);
           
           if (dynamicPlaylists.isNotEmpty) {
              final title = isCombo ? '$mood for $artist fans' : mood;
              newShelves.add(FeedShelf(
                 title: title,
                 type: ShelfType.playlistCarousel,
                 items: dynamicPlaylists,
              ));
           }
        }
      } else if (category == 'Podcasts') {
        final ytIMusicRepository = locator<IMusicRepository>();
        final offsets = [
          ['True Crime', 'Comedy', 'Educational', 'Business', 'Technology'],
          ['News', 'Health', 'Sports', 'Pop Culture', 'History'],
          ['Society', 'Science', 'Arts', 'Fiction', 'Music Commentary']
        ];
        
        final idx = page % offsets.length;
        final queries = offsets[idx];
        
        for (var query in queries) {
          final podcasts = await ytIMusicRepository.searchPodcasts('$query Podcast', count: 10);
          if (podcasts.isNotEmpty) {
            newShelves.add(FeedShelf(title: '$query Podcasts', type: ShelfType.songCarousel, items: podcasts));
          }
        }
      } else if (category == 'Charts') {
        if (page == 0) {
          final charts = await musicRepo.getCharts();
          if (charts['playlists'] != null && charts['playlists'].isNotEmpty) {
             newShelves.add(FeedShelf(title: 'The Global Soundscape', type: ShelfType.playlistCarousel, items: charts['playlists']));
          }
        }
        final offsets = [
          [
            {'q': 'Global Top 50', 't': 'Stateside Supremacy'}, 
            {'q': 'UK Top 40', 't': 'UK Chart Toppers'}, 
            {'q': 'Viral Hits', 't': 'Viral Frequencies'}
          ],
          [
            {'q': 'Top 50 Hits', 't': 'Hits of the Moment'}, 
            {'q': 'Billboard', 't': 'Billboard Titans'}, 
            {'q': 'TikTok Trending', 't': 'Trending on TikTok'}
          ]
        ];
        
        final idx = page % offsets.length;
        final queries = offsets[idx];
        
        for (var item in queries) {
          final playlists = await musicRepo.searchPlaylists(item['q']!, count: 10);
          if (playlists.isNotEmpty) {
             newShelves.add(FeedShelf(title: item['t']!, type: ShelfType.playlistCarousel, items: playlists));
          }
        }
      }

    } catch (e) {
      debugPrint('[HomeNotifier] Error generating shelf for $category: $e');
    }

    return newShelves;
  }

    bool _isInstrumentalOrJunk(Song s) {
    final title = s.title.toLowerCase();
    const junk = [
      'instrumental',
      'karaoke',
      'ringtone',
      'flute version',
      'flute cover',
      'flute',
      'piano version',
      'piano cover',
      'guitar cover',
      'background score',
      'bgm',
      'soundtrack version',
      'theme music',
      'tribute to',
      'meditation',
      'sleep music',
      'relaxing music',
      'slowed reverb',
      'slowed+reverb',
      'lofi flip',
      'orchestral version',
      'synthesizer',
      'shehnai',
      'tabla solo',
      'santoor',
      'sitar',
    ];
    for (final j in junk) {
      if (title.contains(j)) return true;
    }
    return false;
  }

  List<Song> _deduplicate(List<Song> songs) {
    final Map<String, Song> unique = {};
    for (var s in songs) {
      if (s.title.isEmpty) continue;
      String cleanTitle = s.title
          .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
          .replaceAll(RegExp(r'\s*-\s*.*'), '')
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '')
          .trim();
      if (cleanTitle.isEmpty) {
        cleanTitle = s.title
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]'), '')
            .trim();
      }
      String artistClean = s.artist
          .split(',')
          .first
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '')
          .trim();
      String uniqueKey = '${cleanTitle}_$artistClean';
      if (uniqueKey.isNotEmpty && !unique.containsKey(uniqueKey)) {
        unique[uniqueKey] = s;
      }
    }
    return unique.values.toList();
  }

  Future<void> fetchBollywoodSongs() async {
    try {
      final data = await musicRepo.getChartsByLanguage('hindi');
      var tracks = (data['tracks'] as List<Song>? ?? [])
          .where((s) => !_isInstrumentalOrJunk(s))
          .toList();
      var playlists = data['playlists'] as List<Playlist>? ?? [];

      if (playlists.isEmpty) {
        playlists = await musicRepo.getFeaturedPlaylistsByLanguage('hindi');
      }

      if (tracks.length < 15 && playlists.isNotEmpty) {
        final moreTracks = await musicRepo.getPlaylistTracks(playlists.first.id);
        tracks = _deduplicate([...tracks, ...moreTracks])
            .where((s) => !_isInstrumentalOrJunk(s))
            .toList();
      }

      state = state.copyWith(
        bollywoodSongs: tracks.isNotEmpty ? tracks : state.bollywoodSongs,
        bollywoodPlaylists: playlists.isNotEmpty ? playlists : state.bollywoodPlaylists,
      );
    } catch (e) {
      debugPrint('[HomeNotifier] fetchBollywoodSongs error: $e');
    }
  }

  Future<void> fetchTeluguSongs() async {
    try {
      final data = await musicRepo.getChartsByLanguage('telugu');
      var tracks = (data['tracks'] as List<Song>? ?? [])
          .where((s) => !_isInstrumentalOrJunk(s))
          .toList();
      var playlists = data['playlists'] as List<Playlist>? ?? [];

      if (playlists.isEmpty) {
        playlists = await musicRepo.getFeaturedPlaylistsByLanguage('telugu');
      }

      if (tracks.length < 15 && playlists.isNotEmpty) {
        final moreTracks = await musicRepo.getPlaylistTracks(playlists.first.id);
        tracks = _deduplicate([...tracks, ...moreTracks])
            .where((s) => !_isInstrumentalOrJunk(s))
            .toList();
      }

      state = state.copyWith(
        teluguSongs: tracks.isNotEmpty ? tracks : state.teluguSongs,
        teluguPlaylists: playlists.isNotEmpty ? playlists : state.teluguPlaylists,
      );
    } catch (e) {
      debugPrint('[HomeNotifier] fetchTeluguSongs error: $e');
    }
  }

  Future<void> fetchTamilSongs() async {
    try {
      final data = await musicRepo.getChartsByLanguage('tamil');
      var tracks = (data['tracks'] as List<Song>? ?? [])
          .where((s) => !_isInstrumentalOrJunk(s))
          .toList();
      var playlists = data['playlists'] as List<Playlist>? ?? [];

      if (playlists.isEmpty) {
        playlists = await musicRepo.getFeaturedPlaylistsByLanguage('tamil');
      }

      if (tracks.length < 15 && playlists.isNotEmpty) {
        final moreTracks = await musicRepo.getPlaylistTracks(playlists.first.id);
        tracks = _deduplicate([...tracks, ...moreTracks])
            .where((s) => !_isInstrumentalOrJunk(s))
            .toList();
      }

      state = state.copyWith(
        tamilSongs: tracks.isNotEmpty ? tracks : state.tamilSongs,
        tamilPlaylists: playlists.isNotEmpty ? playlists : state.tamilPlaylists,
      );
    } catch (e) {
      debugPrint('[HomeNotifier] fetchTamilSongs error: $e');
    }
  }

  Future<void> fetchPunjabiSongs() async {
    try {
      final data = await musicRepo.getChartsByLanguage('punjabi');
      var tracks = (data['tracks'] as List<Song>? ?? [])
          .where((s) => !_isInstrumentalOrJunk(s))
          .toList();
      var playlists = data['playlists'] as List<Playlist>? ?? [];

      if (playlists.isEmpty) {
        playlists = await musicRepo.getFeaturedPlaylistsByLanguage('punjabi');
      }

      if (tracks.length < 15 && playlists.isNotEmpty) {
        final moreTracks = await musicRepo.getPlaylistTracks(playlists.first.id);
        tracks = _deduplicate([...tracks, ...moreTracks])
            .where((s) => !_isInstrumentalOrJunk(s))
            .toList();
      }

      state = state.copyWith(
        punjabiSongs: tracks.isNotEmpty ? tracks : state.punjabiSongs,
        punjabiPlaylists: playlists.isNotEmpty ? playlists : state.punjabiPlaylists,
      );
    } catch (e) {
      debugPrint('[HomeNotifier] fetchPunjabiSongs error: $e');
    }
  }

  Future<void> fetchHollywoodSongs() async {
    try {
      final data = await musicRepo.getChartsByLanguage('english');
      var tracks = (data['tracks'] as List<Song>? ?? [])
          .where((s) => s.language.toLowerCase() == 'english' && !_isInstrumentalOrJunk(s))
          .toList();
      var playlists = data['playlists'] as List<Playlist>? ?? [];

      if (playlists.isEmpty) {
        playlists = await musicRepo.getFeaturedPlaylistsByLanguage('english');
      }

      if (tracks.length < 15 && playlists.isNotEmpty) {
        final moreTracks = await musicRepo.getPlaylistTracks(playlists.first.id);
        tracks = _deduplicate([...tracks, ...moreTracks])
            .where((s) => s.language.toLowerCase() == 'english' && !_isInstrumentalOrJunk(s))
            .toList();
      }

      state = state.copyWith(
        hollywoodSongs: tracks.isNotEmpty ? tracks : state.hollywoodSongs,
        hollywoodPlaylists: playlists.isNotEmpty ? playlists : state.hollywoodPlaylists,
      );
    } catch (e) {
      debugPrint('[HomeNotifier] fetchHollywoodSongs error: $e');
    }
  }

  Future<void> fetchPodcasts() async {
    try {
      final random = Random();
      final keywords = [
        'Motivation podcast',
        'Tech podcast',
        'True crime podcast',
      ];
      final creators = ['The Ranveer Show', 'Jay Shetty', 'Huberman Lab'];

      final ytIMusicRepository = locator<IMusicRepository>();

      final list1 = await ytIMusicRepository.searchPodcasts(
        keywords[random.nextInt(keywords.length)],
        count: 10,
      );
      final list2 = await ytIMusicRepository.searchPodcasts(
        creators[random.nextInt(creators.length)],
        count: 10,
      );

      final combined = _deduplicate([...list1, ...list2]);
      state = state.copyWith(
        podcastSongs: combined.isNotEmpty ? combined : state.podcastSongs,
        podcastPlaylists: await musicRepo.searchPlaylists("Podcast", count: 10)
      );
    } catch (e) {
      debugPrint('[HomeNotifier] fetchPodcasts error: $e');
    }
  }

  Future<void> fetchIndianAlbums() async {
    try {
      final hindiAlbums = await musicRepo.searchAlbums("Hindi", count: 25);
      final teluguAlbums = await musicRepo.searchAlbums("Telugu", count: 25);
      final tamilAlbums = await musicRepo.searchAlbums("Tamil", count: 25);
      final punjabiAlbums = await musicRepo.searchAlbums("Punjabi", count: 25);

      final combined = <Playlist>[
        ...hindiAlbums,
        ...teluguAlbums,
        ...tamilAlbums,
        ...punjabiAlbums,
      ];
      final Map<String, Playlist> unique = {};
      for (var album in combined) {
        if (album.id.isNotEmpty) unique[album.id] = album;
      }
      if (unique.isNotEmpty) {
        state = state.copyWith(topAlbums: unique.values.toList());
      }
    } catch (_) {}
  }

  Future<void> fetchYouSongs(List<String> historyArtists) async {
    if (state.youSongs.isNotEmpty) return;
    state = state.copyWith(isLoading: true);

    try {
      final favoriteArtists = await StorageService.getFavoriteArtists();
      if (favoriteArtists.isNotEmpty) favoriteArtists.shuffle();
      
      var queryArtists = favoriteArtists.isNotEmpty
          ? favoriteArtists
          : (historyArtists.isNotEmpty
            ? historyArtists
            : (state.trendingSongs.isNotEmpty
                  ? state.trendingSongs
                        .map((e) => e.artist.split(',').first.trim())
                        .where((a) => a.isNotEmpty)
                        .toSet()
                        .toList()
                  : ['Arijit Singh', 'Pritam', 'The Weeknd', 'Taylor Swift']));

      if (queryArtists.isEmpty) {
        queryArtists = ['Arijit Singh', 'Pritam', 'The Weeknd', 'Taylor Swift'];
      }
      
      // Shuffle to ensure daily changing mixes if there are many artists
      queryArtists.shuffle();

      final newSongs = <Song>[];
      final newPlaylists = <Playlist>[];

      final Set<String> usedCovers = {};

      for (var artist in queryArtists.take(10)) {
        final res = await musicRepo.searchSongs(artist, count: 20);
        if (res.isNotEmpty) {
          String selectedCover = '';
          for (var song in res) {
            if (song.coverArt.isNotEmpty &&
                !usedCovers.contains(song.coverArt)) {
              selectedCover = song.coverArt;
              usedCovers.add(song.coverArt);
              break;
            }
          }
          if (selectedCover.isEmpty) {
            selectedCover = res.first.coverArt;
          }

          final dedupedRes = _deduplicate(res);
          newPlaylists.add(
            Playlist(
              id: 'mix_${artist.replaceAll(' ', '_')}',
              title: 'Daily Mix: $artist',
              type: 'playlist',
              coverArt: selectedCover,
              songCount: dedupedRes.length,
              songs: dedupedRes,
            ),
          );
          newSongs.addAll(dedupedRes);
        }
      }

      var finalYou = newSongs.isEmpty
          ? state.trendingSongs.take(10).toList()
          : newSongs;
      finalYou = _deduplicate(finalYou);

      state = state.copyWith(youSongs: finalYou, youPlaylists: newPlaylists, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void toggleMoodLanguage() {
    final newLang = state.moodLanguage == 'English' ? 'Hindi' : 'English';
    state = state.copyWith(moodLanguage: newLang);
    fetchMoods();
  }

  Future<void> fetchMoods() async {
    if (state.isLoadingMoods) return;
    state = state.copyWith(isLoadingMoods: true);

    try {
      final moods = ['Chill', 'Party', 'Lofi', 'Romance', 'Workout'];
      final futures = moods.map<Future<List<Playlist>>>(
        (mood) =>
            musicRepo.searchPlaylists('${state.moodLanguage} $mood', count: 4),
      );
      final results = await Future.wait(futures);

      final moodList = <Playlist>[];
      for (var result in results) {
        if (result.isNotEmpty) moodList.addAll(result);
      }

      final seen = <String>{};
      var finalMoods = moodList
          .where((p) => p.coverArt.isNotEmpty && seen.add(p.id))
          .toList();
      if (finalMoods.isEmpty) {
        finalMoods = state.topPlaylists
            .where((p) => p.type == 'playlist')
            .take(5)
            .toList();
      }

      state = state.copyWith(moodPlaylists: finalMoods, isLoadingMoods: false);
    } catch (_) {
      state = state.copyWith(isLoadingMoods: false);
    }
  }

  Future<void> fetchCharts() async {
    if (state.chartPlaylists.isNotEmpty || state.isLoadingCharts) return;
    state = state.copyWith(isLoadingCharts: true);

    try {
      final queries = ['Top 50', 'Billboard', 'Viral', 'Global 100'];
      final futures = queries.map<Future<List<Playlist>>>(
        (query) => musicRepo.searchPlaylists(query, count: 8),
      );
      final results = await Future.wait(futures);

      final chartList = <Playlist>[];
      for (var result in results) {
        if (result.isNotEmpty) chartList.addAll(result);
      }

      final seen = <String>{};
      var finalCharts = chartList.where((p) => seen.add(p.id)).toList();
      if (finalCharts.isEmpty) {
        finalCharts = state.topPlaylists
            .where((p) => p.type == 'playlist')
            .take(5)
            .toList();
      }

      state = state.copyWith(
        chartPlaylists: finalCharts,
        isLoadingCharts: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingCharts: false);
    }
  }

  Future<void> loadHomepageData([BuildContext? context]) async {
    state = state.copyWith(isLoading: true);

    List<Song> trending = [];
    List<Playlist> rawPlaylists = [];

    try {
      // Primary discovery via Saavn Charts
      final charts = await musicRepo.getCharts();
      if (charts['tracks'].isNotEmpty) {
        trending = charts['tracks'];
        rawPlaylists = charts['playlists'];
        debugPrint('[HomeNotifier] Loaded storefront via Saavn Charts API');
      } else {
        final data = await musicRepo.fetchHomepageData(
          onError: (message) {
            if (context != null) {
              ErrorReporter.showError(context, message);
            }
          },
        );
        final rawTrending = data['trending'] as List? ?? [];
        trending = rawTrending.map((e) => e is Song ? e : Song.fromJson(e)).toList();
        if (trending.isEmpty) {
          trending = await musicRepo.searchSongs("Top Global Hits 2026", count: 30);
        }
        trending = trending.where((s) => !_isInstrumentalOrJunk(s)).toList();
        
        final rawPl = data['playlists'] as List? ?? [];
        rawPlaylists = rawPl.map((e) => e is Playlist ? e : Playlist.fromJson(e)).toList();
        debugPrint('[HomeNotifier] Loaded storefront via Saavn Home Feed');
      }
    } catch (e) {
      debugPrint('[HomeNotifier] Saavn storefront API failed: $e');
    }

    final continueWatchingList = await DatabaseService.getContinueWatching();

    state = state.copyWith(
      trendingSongs: trending,
      topPlaylists: rawPlaylists,
      topAlbums: rawPlaylists.where((p) => p.type == 'album').toList(),
      continueWatching: continueWatchingList,
      isLoading: false,
    );

    fetchBollywoodSongs();
    fetchTeluguSongs();
    fetchTamilSongs();
    fetchPunjabiSongs();
    fetchHollywoodSongs();
    fetchIndianAlbums();
  }
}

typedef HomeProvider = HomeNotifier;
