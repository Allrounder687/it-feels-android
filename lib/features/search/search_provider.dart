import 'dart:async';
import 'package:flutter/material.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';

class SearchProvider extends ChangeNotifier {
  final MusicApiService apiService;

  String _query = '';
  List<Song> _songs = [];
  List<Playlist> _albums = [];
  List<Playlist> _playlists = [];
  List<Map<String, dynamic>> _artists = [];
  bool _isSearching = false;
  
  Timer? _debounceTimer;

  SearchProvider({required this.apiService});

  String get query => _query;
  List<Song> get songs => _songs;
  List<Playlist> get albums => _albums;
  List<Playlist> get playlists => _playlists;
  List<Map<String, dynamic>> get artists => _artists;
  bool get isSearching => _isSearching;

  void search(String newQuery, {BuildContext? context}) {
    _query = newQuery;
    
    if (_debounceTimer != null) {
      _debounceTimer!.cancel();
    }

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

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (_query != newQuery) return; // Prevent race conditions

      try {
        final resultsFuture = apiService.searchAll(newQuery);
        final songsFuture = apiService.searchSongs(newQuery, count: 50);

        final results = await resultsFuture;
        final topSongs = await songsFuture;

        if (_query != newQuery) return; // Re-check after await

        _albums = List<Playlist>.from(results['albums'] ?? []);
        _playlists = List<Playlist>.from(results['playlists'] ?? []);
        _artists = List<Map<String, dynamic>>.from(results['artists'] ?? []);

        // Ultimate Artist Search: If an artist is matched, fetch their true top songs
        if (_artists.isNotEmpty && _artists.first['id'] != null && _artists.first['id'].toString().isNotEmpty) {
          final artistId = _artists.first['id'].toString();
          final artistData = await apiService.fetchArtistDetails(artistId);
          
          if (_query != newQuery) return; // Re-check after 2nd await

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
      } catch (e) {
        debugPrint('[SearchProvider] Search error: $e');
      } finally {
        if (_query == newQuery) {
          _isSearching = false;
          notifyListeners();
        }
      }
    });
  }
}

