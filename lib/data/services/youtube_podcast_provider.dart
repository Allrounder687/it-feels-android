import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/services/podcast_provider.dart';

import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubePodcastProvider implements PodcastProvider {
  final _yt = YoutubeExplode();

  @override
  Future<List<Song>> searchPodcasts(String query, {int count = 20}) async {
    try {
      final results = await _yt.search.search("$query podcast full episode");
      final List<Song> podcastSongs = [];

      for (var video in results.take(count)) {
        if (video.duration != null && video.duration!.inMinutes > 5) {
          // Filter out shorts
          podcastSongs.add(
            Song(
              id: 'yt_${video.id.value}',
              saavnId: 'yt_${video.id.value}',
              title: cleanTitle(video.title),
              artist: video.author,
              album: 'YouTube Podcast',
              duration: video.duration!.inSeconds,
              coverArt: video.thumbnails.highResUrl,
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
