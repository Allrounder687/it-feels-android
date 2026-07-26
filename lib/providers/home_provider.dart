import 'package:flutter/material.dart';
import '../core/utils/error_reporter.dart';
import '../data/models/song_model.dart';
import '../data/services/music_api_service.dart';
import '../services/storage_service.dart';

class HomeProvider extends ChangeNotifier {
  final MusicApiService apiService;

  List<Song> _trendingSongs = [];
  List<Playlist> _topPlaylists = [];
  List<Playlist> _topAlbums = [];

  List<Song> _bollywoodSongs = [];
  List<Playlist> _bollywoodPlaylists = [];

  List<Song> _teluguSongs = [];
  List<Playlist> _teluguPlaylists = [];

  List<Song> _tamilSongs = [];
  List<Playlist> _tamilPlaylists = [];

  List<Song> _punjabiSongs = [];
  List<Playlist> _punjabiPlaylists = [];

  List<Song> _hollywoodSongs = [];
  List<Playlist> _hollywoodPlaylists = [];

  List<Song> _podcastSongs = [];
  List<Playlist> _podcastPlaylists = [];

  List<Song> _youSongs = [];
  List<Playlist> _youPlaylists = [];

  // Moods
  String _moodLanguage = 'English'; // English or Hindi
  List<Playlist> _moodPlaylists = [];
  bool _isLoadingMoods = false;

  // Charts
  List<Playlist> _chartPlaylists = [];
  bool _isLoadingCharts = false;

  String _selectedCategory = "For You";
  bool _isLoading = true;

  HomeProvider({required this.apiService}) {
    _initCategory();
    loadHomepageData();
  }

  Future<void> _initCategory() async {
    _selectedCategory = await StorageService.loadDefaultCategory();
    notifyListeners();
  }

  List<Song> get trendingSongs => _trendingSongs;
  List<Playlist> get topPlaylists => _topPlaylists;
  List<Playlist> get topAlbums => _topAlbums;
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  bool get isLoadingMoods => _isLoadingMoods;
  bool get isLoadingCharts => _isLoadingCharts;
  String get moodLanguage => _moodLanguage;

  List<Song> get youSongs => _youSongs;
  List<Playlist> get youPlaylists => _youPlaylists;
  List<Song> get bollywoodSongs => _bollywoodSongs;
  List<Song> get teluguSongs => _teluguSongs;
  List<Song> get tamilSongs => _tamilSongs;
  List<Song> get punjabiSongs => _punjabiSongs;
  List<Song> get hollywoodSongs => _hollywoodSongs;
  List<Song> get podcastSongs => _podcastSongs;
  List<Playlist> get podcastPlaylists => _podcastPlaylists;
  List<Playlist> get moodPlaylists => _moodPlaylists;
  List<Playlist> get chartPlaylists => _chartPlaylists;

  List<Song> get currentCategorySongs {
    switch (_selectedCategory) {
      case "For You":
        return _youSongs;
      case "Podcasts":
        return _podcastSongs;
      case "Music":
      case "Charts":
      default:
        return _trendingSongs;
    }
  }

  List<Playlist> get currentCategoryPlaylists {
    switch (_selectedCategory) {
      case "For You":
        return _youPlaylists;
      case "Podcasts":
        return _podcastPlaylists;
      case "Charts":
        return _chartPlaylists;
      case "Music":
      default:
        return _topPlaylists;
    }
  }

  Future<void> selectCategory(String category) async {
    _selectedCategory = category;
    notifyListeners();

    if (category == "Podcasts" && _podcastPlaylists.isEmpty) {
      await fetchPodcasts();
    } else if (category == "For You" && _moodPlaylists.isEmpty) {
      await fetchMoods();
    } else if (category == "Charts" && _chartPlaylists.isEmpty) {
      await fetchCharts();
    } else if (category == "Music" && _hollywoodSongs.isEmpty) {
      await fetchHollywoodSongs();
    }
  }

