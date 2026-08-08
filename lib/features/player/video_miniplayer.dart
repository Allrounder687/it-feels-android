import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoMiniplayer extends ConsumerWidget {
  const VideoMiniplayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoProvider = ref.watch(videoPlayerProvider);
    final audioProvider = ref.watch(audioPlayerProvider);
    final settings = ref.watch(settingsProvider);

    final isSameSong = audioProvider.currentSong != null && 
                       (videoProvider.currentVideoId == audioProvider.currentSong!.id || 
                        videoProvider.currentVideoId == 'search:${audioProvider.currentSong!.id}');
                        
    final isMutedCanvas = !settings.useVideoAudioSource && isSameSong;

    if (!videoProvider.isVideoActive || videoProvider.videoController == null || isMutedCanvas) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth >= 600;
    final isExtraWide = screenWidth >= 1200;
    
    final double width = isExtraWide ? 426 : (isWideScreen ? 320 : 176);
    final double height = isExtraWide ? 240 : (isWideScreen ? 180 : 99);

    return GestureDetector(
      onTap: () {
        if (isSameSong) {
          context.push('/now_playing');
        } else {
          context.push('/video_player');
        }
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video Player
              IgnorePointer(
                child: ExcludeSemantics(
                  child: Video(
                    controller: videoProvider.videoController!,
                    controls: NoVideoControls,
                  ),
                ),
              ),
              // Gradient for visibility of icons
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black54, Colors.transparent, Colors.black54],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              // Close Button (Top Right)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => ref.read(videoPlayerProvider.notifier).closeVideo(),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
              // Play/Pause Button (Center)
              Center(
                child: StreamBuilder<bool>(
                  stream: videoProvider.player!.stream.playing,
                  initialData: videoProvider.player!.state.playing,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data ?? false;
                    return GestureDetector(
                      onTap: () {
                        isPlaying
                            ? videoProvider.player!.pause()
                            : videoProvider.player!.play();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

