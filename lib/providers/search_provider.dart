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

    _albums = List<Playlist>.from(results['albums'] ?? []);
    _playlists = List<Playlist>.from(results['playlists'] ?? []);
    _artists = List<Map<String, dynamic>>.from(results['artists'] ?? []);

    // Ultimate Artist Search: If an artist is matched, fetch their true top songs
    if (_artists.isNotEmpty && _artists.first['id'] != null && _artists.first['id'].toString().isNotEmpty) {
      final artistId = _artists.first['id'].toString();
      final artistData = await apiService.fetchArtistDetails(artistId);
      if (artistData['topSongs'] != null && (artistData['topSongs'] as List).isNotEmpty) {
        // Prepend true artist songs or replace completely
        final trueArtistSongs = artistData['topSongs'] as List<Song>;
        _songs = trueArtistSongs;
        
        if (artistData['albums'] != null && (artistData['albums'] as List).isNotEmpty) {
          _albums.insertAll(0, artistData['albums'] as List<Playlist>);
        }
      }
    } else {
      _songs = topSongs.isNotEmpty ? topSongs : List<Song>.from(results['songs'] ?? []);
    }

    _isSearching = false;
    notifyListeners();
  }
}
