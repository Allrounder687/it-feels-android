import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/podcast_provider.dart';
import 'package:it_feels_music/services/backend_api_service.dart';
import 'package:flutter/foundation.dart';

class YouTubePodcastProvider implements PodcastProvider {
  @override
  Future<List<Song>> searchPodcasts(String query, {int count = 20}) async {
    try {
      final results = await BackendApiService.directInnerTubeVideoSearch("$query podcast full episode", limit: count);
      final List<Song> podcastSongs = [];

      for (var video in results) {
        final duration = video['duration'] as int? ?? 0;
        if (duration > 300) { // Filter out videos shorter than 5 minutes
          final rawId = video['id'] as String;
          final videoId = rawId.startsWith('youtube:') ? rawId.substring(8) : rawId;
          
          podcastSongs.add(
            Song(
              id: 'yt_$videoId',
              saavnId: 'yt_$videoId',
              title: cleanTitle(video['title'] ?? 'Podcast Episode'),
              artist: video['uploader'] ?? 'YouTube Creator',
              album: 'YouTube Podcast',
              duration: duration,
              coverArt: video['thumbnail'] ?? 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
              addedAt: DateTime.now(),
            ),
          );
        }
      }
      return podcastSongs;
    } catch (e) {
      debugPrint('[YouTubePodcastProvider] Error fetching podcasts: $e');
      return [];
    }
  }

  String cleanTitle(String title) {
    return title.replaceAll(RegExp(r'#\w+'), '').trim();
  }
}