  List<Song> _deduplicate(List<Song> songs) {
    final Map<String, Song> unique = {};
    for (var s in songs) {
      if (s.title.isEmpty) continue;

      // Clean title: strip (From "..."), - Title Track, special characters
      String cleanTitle = s.title
          .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
          .replaceAll(RegExp(r'\s*-\s*.*'), '')
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '')
          .trim();

      if (cleanTitle.isEmpty) {
        cleanTitle = s.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
      }
      
      // Combine with artist name to allow the same song title by different artists
      // but prevent exact duplicates of the same song by the same artist
      String artistClean = s.artist.split(',').first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
      String uniqueKey = '${cleanTitle}_$artistClean';

      // Keep only the first instance
      if (uniqueKey.isNotEmpty && !unique.containsKey(uniqueKey)) {
        unique[uniqueKey] = s;
      }
    }
    return unique.values.toList();
  }

  Future<void> fetchBollywoodSongs() async {
    try {
      final list1 = await apiService.searchSongs("Hindi Songs", count: 30);
      final list2 = await apiService.searchSongs("Arijit Singh", count: 30);
      final list3 = await apiService.searchSongs("Bollywood Hits", count: 30);
      final playlists = await apiService.searchPlaylists("Bollywood Hits", count: 20);

      final combined = _deduplicate([...list1, ...list2, ...list3]);
      if (combined.isNotEmpty) _bollywoodSongs = combined;
      if (playlists.isNotEmpty) _bollywoodPlaylists = playlists;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> fetchTeluguSongs() async {
    try {
      final list1 = await apiService.searchSongs("Telugu Songs", count: 30);
      final list2 = await apiService.searchSongs("Sid Sriram Telugu", count: 30);
      final list3 = await apiService.searchSongs("Tollywood Hits", count: 30);
      final playlists = await apiService.searchPlaylists("Telugu Hits", count: 20);

      final combined = _deduplicate([...list1, ...list2, ...list3]);
      if (combined.isNotEmpty) _teluguSongs = combined;
      if (playlists.isNotEmpty) _teluguPlaylists = playlists;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> fetchTamilSongs() async {
    try {
      final list1 = await apiService.searchSongs("Tamil Songs", count: 30);
      final list2 = await apiService.searchSongs("Anirudh Ravichander", count: 30);
      final list3 = await apiService.searchSongs("Kollywood Hits", count: 30);
      final playlists = await apiService.searchPlaylists("Tamil Hits", count: 20);

      final combined = _deduplicate([...list1, ...list2, ...list3]);
      if (combined.isNotEmpty) _tamilSongs = combined;
      if (playlists.isNotEmpty) _tamilPlaylists = playlists;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> fetchPunjabiSongs() async {
    try {
      final list1 = await apiService.searchSongs("Punjabi Songs", count: 30);
      final list2 = await apiService.searchSongs("Karan Aujla", count: 30);
      final list3 = await apiService.searchSongs("Punjabi Hits", count: 30);
      final playlists = await apiService.searchPlaylists("Punjabi Hits", count: 20);

      final combined = _deduplicate([...list1, ...list2, ...list3]);
      if (combined.isNotEmpty) _punjabiSongs = combined;
      if (playlists.isNotEmpty) _punjabiPlaylists = playlists;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> fetchHollywoodSongs() async {
    try {
      final list1 = await apiService.searchSongs("English Songs", count: 30);
      final list2 = await apiService.searchSongs("Taylor Swift", count: 30);
      final list3 = await apiService.searchSongs("Pop Hits", count: 30);
      final playlists = await apiService.searchPlaylists("English Hits", count: 20);

      final combined = _deduplicate([...list1, ...list2, ...list3]);
      if (combined.isNotEmpty) _hollywoodSongs = combined;
      if (playlists.isNotEmpty) _hollywoodPlaylists = playlists;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> fetchPodcasts() async {
    try {
      final res = await apiService.searchAll('Podcasts');
      final combinedSongs = _deduplicate(res['songs'] as List<Song>);
      if (combinedSongs.isNotEmpty) _podcastSongs = combinedSongs;
      
      var playlists = res['playlists'] as List<Playlist>;
      if (playlists.isEmpty) {
        playlists = await apiService.searchPlaylists("Podcasts");
      }
      if (playlists.isNotEmpty) _podcastPlaylists = playlists;
    } catch (e) {
      debugPrint('[HomeProvider] fetchPodcasts error: $e');
    }
    notifyListeners();
  }

  Future<void> fetchIndianAlbums() async {
    try {
      final hindiAlbums = await apiService.searchAlbums("Hindi", count: 25);
      final teluguAlbums = await apiService.searchAlbums("Telugu", count: 25);
      final tamilAlbums = await apiService.searchAlbums("Tamil", count: 25);
      final punjabiAlbums = await apiService.searchAlbums("Punjabi", count: 25);

      final combined = <Playlist>[...hindiAlbums, ...teluguAlbums, ...tamilAlbums, ...punjabiAlbums];
      final Map<String, Playlist> unique = {};
      for (var album in combined) {
        if (album.id.isNotEmpty) {
          unique[album.id] = album;
        }
      }
      if (unique.isNotEmpty) {
        _topAlbums = unique.values.toList();
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> fetchYouSongs(List<String> topArtists) async {
    if (_youSongs.isNotEmpty) return;

    try {
      final queryArtists = topArtists.isNotEmpty 
          ? topArtists 
          : ['Arijit Singh', 'Pritam', 'The Weeknd', 'Taylor Swift']; // Fallback artists

      for (var artist in queryArtists.take(4)) {
        final res = await apiService.searchSongs(artist, count: 20);
        if (res.isNotEmpty) {
          _youPlaylists.add(Playlist(
            id: 'mix_${artist.replaceAll(' ', '_')}',
            title: 'Daily Mix: $artist',
            type: 'playlist',
            coverArt: res.first.coverArt,
            songCount: res.length,
          ));
          _youSongs.addAll(res);
        }
      }
      
      // If still empty (network failure etc), fallback to trending
      if (_youSongs.isEmpty) {
        _youSongs.addAll(_trendingSongs.take(10));
      }
      
      _youSongs = _deduplicate(_youSongs);
    } catch (_) {}
    
    notifyListeners();
  }

  void toggleMoodLanguage() {
    _moodLanguage = _moodLanguage == 'English' ? 'Hindi' : 'English';
    fetchMoods();
  }

  Future<void> fetchMoods() async {
    if (_isLoadingMoods) return;
    _isLoadingMoods = true;
    notifyListeners();

    try {
      final moods = ['Chill', 'Party', 'Lofi', 'Romance', 'Workout'];
      final futures = moods.map((mood) => apiService.searchPlaylists('$_moodLanguage $mood', count: 4));
      final results = await Future.wait(futures);
      
      _moodPlaylists.clear();
      for (var result in results) {
        if (result.isNotEmpty) {
          _moodPlaylists.addAll(result);
        }
      }
      
      // Deduplicate playlists by id
      final seen = <String>{};
      _moodPlaylists = _moodPlaylists.where((p) => seen.add(p.id)).toList();
      
      // Fallback if empty
      if (_moodPlaylists.isEmpty) {
        _moodPlaylists = _topPlaylists.where((p) => p.type == 'playlist').take(5).toList();
      }
    } catch (_) {}
    
    _isLoadingMoods = false;
    notifyListeners();
  }

  Future<void> fetchCharts() async {
    if (_chartPlaylists.isNotEmpty || _isLoadingCharts) return;
    _isLoadingCharts = true;
    notifyListeners();

    try {
      final queries = ['Top 50', 'Billboard', 'Viral', 'Global 100'];
      final futures = queries.map((query) => apiService.searchPlaylists(query, count: 4));
      final results = await Future.wait(futures);
      
      _chartPlaylists.clear();
      for (var result in results) {
        if (result.isNotEmpty) {
          _chartPlaylists.addAll(result);
        }
      }
      
      final seen = <String>{};
      _chartPlaylists = _chartPlaylists.where((p) => seen.add(p.id)).toList();
      
      if (_chartPlaylists.isEmpty) {
         _chartPlaylists = _topPlaylists.where((p) => p.type == 'playlist').take(5).toList();
      }
    } catch (_) {}
    
    _isLoadingCharts = false;
    notifyListeners();
  }

  Future<void> loadHomepageData([BuildContext? context]) async {
    _isLoading = true;
    notifyListeners();

    final data = await apiService.fetchHomepageData(
      onError: (message) {
        if (context != null) {
          ErrorReporter.showError(context, message);
        }
      },
    );
    _trendingSongs = List<Song>.from(data['trending'] ?? []);
    final rawPlaylists = List<Playlist>.from(data['playlists'] ?? []);
    _topPlaylists = rawPlaylists;
    _topAlbums = rawPlaylists.where((p) => p.type == 'album').toList();

    // Fetch rich multi-query song lists for all regional categories
    fetchBollywoodSongs();
    fetchTeluguSongs();
    fetchTamilSongs();
    fetchPunjabiSongs();
    fetchIndianAlbums();

    _isLoading = false;
    notifyListeners();
  }
}
