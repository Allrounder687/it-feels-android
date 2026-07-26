import 'package:flutter/material.dart';
import '../core/utils/error_reporter.dart';
import '../data/models/song_model.dart';
import '../data/services/jiosaavn_api_service.dart';

class HomeProvider extends ChangeNotifier {
  final JioSaavnApiService apiService;

  List<Song> _trendingSongs = [];
  List<Playlist> _topPlaylists = [];
  bool _isLoading = true;

  HomeProvider({required this.apiService}) {
    loadHomepageData();
  }

  List<Song> get trendingSongs => _trendingSongs;
  List<Playlist> get topPlaylists => _topPlaylists;
  bool get isLoading => _isLoading;

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
    _topPlaylists = List<Playlist>.from(data['playlists'] ?? []);

    _isLoading = false;
    notifyListeners();
  }
}
