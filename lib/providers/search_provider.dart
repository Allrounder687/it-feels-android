import 'package:flutter/material.dart';
import '../data/models/song_model.dart';
import '../data/services/jiosaavn_api_service.dart';

/// `SearchProvider` is a [ChangeNotifier] responsible for managing the state of the
/// application's search functionality.
///
/// It keeps track of the current search query, manages the results categorized
/// into [songs], [albums], and [playlists], and indicates the current search status
/// ([isSearching]).
///
/// This provider uses [JioSaavnApiService] to execute search queries and updates
/// its state based on the retrieved results.
class SearchProvider extends ChangeNotifier {
  /// Service for interacting with the JioSaavn API to perform search queries.
  final JioSaavnApiService apiService;

  /// The current search query string entered by the user.
  String _query = '';

  /// List of song search results.
  List<Song> _songs = [];

  /// List of album search results.
  List<Playlist> _albums = [];

  /// List of playlist search results.
  List<Playlist> _playlists = [];

  /// Indicates if a search operation is currently in progress.
  bool _isSearching = false;

  /// Constructs a [SearchProvider] requiring a [JioSaavnApiService].
  SearchProvider({required this.apiService});

  /// Getter for the current search query.
  String get query => _query;

  /// Getter for the list of song search results.
  List<Song> get songs => _songs;

  /// Getter for the list of album search results.
  List<Playlist> get albums => _albums;

  /// Getter for the list of playlist search results.
  List<Playlist> get playlists => _playlists;

  /// Getter for the search status.
  bool get isSearching => _isSearching;

  /// Executes a search operation for a given [newQuery].
  ///
  /// Data Flow:
  /// 1. Updates the [_query] and checks if it's empty or blank.
  /// 2. If empty, clears previous results, resets search status, and notifies listeners.
  /// 3. If not empty, sets [_isSearching] to `true` and notifies listeners
  ///    to show a loading indicator in the UI.
  /// 4. Calls [apiService.searchAll] to fetch search results from the API.
  /// 5. Populates [_songs], [_albums], and [_playlists] lists from the results map.
  /// 6. Sets [_isSearching] to `false` and notifies listeners to update the UI
  ///    with new search results.
  void search(String newQuery) async {
    _query = newQuery;
    if (newQuery.trim().isEmpty) {
      // If query is empty, reset results
      _songs = [];
      _albums = [];
      _playlists = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    // Start search
    _isSearching = true;
    notifyListeners();

    // Fetch results from API
    final results = await apiService.searchAll(newQuery);
    _songs = List<Song>.from(results['songs'] ?? []);
    _albums = List<Playlist>.from(results['albums'] ?? []);
    _playlists = List<Playlist>.from(results['playlists'] ?? []);

    // Search finished
    _isSearching = false;
    notifyListeners();
  }
}
