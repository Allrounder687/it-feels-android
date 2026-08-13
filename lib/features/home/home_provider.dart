import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/utils/error_reporter.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/models/feed_shelf.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/data/services/deezer_api_service.dart';
import 'package:it_feels_music/services/lastfm_service.dart';
import 'package:it_feels_music/services/storage_service.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/services/database_service.dart';
import 'package:it_feels_music/data/services/youtube_podcast_provider.dart';

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
  late final MusicApiService saavnApi;
  late final DeezerApiService deezerApi;
  late final LastfmService lastfmService;

  @override
  HomeState build() {
    saavnApi = locator.isRegistered<MusicApiService>() ? locator<MusicApiService>() : MusicApiService();
    deezerApi = locator.isRegistered<DeezerApiService>() ? locator<DeezerApiService>() : DeezerApiService();
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
    } else if (category == "Music" && state.hollywoodSongs.isEmpty) {
      await fetchHollywoodSongs();
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
        // Endless scrolling through Deezer Curated Categories
        final offsets = [
          ['Pop', 'Hip Hop', 'R&B', 'Electronic', 'Rock'],
          ['Indie', 'Jazz', 'Classical', 'K-Pop', 'Chill'],
          ['Gaming', 'Workout', 'Romance', 'Party', 'Acoustic'],
          ['Country', 'Folk', 'Metal', 'Punk', 'Focus']
        ];
        final idx = page % offsets.length;
        final queries = offsets[idx];
        
        for (var query in queries) {
          final playlists = await saavnApi.searchPlaylists(query, count: 10);
          if (playlists.isNotEmpty) {
            newShelves.add(FeedShelf(title: '$query Trending', type: ShelfType.playlistCarousel, items: playlists));
          }
        }
      } else if (category == 'For You') {
        // Multi-source Recommendation Engine: Last.fm + Deezer + Onboarding
        
        final favoriteArtists = await StorageService.getFavoriteArtists();
        final baseArtists = favoriteArtists.isNotEmpty 
            ? List<String>.from(favoriteArtists)
            : ['Arijit Singh', 'The Weeknd', 'Taylor Swift', 'Pritam', 'Travis Scott'];

        // Mix in Last.fm if logged in
        final isLoggedIn = await lastfmService.isLoggedIn();
        if (isLoggedIn) {
           final username = await lastfmService.getUsername();
           if (username != null) {
              final topTracks = await lastfmService.getUserTopTracks(username, limit: 10);
              for (var track in topTracks) {
                 final artistName = track['artist']['name'];
                 if (artistName != null && !baseArtists.contains(artistName)) {
                     baseArtists.add(artistName);
                 }
              }
           }
        }
        
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
           final artistPlaylists = await saavnApi.searchPlaylists(artist, count: 10);
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
           final dynamicPlaylists = await saavnApi.searchPlaylists(dynamicQuery, count: 10);
           
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
        final ytPodcastProvider = YouTubePodcastProvider();
        final offsets = [
          ['True Crime', 'Comedy', 'Educational', 'Business', 'Technology'],
          ['News', 'Health', 'Sports', 'Pop Culture', 'History'],
          ['Society', 'Science', 'Arts', 'Fiction', 'Music Commentary']
        ];
        
        final idx = page % offsets.length;
        final queries = offsets[idx];
        
        for (var query in queries) {
          final podcasts = await ytPodcastProvider.searchPodcasts('$query Podcast', count: 10);
          if (podcasts.isNotEmpty) {
            newShelves.add(FeedShelf(title: '$query Podcasts', type: ShelfType.songCarousel, items: podcasts));
          }
        }
      } else if (category == 'Charts') {
        if (page == 0) {
          final charts = await deezerApi.getCharts();
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
          final playlists = await saavnApi.searchPlaylists(item['q']!, count: 10);
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
      final random = Random();
      final keywords = ['Hindi Songs', 'Bollywood Hits', 'Latest Hindi'];
      final artists = ['Arijit Singh', 'Shreya Ghoshal', 'Pritam'];

      final list1 = await saavnApi.searchSongs(
        keywords[random.nextInt(keywords.length)],
        count: 30,
      );
      final list2 = await saavnApi.searchSongs(
        artists[random.nextInt(artists.length)],
        count: 30,
      );
      final list3 = await saavnApi.searchSongs(
        "Hindi Romantic Hits",
        count: 30,
      );
      final playlists = await saavnApi.searchPlaylists(
        "Bollywood Hits",
        count: 20,
      );

      final combined = _deduplicate([...list1, ...list2, ...list3]);
      state = state.copyWith(
        bollywoodSongs: combined.isNotEmpty ? combined : state.bollywoodSongs,
        bollywoodPlaylists: playlists.isNotEmpty
            ? playlists
            : state.bollywoodPlaylists,
      );
    } catch (_) {}
  }

  Future<void> fetchTeluguSongs() async {
    try {
      final random = Random();
      final keywords = ['Telugu Songs', 'Tollywood Hits', 'Latest Telugu'];
      final artists = ['Sid Sriram Telugu', 'Devi Sri Prasad', 'Thaman S'];

      final list1 = await saavnApi.searchSongs(
        keywords[random.nextInt(keywords.length)],
        count: 30,
      );
      final list2 = await saavnApi.searchSongs(
        artists[random.nextInt(artists.length)],
        count: 30,
      );
      final list3 = await saavnApi.searchSongs(
        "Telugu Melody Hits",
        count: 30,
      );
      final playlists = await saavnApi.searchPlaylists(
        "Telugu Hits",
        count: 20,
      );

      final combined = _deduplicate([...list1, ...list2, ...list3]);
      state = state.copyWith(
        teluguSongs: combined.isNotEmpty ? combined : state.teluguSongs,
        teluguPlaylists: playlists.isNotEmpty
            ? playlists
            : state.teluguPlaylists,
      );
    } catch (_) {}
  }

  Future<void> fetchTamilSongs() async {
    try {
      final random = Random();
      final keywords = ['Tamil Songs', 'Kollywood Hits', 'Latest Tamil'];
      final artists = [
        'Anirudh Ravichander',
        'A.R. Rahman Tamil',
        'Yuvan Shankar Raja',
      ];

      final list1 = await saavnApi.searchSongs(
        keywords[random.nextInt(keywords.length)],
        count: 30,
      );
      final list2 = await saavnApi.searchSongs(
        artists[random.nextInt(artists.length)],
        count: 30,
      );
      final list3 = await saavnApi.searchSongs(
        "Tamil Melody Hits",
        count: 30,
      );
      final playlists = await saavnApi.searchPlaylists(
        "Tamil Hits",
        count: 20,
      );

      final combined = _deduplicate([...list1, ...list2, ...list3]);
      state = state.copyWith(
        tamilSongs: combined.isNotEmpty ? combined : state.tamilSongs,
        tamilPlaylists: playlists.isNotEmpty ? playlists : state.tamilPlaylists,
      );
    } catch (_) {}
  }

  Future<void> fetchPunjabiSongs() async {
    try {
      final random = Random();
      final keywords = ['Punjabi Songs', 'Punjabi Hits', 'Latest Punjabi'];
      final artists = ['Karan Aujla', 'Diljit Dosanjh', 'AP Dhillon'];

      final list1 = await saavnApi.searchSongs(
        keywords[random.nextInt(keywords.length)],
        count: 30,
      );
      final list2 = await saavnApi.searchSongs(
        artists[random.nextInt(artists.length)],
        count: 30,
      );
      final list3 = await saavnApi.searchSongs(
        "Punjabi Party Hits",
        count: 30,
      );
      final playlists = await saavnApi.searchPlaylists(
        "Punjabi Hits",
        count: 20,
      );

      final combined = _deduplicate([...list1, ...list2, ...list3]);
      state = state.copyWith(
        punjabiSongs: combined.isNotEmpty ? combined : state.punjabiSongs,
        punjabiPlaylists: playlists.isNotEmpty
            ? playlists
            : state.punjabiPlaylists,
      );
    } catch (_) {}
  }

  Future<void> fetchHollywoodSongs() async {
    try {
      final random = Random();
      final artists = [
        'Taylor Swift',
        'The Weeknd',
        'Dua Lipa',
        'Ed Sheeran',
        'Billie Eilish',
        'Post Malone',
        'Drake',
        'Ariana Grande',
        'Justin Bieber',
        'Bruno Mars',
        'Eminem',
        'Rihanna',
        'Coldplay',
        'Imagine Dragons',
        'Maroon 5',
        'Shawn Mendes',
      ];
      final artist1 = artists.removeAt(random.nextInt(artists.length));
      final artist2 = artists.removeAt(random.nextInt(artists.length));
      final artist3 = artists.removeAt(random.nextInt(artists.length));

      final list1 = await saavnApi.searchSongs(artist1, count: 30);
      final list2 = await saavnApi.searchSongs(artist2, count: 30);
      final list3 = await saavnApi.searchSongs(artist3, count: 30);
      final playlists = await saavnApi.searchPlaylists(
        "English Pop",
        count: 20,
      );

      final combined = _deduplicate([...list1, ...list2, ...list3]);
      state = state.copyWith(
        hollywoodSongs: combined.isNotEmpty ? combined : state.hollywoodSongs,
        hollywoodPlaylists: playlists.isNotEmpty
            ? playlists
            : state.hollywoodPlaylists,
      );
    } catch (_) {}
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

      final ytPodcastProvider = YouTubePodcastProvider();

      final list1 = await ytPodcastProvider.searchPodcasts(
        keywords[random.nextInt(keywords.length)],
        count: 10,
      );
      final list2 = await ytPodcastProvider.searchPodcasts(
        creators[random.nextInt(creators.length)],
        count: 10,
      );

      final combined = _deduplicate([...list1, ...list2]);
      state = state.copyWith(
        podcastSongs: combined.isNotEmpty ? combined : state.podcastSongs,
        podcastPlaylists: [], // Disabled: we only fetch podcasts natively via YouTube Explode now
      );
    } catch (e) {
      debugPrint('[HomeNotifier] fetchPodcasts error: $e');
    }
  }

  Future<void> fetchIndianAlbums() async {
    try {
      final hindiAlbums = await saavnApi.searchAlbums("Hindi", count: 25);
      final teluguAlbums = await saavnApi.searchAlbums("Telugu", count: 25);
      final tamilAlbums = await saavnApi.searchAlbums("Tamil", count: 25);
      final punjabiAlbums = await saavnApi.searchAlbums("Punjabi", count: 25);

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

  Future<void> fetchYouSongs(List<String> topArtists) async {
    if (state.youSongs.isNotEmpty) return;

    try {
      final favoriteArtists = await StorageService.getFavoriteArtists();
      if (favoriteArtists.isNotEmpty) favoriteArtists.shuffle();
      
      var queryArtists = favoriteArtists.isNotEmpty
          ? favoriteArtists
          : (topArtists.isNotEmpty
            ? topArtists
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
        final res = await saavnApi.searchSongs(artist, count: 20);
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

      state = state.copyWith(youSongs: finalYou, youPlaylists: newPlaylists);
    } catch (_) {}
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
            saavnApi.searchPlaylists('${state.moodLanguage} $mood', count: 4),
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
        (query) => saavnApi.searchPlaylists(query, count: 8),
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
      // Primary discovery via Deezer Charts
      final charts = await deezerApi.getCharts();
      if (charts['tracks'].isNotEmpty) {
        trending = charts['tracks'];
        rawPlaylists = charts['playlists'];
        debugPrint('[HomeNotifier] Loaded storefront via Deezer API');
      } else {
        // Fallback to Saavn if Deezer is fully restricted
        final data = await saavnApi.fetchHomepageData(
          onError: (message) {
            if (context != null) {
              ErrorReporter.showError(context, message);
            }
          },
        );
        trending = List<Song>.from(data['trending'] ?? []);
        rawPlaylists = List<Playlist>.from(data['playlists'] ?? []);
        debugPrint('[HomeNotifier] Loaded storefront via Saavn Fallback');
      }
    } catch (e) {
      debugPrint('[HomeNotifier] Deezer/Saavn API failed: $e');
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
    fetchIndianAlbums();
  }
}

typedef HomeProvider = HomeNotifier;
