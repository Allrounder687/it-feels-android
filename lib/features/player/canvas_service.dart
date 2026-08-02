import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:video_player/video_player.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

final canvasControllerProvider = StateNotifierProvider<CanvasControllerNotifier, VideoPlayerController?>((ref) {
  final notifier = CanvasControllerNotifier(ref);
  ref.listen<Song?>(audioPlayerProvider.select((state) => state.currentSong), (prev, next) {
    if (next != null && prev?.id != next.id) {
      notifier.loadCanvasForSong(next);
    }
  });
  return notifier;
});

class CanvasControllerNotifier extends StateNotifier<VideoPlayerController?> {
  final Ref ref;
  final YoutubeExplode _yt = YoutubeExplode();
  
  CanvasControllerNotifier(this.ref) : super(null);

  Future<void> loadCanvasForSong(Song song) async {
    // Clear old
    if (state != null) {
      await state?.dispose();
      state = null;
    }
    
    try {
      final query = "\${song.title} \${song.artist} vertical short animation";
      final searchList = await _yt.search.search(query);
      if (searchList.isEmpty) return;

      // Filter for shorts
      Video? targetVideo;
      for (final video in searchList) {
        if (video.duration != null && video.duration!.inMinutes <= 2) {
          targetVideo = video;
          break;
        }
      }

      if (targetVideo == null) return;

      final manifest = await _yt.videos.streamsClient.getManifest(targetVideo.id);
      final streamInfo = manifest.muxed.withHighestBitrate();
      
      final controller = VideoPlayerController.networkUrl(streamInfo.url);
      await controller.initialize();
      await controller.setVolume(0.0);
      await controller.setLooping(true);
      await controller.play();
      
      if (mounted) {
        state = controller;
      } else {
        controller.dispose();
      }
    } catch (e) {
      // Failed to load canvas silently
    }
  }

  @override
  void dispose() {
    state?.dispose();
    _yt.close();
    super.dispose();
  }
}

