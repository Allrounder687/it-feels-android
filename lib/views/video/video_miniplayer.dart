import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:miniplayer/miniplayer.dart';
import '../../providers/video_player_provider.dart';
import 'package:video_player/video_player.dart';
import 'video_player_screen.dart';

class VideoMiniplayer extends StatelessWidget {
  const VideoMiniplayer({super.key});

  @override
  Widget build(BuildContext context) {
    final videoProvider = Provider.of<VideoPlayerProvider>(context);

    if (!videoProvider.isVideoActive) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    final minHeight = isLandscape 
        ? MediaQuery.of(context).size.height
        : 80.0 + MediaQuery.of(context).padding.bottom + 80.0; // Above bottom nav

    return Miniplayer(
      controller: videoProvider.miniplayerController,
      minHeight: minHeight,
      maxHeight: MediaQuery.of(context).size.height,
      builder: (height, percentage) {
        final isMinimized = percentage < 0.2 && !isLandscape;

        if (isMinimized) {
          // Minimized PiP Player
          return GestureDetector(
            onTap: () {
              videoProvider.miniplayerController.animateToHeight(state: PanelState.MAX);
            },
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Row(
                children: [
                  if (videoProvider.videoController != null && videoProvider.videoController!.value.isInitialized)
                    Container(
                      height: 60,
                      width: 100,
                      margin: const EdgeInsets.all(4),
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
                  IconButton(
                    icon: Icon((videoProvider.videoController?.value.isPlaying ?? false) ? Icons.pause : Icons.play_arrow),
                    onPressed: () {
                      if (videoProvider.videoController != null) {
                        videoProvider.videoController!.value.isPlaying
                            ? videoProvider.videoController!.pause()
                            : videoProvider.videoController!.play();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => videoProvider.closeVideo(),
                  ),
                ],
              ),
            ),
          );
        }

        // Expanded Full Player (Reusing or wrapping VideoPlayerScreen)
        return const VideoPlayerScreen(); // We need to adapt VideoPlayerScreen to work here
      },
    );
  }
}
