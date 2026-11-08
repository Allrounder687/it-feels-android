import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  int _canvasGenToken = 0;
  bool _isDisposed = false;
  
  CanvasControllerNotifier(this.ref) : super(null);

  Future<void> loadCanvasForSong(Song song) async {
    if (_isDisposed) return;
    final myToken = ++_canvasGenToken;
    // Clear old
    if (state != null) {
      final oldState = state;
      state = null;
      try {
        await oldState?.player.stop();
        await oldState?.player.dispose();
      } catch (_) {}
    }
    
    try {
      final query = "${song.title} ${song.artist} #shorts";
      
      // Offload heavy HTML/Regex parsing to a background isolate
      final streamUrl = await compute(_fetchCanvasUrl, query);
      if (_canvasGenToken != myToken || _isDisposed) return;
      
      if (streamUrl == null) return;

      // Allow UI Hero animations to finish smoothly before hitting the GPU
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted || _isDisposed) return;
      if (_canvasGenToken != myToken) return;

      final player = Player();
      final controller = VideoController(player);
      
      await player.open(Media(streamUrl), play: false);
      if (_canvasGenToken != myToken || !mounted || _isDisposed) {
        try {
          await player.stop();
          await player.dispose();
        } catch (_) {}
        return;
      }
      await player.setVolume(0.0);
      await player.setPlaylistMode(PlaylistMode.loop);
      await player.play();
      
      if (mounted && _canvasGenToken == myToken && !_isDisposed) {
        state = controller;
      } else {
        try {
          await player.stop();
          await player.dispose();
        } catch (_) {}
      }
    } catch (e) {
      // Failed to load canvas silently
    }
  }

  /// Explicitly releases native Direct3D video texture and libmpv player instance
  Future<void> releaseVideoResources() async {
    _canvasGenToken++;
    final oldState = state;
    state = null;
    if (oldState != null) {
      try {
        await oldState.player.stop();
        await oldState.player.dispose();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _canvasGenToken++;
    final oldState = state;
    state = null;
    if (oldState != null) {
      final p = oldState.player;
      try {
        p.stop().then((_) {
          p.dispose().catchError((_) {});
        }).catchError((_) {});
      } catch (_) {}
    }
    super.dispose();
  }
}

class CanvasService {
  Future<String?> getSpotifyCanvasUrl(Song song) async {
    return null;
  }
}

// Standalone function for isolate
Future<String?> _fetchCanvasUrl(String query) async {
  return null;
}
