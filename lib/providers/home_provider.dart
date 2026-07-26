import 'package:flutter/material.dart';
import '../data/models/song_model.dart';
import '../data/services/jiosaavn_api_service.dart';

/// `HomeProvider` is a [ChangeNotifier] responsible for managing the data
/// displayed on the application's home screen. It handles fetching trending songs
/// and top playlists from the [JioSaavnApiService].
///
/// It exposes lists of [_trendingSongs] and [_topPlaylists] along with a
/// loading state ([_isLoading]) to the UI.
class HomeProvider extends ChangeNotifier {
  /// Service for interacting with the JioSaavn API to fetch homepage-specific data.
  final JioSaavnApiService apiService;

  /// List of trending songs to be displayed on the home screen.
  List<Song> _trendingSongs = [];

  /// List of top or featured playlists/albums to be displayed on the home screen.
  List<Playlist> _topPlaylists = [];

  /// Indicates if the homepage data is currently being loaded.
  bool _isLoading = true;

  /// Constructs a [HomeProvider] requiring a [JioSaavnApiService].
  ///
  /// Automatically calls [loadHomepageData] upon initialization to populate
  /// the home screen with initial data.
  HomeProvider({required this.apiService}) {
    loadHomepageData();
  }

  /// Getter for the list of trending songs.
  List<Song> get trendingSongs => _trendingSongs;

  /// Getter for the list of top playlists.
  List<Playlist> get topPlaylists => _topPlaylists;

  /// Getter for the loading status of homepage data.
  bool get isLoading => _isLoading;

  /// Fetches the homepage data (trending songs and playlists) from the
  /// [JioSaavnApiService].
  ///
  /// Data Flow:
  /// 1. Sets [_isLoading] to `true` and notifies listeners to show loading indicators.
  /// 2. Calls [apiService.fetchHomepageData()] to get the raw data.
  /// 3. Populates [_trendingSongs] and [_topPlaylists] from the fetched data.
  /// 4. Sets [_isLoading] to `false` and notifies listeners again, indicating
  ///    that data is ready for display.
  Future<void> loadHomepageData() async {
    _isLoading = true;
    notifyListeners();

    final data = await apiService.fetchHomepageData();
    _trendingSongs = List<Song>.from(data['trending'] ?? []);
    _topPlaylists = List<Playlist>.from(data['playlists'] ?? []);

    _isLoading = false;
    notifyListeners();
  }
}
