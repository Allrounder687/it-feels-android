import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/core/utils/error_reporter.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/models/feed_shelf.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/services/storage_service.dart';
import 'package:it_feels_music/services/database_service.dart';
import 'package:it_feels_music/data/services/youtube_podcast_provider.dart';
import 'package:it_feels_music/data/services/spotify_api_service.dart';

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
  late final MusicApiService apiService;

  @override
  HomeState build() {
    apiService = locator.isRegistered<MusicApiService>()
        ? locator<MusicApiService>()
        : MusicApiService();
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

    // STOP POINT for infinite scroll: Max 5 dynamic paginations per tab
    if (currentPage >= 5) return;

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
    List<List<dynamic>> queries = [];

    // Dynamic extraction from current state
    final topArtists = state.trendingSongs
        .map((e) => e.artist.split(',').first.trim())
        .where((a) => a.isNotEmpty)
        .toSet()
        .toList();
    topArtists.shuffle();
    final randArtist1 = topArtists.isNotEmpty ? topArtists[0] : 'Arijit Singh';
    final randArtist2 = topArtists.length > 1 ? topArtists[1] : 'The Weeknd';
    final randArtist3 = topArtists.length > 2
        ? topArtists[2]
        : 'Shreya Ghoshal';

    if (category == 'For You') {
      queries = [
        ['Featured Artists', ShelfType.artistGrid, randArtist1],
        [
          'Recommended Stations',
          ShelfType.playlistCarousel,
          '$randArtist1 Mix',
        ],
        ['Chill Mix', ShelfType.songCarousel, 'playlist:Chill Mix'],
        ['Biggest Hits', ShelfType.songCarousel, randArtist2],
        ['Artists You Might Like', ShelfType.artistGrid, randArtist3],
        ['Party', ShelfType.playlistCarousel, 'Party Hits'],
        ['Late Night Vibes', ShelfType.songCarousel, 'playlist:Late Night'],
        ['Discover Weekly', ShelfType.playlistCarousel, 'Discover'],
        ['Acoustic Covers', ShelfType.songCarousel, 'playlist:Acoustic Covers'],
        ['Trending Producers', ShelfType.artistGrid, 'Producer'],
      ];
    } else if (category == 'Music') {
      queries = [
        ['Global Top Artists', ShelfType.artistGrid, 'Global Hits'],
        ['New Music Friday', ShelfType.playlistCarousel, 'New Releases'],
        ['Pop Rising', ShelfType.songCarousel, 'playlist:Pop Rising'],
        ['Indie Hits', ShelfType.playlistCarousel, 'Indie'],
        ['Rock Classics', ShelfType.songCarousel, 'playlist:Rock Classics'],
        ['Rising Artists', ShelfType.artistGrid, 'Rising Artists'],
        ['Hip Hop Nation', ShelfType.playlistCarousel, 'Hip Hop'],
        ['Electronic Dance', ShelfType.songCarousel, 'playlist:EDM Top'],
        ['R&B Grooves', ShelfType.playlistCarousel, 'R&B'],
        ['Jazz & Blues', ShelfType.artistGrid, 'Jazz'],
      ];
    } else if (category == 'Podcasts') {
      queries = [
        ['Top Creators', ShelfType.artistGrid, 'Podcast channels'],
        ['True Crime', ShelfType.playlistCarousel, 'True Crime Podcast'],
        [
          'Comedy Specials',
          ShelfType.songCarousel,
          'Comedy Podcast full episode',
        ],
        ['Educational', ShelfType.playlistCarousel, 'Educational Podcast'],
        ['Business & Tech', ShelfType.playlistCarousel, 'Business Podcast'],
        ['Daily News', ShelfType.songCarousel, 'News Podcast full episode'],
        ['Health & Wellness', ShelfType.playlistCarousel, 'Health Podcast'],
        ['Sports Talk', ShelfType.songCarousel, 'Sports Podcast full episode'],
        ['Pop Culture', ShelfType.playlistCarousel, 'Pop Culture Podcast'],
        ['Motivation', ShelfType.artistGrid, 'Motivation Podcast'],
      ];
    } else {
      queries = [
        ['Top 50 Global', ShelfType.songCarousel, 'playlist:Top 50 Global'],
        ['Viral Artists', ShelfType.artistGrid, 'Viral'],
        ['Global Viral 50', ShelfType.playlistCarousel, 'Viral 50'],
        ['Billboard Hot 100', ShelfType.playlistCarousel, 'Billboard'],
        ['Top 50 USA', ShelfType.songCarousel, 'playlist:Top 50 USA'],
        ['UK Top 40', ShelfType.playlistCarousel, 'UK Top'],
        ['Top 50 India', ShelfType.songCarousel, 'playlist:Top 50 India'],
        ['Global Top Playlists', ShelfType.playlistCarousel, 'Top Playlists'],
        [
          'Trending on TikTok',
          ShelfType.songCarousel,
          'playlist:TikTok Trending',
        ],
        ['Chart Toppers', ShelfType.artistGrid, 'Chart Toppers'],
      ];
    }

    final start = (page * 2) % queries.length;
    for (var i = start; i < start + 2 && i < queries.length; i++) {
      final title = queries[i][0] as String;
      final type = queries[i][1] as ShelfType;
      final query = queries[i].length > 2 ? queries[i][2] as String : title;

      try {
        if (type == ShelfType.artistGrid) {
          final searchRes = await apiService.searchAll(query);
          final artists = (searchRes['artists'] as List).take(6).toList();
          if (artists.isNotEmpty) {
            newShelves.add(FeedShelf(title: title, type: type, items: artists));
          } else {
            // Fallback
            final songs = await apiService.searchSongs(query, count: 10);
            final artistNames = songs
                .map((s) => s.artist)
                .where((a) => a.isNotEmpty)
                .toSet()
                .take(6)
                .toList();
            if (artistNames.isNotEmpty)
              newShelves.add(
                FeedShelf(title: title, type: type, items: artistNames),
              );
          }
        } else if (type == ShelfType.songCarousel) {
          if (query.startsWith('playlist:')) {
            final actualQuery = query.substring(9);
            final playlists = await apiService.searchPlaylists(
              actualQuery,
              count: 5,
            );
            if (playlists.isNotEmpty) {
              final details = await apiService.fetchPlaylistDetails(
                playlists.first.id,
              );
              final songs = details['songs'] as List<Song>;
              if (songs.isNotEmpty)
                newShelves.add(
                  FeedShelf(title: title, type: type, items: songs),
                );
            }
          } else {
            final songs = await apiService.searchSongs(query, count: 15);
            if (songs.isNotEmpty)
              newShelves.add(FeedShelf(title: title, type: type, items: songs));
          }
        } else if (type == ShelfType.playlistCarousel) {
          final playlists = await apiService.searchPlaylists(query, count: 10);
          if (playlists.isNotEmpty)
            newShelves.add(
              FeedShelf(title: title, type: type, items: playlists),
            );
        }
      } catch (e) {
        debugPrint('[HomeNotifier] Error generating shelf $title: $e');
      }
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

      final list1 = await apiService.searchSongs(
        keywords[random.nextInt(keywords.length)],
        count: 30,
      );
      final list2 = await apiService.searchSongs(
        artists[random.nextInt(artists.length)],
        count: 30,
      );
      final list3 = await apiService.searchSongs(
        "Hindi Romantic Hits",
        count: 30,
      );
      final playlists = await apiService.searchPlaylists(
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

      final list1 = await apiService.searchSongs(
        keywords[random.nextInt(keywords.length)],
        count: 30,
      );
      final list2 = await apiService.searchSongs(
        artists[random.nextInt(artists.length)],
        count: 30,
      );
      final list3 = await apiService.searchSongs(
        "Telugu Melody Hits",
        count: 30,
      );
      final playlists = await apiService.searchPlaylists(
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

      final list1 = await apiService.searchSongs(
        keywords[random.nextInt(keywords.length)],
        count: 30,
      );
      final list2 = await apiService.searchSongs(
        artists[random.nextInt(artists.length)],
        count: 30,
      );
      final list3 = await apiService.searchSongs(
        "Tamil Melody Hits",
        count: 30,
      );
      final playlists = await apiService.searchPlaylists(
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

      final list1 = await apiService.searchSongs(
        keywords[random.nextInt(keywords.length)],
        count: 30,
      );
      final list2 = await apiService.searchSongs(
        artists[random.nextInt(artists.length)],
        count: 30,
      );
      final list3 = await apiService.searchSongs(
        "Punjabi Party Hits",
        count: 30,
      );
      final playlists = await apiService.searchPlaylists(
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

      final list1 = await apiService.searchSongs(artist1, count: 30);
      final list2 = await apiService.searchSongs(artist2, count: 30);
      final list3 = await apiService.searchSongs(artist3, count: 30);
      final playlists = await apiService.searchPlaylists(
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

      // Keep searching playlists on JioSaavn as a fallback just in case users like Saavn podcasts
      final playlists = await apiService.searchPlaylists("Podcasts", count: 20);

      final combined = _deduplicate([...list1, ...list2]);
      state = state.copyWith(
        podcastSongs: combined.isNotEmpty ? combined : state.podcastSongs,
        podcastPlaylists: playlists.isNotEmpty
            ? playlists
            : state.podcastPlaylists,
      );
    } catch (e) {
      debugPrint('[HomeNotifier] fetchPodcasts error: $e');
    }
  }

  Future<void> fetchIndianAlbums() async {
    try {
      final hindiAlbums = await apiService.searchAlbums("Hindi", count: 25);
      final teluguAlbums = await apiService.searchAlbums("Telugu", count: 25);
      final tamilAlbums = await apiService.searchAlbums("Tamil", count: 25);
      final punjabiAlbums = await apiService.searchAlbums("Punjabi", count: 25);

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
      final queryArtists = topArtists.isNotEmpty
          ? topArtists
          : (state.trendingSongs.isNotEmpty
                ? state.trendingSongs
                      .map((e) => e.artist.split(',').first)
                      .where((a) => a.isNotEmpty)
                      .toSet()
                      .take(4)
                      .toList()
                : ['Arijit Singh', 'Pritam', 'The Weeknd', 'Taylor Swift']);

      final newSongs = <Song>[];
      final newPlaylists = <Playlist>[];

      final Set<String> usedCovers = {};

      for (var artist in queryArtists.take(4)) {
        final res = await apiService.searchSongs(artist, count: 20);
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
      final futures = moods.map(
        (mood) =>
            apiService.searchPlaylists('${state.moodLanguage} $mood', count: 4),
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
      final futures = queries.map(
        (query) => apiService.searchPlaylists(query, count: 8),
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

    bool usedSpotify = false;
    List<Song> trending = [];
    List<Playlist> rawPlaylists = [];

    try {
      final spotifyApi = SpotifyApiService();
      final featuredPlaylists = await spotifyApi.getFeaturedPlaylists();
      
      if (featuredPlaylists.isNotEmpty) {
        // Fetch tracks for the first featured playlist to use as trending
        final firstPlaylistId = featuredPlaylists.first.id;
        final trendingTracks = await spotifyApi.getPlaylistTracks(firstPlaylistId);
        
        if (trendingTracks.isNotEmpty) {
          trending = trendingTracks.map((t) => t.toSong()).toList();
          rawPlaylists = featuredPlaylists;
          
          final newReleases = await spotifyApi.getNewReleases();
          rawPlaylists.addAll(newReleases);
          
          usedSpotify = true;
          debugPrint('[HomeNotifier] Successfully loaded storefront via Spotify API');
        }
      }
    } catch (e) {
      debugPrint('[HomeNotifier] Spotify API failed: $e. Falling back to Saavn.');
    }

    if (!usedSpotify) {
      final data = await apiService.fetchHomepageData(
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

    state = state.copyWith(
      trendingSongs: trending,
      topPlaylists: rawPlaylists,
      topAlbums: rawPlaylists.where((p) => p.type == 'album').toList(),
      continueWatching: await DatabaseService.getContinueWatching(),
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
