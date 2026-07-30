import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:miniplayer/miniplayer.dart';
import '../../providers/video_player_provider.dart';
import 'video_player_screen.dart';

class VideoMiniplayer extends StatelessWidget {
  const VideoMiniplayer({super.key});

  @override
  Widget build(BuildContext context) {
    final videoProvider = Provider.of<VideoPlayerProvider>(context);

    if (!videoProvider.isVideoActive) {
      return const SizedBox.shrink();
    }

    final minHeight = 80.0 + MediaQuery.of(context).padding.bottom + 80.0; // Above bottom nav

    return Miniplayer(
      controller: videoProvider.miniplayerController,
      minHeight: minHeight,
      maxHeight: MediaQuery.of(context).size.height,
      builder: (height, percentage) {
        final isMinimized = percentage < 0.2;

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
                  Expanded(
                    child: Text(
                      videoProvider.currentTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
