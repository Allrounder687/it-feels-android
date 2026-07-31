import 'package:it_feels_music/main.dart';
import 'package:flutter/foundation.dart';
import 'package:it_feels_music/features/library/custom_playlist_provider.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';

class PlaylistImportProgress {
  final int total;
  final int current;
  final String status;
  final bool isDone;

  PlaylistImportProgress({
    required this.total,
    required this.current,
    required this.status,
    required this.isDone,
  });
}

class PlaylistImportService {
  static final PlaylistImportService _instance = PlaylistImportService._internal();
  factory PlaylistImportService() => _instance;
  PlaylistImportService._internal();

  final ValueNotifier<PlaylistImportProgress?> importProgress = ValueNotifier(null);

  Future<void> startBackgroundImport(
    String url, 
    CustomPlaylistState playlistProvider, 
    MusicApiService apiService
  ) async {
    // 1. Initial State
    importProgress.value = PlaylistImportProgress(
      total: 0, current: 0, status: 'Fetching playlist details...', isDone: false
    );

    // 2. Extract tracks using scraper
    // final tracks = await SpotifyScraperService.extractTracksFromUrl(url);
    final List<Map<String, String>> tracks = []; // Mocked for now to fix build
    if (tracks.isEmpty) {
      importProgress.value = PlaylistImportProgress(
        total: 0, current: 0, status: 'Failed to extract tracks.', isDone: true
      );
      return;
    }

    final playlistName = 'Imported Playlist (${DateTime.now().month}/${DateTime.now().day})';
    
    // 3. Create playlist
    await appProviderContainer.read(customPlaylistProvider.notifier).createPlaylist(playlistName);
    // Grab the newly created playlist ID (it should be the last one)
    final newPlaylistId = playlistProvider.playlists.last.id;

    importProgress.value = PlaylistImportProgress(
      total: tracks.length, current: 0, status: 'Matching songs...', isDone: false
    );

    int matchedCount = 0;

    // 4. Background Matching Engine
    for (int i = 0; i < tracks.length; i++) {
      final track = tracks[i];
      final query = '${track['title']} ${track['artist']}';
      
      try {
        final results = await apiService.searchSongs(query, count: 5);
        if (results.isNotEmpty) {
          // Zero cognitive load: Pick the top result automatically
          final bestMatch = results.first;
          await appProviderContainer.read(customPlaylistProvider.notifier).addSongToPlaylist(newPlaylistId, bestMatch);
          matchedCount++;
        }
      } catch (e) {
        debugPrint('Failed to match: $query');
      }

      // Update UI Progress
      importProgress.value = PlaylistImportProgress(
        total: tracks.length, 
        current: i + 1, 
        status: 'Importing...', 
        isDone: false
      );
      
      // Add a slight delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // 5. Finished
    importProgress.value = PlaylistImportProgress(
      total: tracks.length, 
      current: tracks.length, 
      status: 'Imported $matchedCount/${tracks.length} songs!', 
      isDone: true
    );

    // Clear banner after 3 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (importProgress.value?.isDone == true) {
        importProgress.value = null;
      }
    });
  }
}
