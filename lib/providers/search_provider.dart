import 'package:flutter/material.dart';
import '../data/models/song_model.dart';
import '../data/services/jiosaavn_api_service.dart';

class SearchProvider extends ChangeNotifier {
  final JioSaavnApiService apiService;

  String _query = '';
  List<Song> _songs = [];
  List<Playlist> _albums = [];
  List<Playlist> _playlists = [];
  List<Map<String, dynamic>> _artists = [];
  bool _isSearching = false;

  SearchProvider({required this.apiService});

  String get query => _query;
  List<Song> get songs => _songs;
  List<Playlist> get albums => _albums;
  List<Playlist> get playlists => _playlists;
  List<Map<String, dynamic>> get artists => _artists;
  bool get isSearching => _isSearching;

  void search(String newQuery, {BuildContext? context}) async {
    _query = newQuery;
    if (newQuery.trim().isEmpty) {
      _songs = [];
      _albums = [];
      _playlists = [];
      _artists = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    final resultsFuture = apiService.searchAll(newQuery);
    final songsFuture = apiService.searchSongs(newQuery, count: 50);

    final results = await resultsFuture;
    final topSongs = await songsFuture;

    // Use the 50 fetched songs, fallback to searchAll songs if empty
    _songs = topSongs.isNotEmpty ? topSongs : List<Song>.from(results['songs'] ?? []);
    _albums = List<Playlist>.from(results['albums'] ?? []);
    _playlists = List<Playlist>.from(results['playlists'] ?? []);
    _artists = List<Map<String, dynamic>>.from(results['artists'] ?? []);

    _isSearching = false;
    notifyListeners();
  }
}
