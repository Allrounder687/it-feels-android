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

    if (!videoProvider.isVideoActive || videoProvider.videoController == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        context.push('/video_player');
      },
      child: Container(
        width: 176, // 16:9 ratio
        height: 99,
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
                child: Video(
                  controller: videoProvider.videoController!,
                  controls: NoVideoControls,
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

