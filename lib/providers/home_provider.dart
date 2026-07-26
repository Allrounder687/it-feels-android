import 'package:flutter/material.dart';
import '../core/utils/error_reporter.dart';
import '../data/models/song_model.dart';
import '../data/services/jiosaavn_api_service.dart';

class HomeProvider extends ChangeNotifier {
  final JioSaavnApiService apiService;

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

  List<Song> _youSongs = [];
  List<Playlist> _youPlaylists = [];

  // Moods
  String _moodLanguage = 'English'; // English or Hindi
  List<Playlist> _moodPlaylists = [];
  bool _isLoadingMoods = false;

  // Charts
  List<Playlist> _chartPlaylists = [];
  bool _isLoadingCharts = false;

  String _selectedCategory = "YOU";
  bool _isLoading = true;

  HomeProvider({required this.apiService}) {
    loadHomepageData();
  }

  List<Song> get trendingSongs => _trendingSongs;
  List<Playlist> get topPlaylists => _topPlaylists;
  List<Playlist> get topAlbums => _topAlbums;
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  bool get isLoadingMoods => _isLoadingMoods;
  bool get isLoadingCharts => _isLoadingCharts;
  String get moodLanguage => _moodLanguage;

  List<Song> get currentCategorySongs {
    switch (_selectedCategory) {
      case "Bollywood":
        return _bollywoodSongs.isNotEmpty ? _bollywoodSongs : _trendingSongs;
      case "Telugu":
        return _teluguSongs.isNotEmpty ? _teluguSongs : _trendingSongs;
      case "Tamil":
        return _tamilSongs.isNotEmpty ? _tamilSongs : _trendingSongs;
      case "Punjabi":
        return _punjabiSongs.isNotEmpty ? _punjabiSongs : _trendingSongs;
      case "Hollywood":
        return _hollywoodSongs.isNotEmpty ? _hollywoodSongs : _trendingSongs;
      case "YOU":
        return _youSongs;
      case "Moods":
        return [];
      case "Charts":
        return [];
      case "Trending":
        return _trendingSongs;
      case "Playlists":
        return _trendingSongs;
      case "Albums":
        return _trendingSongs;
      case "All":
      default:
        return [..._bollywoodSongs, ..._teluguSongs, ..._tamilSongs, ..._trendingSongs];
    }
  }

  List<Playlist> get currentCategoryPlaylists {
    switch (_selectedCategory) {
      case "Bollywood":
        return _bollywoodPlaylists.isNotEmpty ? _bollywoodPlaylists : _topPlaylists;
      case "Telugu":
        return _teluguPlaylists.isNotEmpty ? _teluguPlaylists : _topPlaylists;
      case "Tamil":
        return _tamilPlaylists.isNotEmpty ? _tamilPlaylists : _topPlaylists;
      case "Punjabi":
        return _punjabiPlaylists.isNotEmpty ? _punjabiPlaylists : _topPlaylists;
      case "Hollywood":
        return _hollywoodPlaylists.isNotEmpty ? _hollywoodPlaylists : _topPlaylists;
      case "YOU":
        return _youPlaylists;
      case "Moods":
        return _moodPlaylists;
      case "Charts":
        return _chartPlaylists;
      case "Playlists":
        return _topPlaylists.where((p) => p.type == 'playlist').toList();
      case "Albums":
        return _topAlbums.isNotEmpty ? _topAlbums : _topPlaylists;
      case "Trending":
      case "All":
      default:
        return _topPlaylists;
    }
  }

  Future<void> selectCategory(String category) async {
    _selectedCategory = category;
    notifyListeners();

    if (category == "Bollywood" && _bollywoodSongs.length < 10) {
      await fetchBollywoodSongs();
    } else if (category == "Telugu" && _teluguSongs.length < 10) {
      await fetchTeluguSongs();
    } else if (category == "Tamil" && _tamilSongs.length < 10) {
      await fetchTamilSongs();
    } else if (category == "Punjabi" && _punjabiSongs.length < 10) {
      await fetchPunjabiSongs();
    } else if (category == "Hollywood" && _hollywoodSongs.length < 10) {
      await fetchHollywoodSongs();
    } else if (category == "Albums" && _topAlbums.length < 10) {
      await fetchIndianAlbums();
    } else if (category == "Moods" && _moodPlaylists.isEmpty) {
      await fetchMoods();
    } else if (category == "Charts" && _chartPlaylists.isEmpty) {
      await fetchCharts();
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
    _youSongs.clear();
    _youPlaylists.clear();
    
    if (topArtists.isEmpty) {
      notifyListeners();
      return;
    }

    try {
      for (int i = 0; i < topArtists.length; i++) {
        final artist = topArtists[i];
        final songs = await apiService.searchSongs(artist, count: 20);
        
        if (songs.isNotEmpty) {
          _youPlaylists.add(Playlist(
            id: 'mix_$i',
            title: 'Daily Mix: $artist',
            type: 'playlist',
            coverArt: songs.first.coverArt,
            songCount: songs.length,
          ));
          _youSongs.addAll(songs);
        }
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
      final moods = ['Chill', 'Party', 'Lofi', 'Romance', 'Car Ride', 'Workout'];
      final futures = moods.map((mood) => apiService.searchPlaylists('$_moodLanguage $mood', count: 3));
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
    } catch (_) {}
    
    _isLoadingMoods = false;
    notifyListeners();
  }

  Future<void> fetchCharts() async {
    if (_chartPlaylists.isNotEmpty || _isLoadingCharts) return;
    _isLoadingCharts = true;
    notifyListeners();

    try {
      final queries = ['Spotify Top 50 Global', 'Billboard Hot 100', 'Top 50 Hindi', 'Global Top 100', 'Viral 50'];
      final futures = queries.map((query) => apiService.searchPlaylists(query, count: 2));
      final results = await Future.wait(futures);
      
      _chartPlaylists.clear();
      for (var result in results) {
        if (result.isNotEmpty) {
          _chartPlaylists.addAll(result);
        }
      }
      
      final seen = <String>{};
      _chartPlaylists = _chartPlaylists.where((p) => seen.add(p.id)).toList();
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
