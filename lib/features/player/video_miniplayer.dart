import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miniplayer/miniplayer.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/player/video_player_screen.dart';
import 'package:video_player/video_player.dart';

final videoMiniplayerControllerProvider = Provider((ref) => MiniplayerController());

class VideoMiniplayer extends ConsumerWidget {
  const VideoMiniplayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoProvider = ref.watch(videoPlayerProvider);
    final miniplayerController = ref.watch(videoMiniplayerControllerProvider);

    if (!videoProvider.isVideoActive) {
      return const SizedBox.shrink();
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final minHeight = 70.0 + bottomPadding + 64.0; // Above bottom nav + MiniPlayer

    return Miniplayer(
      controller: miniplayerController,
      minHeight: minHeight,
      maxHeight: MediaQuery.of(context).size.height,
      builder: (height, percentage) {
        final isMinimized = percentage < 0.2;

        if (isMinimized) {
          // Minimized PiP Player
          return GestureDetector(
            onTap: () {
              miniplayerController.animateToHeight(state: PanelState.MAX);
            },
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                children: [
                  const Divider(height: 1, thickness: 1, color: Colors.white24),
                  Expanded(
                    child: Row(
                      children: [
                        if (videoProvider.videoController != null && videoProvider.videoController!.value.isInitialized)
                          Container(
                            height: double.infinity,
                            width: 120,
                            color: Colors.black,
                            child: IgnorePointer(
                              child: VideoPlayer(videoProvider.videoController!),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            videoProvider.currentTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (videoProvider.videoController != null)
                          ValueListenableBuilder<VideoPlayerValue>(
                            valueListenable: videoProvider.videoController!,
                            builder: (context, value, child) {
                              return IconButton(
                                icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                                onPressed: () {
                                  value.isPlaying
                                      ? videoProvider.videoController!.pause()
                                      : videoProvider.videoController!.play();
                                },
                              );
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => ref.read(videoPlayerProvider.notifier).closeVideo(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Expanded Full Player
        return const VideoPlayerScreen();
      },
    );
  }
}
