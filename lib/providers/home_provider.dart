import 'package:flutter/material.dart';
import '../core/utils/error_reporter.dart'; // Import ErrorReporter
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
    // loadHomepageData() will now require BuildContext, so it can't be called directly here.
    // It should be called from the UI layer where BuildContext is available.
    // For now, I'll remove the call from the constructor and expect the UI to call it.
    // However, if the design requires immediate load, a global key or similar pattern
    // would be needed to provide a context from outside a widget build cycle.
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
  /// **IMPORTANT:** This method now requires a [BuildContext] to display
  /// user-facing error messages via [ErrorReporter]. It should be called
  /// from a widget that has access to a valid [BuildContext].
  ///
  /// Data Flow:
  /// 1. Sets [_isLoading] to `true` and notifies listeners to show loading indicators.
  /// 2. Calls [apiService.fetchHomepageData()] to get the raw data, passing
  ///    [ErrorReporter.showError] as the `onError` callback.
  /// 3. Populates [_trendingSongs] and [_topPlaylists] from the fetched data.
  /// 4. Sets [_isLoading] to `false` and notifies listeners again, indicating
  ///    that data is ready for display.
  Future<void> loadHomepageData(BuildContext context) async { // Added BuildContext
    _isLoading = true;
    notifyListeners();

    final data = await apiService.fetchHomepageData(
      onError: (message) => ErrorReporter.showError(context, message),
    );
    _trendingSongs = List<Song>.from(data['trending'] ?? []);
    _topPlaylists = List<Playlist>.from(data['playlists'] ?? []);

    _isLoading = false;
    notifyListeners();
  }
}
