import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' hide Video;
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

final canvasControllerProvider = StateNotifierProvider<CanvasControllerNotifier, VideoController?>((ref) {
  final notifier = CanvasControllerNotifier(ref);
  ref.listen<Song?>(audioPlayerProvider.select((state) => state.currentSong), (prev, next) {
    if (next != null && prev?.id != next.id) {
      notifier.loadCanvasForSong(next);
    }
  });
  return notifier;
});

class CanvasControllerNotifier extends StateNotifier<VideoController?> {
  final Ref ref;
  
  CanvasControllerNotifier(this.ref) : super(null);

  Future<void> loadCanvasForSong(Song song) async {
    // Clear old
    if (state != null) {
      await state?.player.pause();
      await state?.player.dispose();
      state = null;
    }
    
    try {
      final query = "${song.title} ${song.artist} #shorts";
      
      // Offload heavy HTML/Regex parsing to a background isolate
      final streamUrl = await compute(_fetchCanvasUrl, query);
      
      if (streamUrl == null) return;

      // Allow UI Hero animations to finish smoothly before hitting the GPU
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      final player = Player();
      final controller = VideoController(player);
      
      await player.open(Media(streamUrl), play: false);
      await player.setVolume(0.0);
      await player.setPlaylistMode(PlaylistMode.loop);
      await player.play();
      
      if (mounted) {
        state = controller;
      } else {
        await player.dispose();
      }
    } catch (e) {
      // Failed to load canvas silently
    }
  }

  @override
  void dispose() {
    state?.player.dispose();
    super.dispose();
  }
}

// Standalone function for isolate
Future<String?> _fetchCanvasUrl(String query) async {
  final yt = YoutubeExplode();
  try {
    final searchList = await yt.search.search(query);
    if (searchList.isEmpty) {
      yt.close();
      return null;
    }

    Video? targetVideo;
    for (final video in searchList) {
      if (video.duration != null && video.duration!.inMinutes <= 2) {
        targetVideo = video;
        break;
      }
    }

    if (targetVideo == null) {
      yt.close();
      return null;
    }

    final manifest = await yt.videos.streamsClient.getManifest(targetVideo.id);
    final streamInfo = manifest.muxed.sortByVideoQuality().last;
    yt.close();
    return streamInfo.url.toString();
  } catch (e) {
    yt.close();
    return null;
  }
}

