import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miniplayer/miniplayer.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/providers/bottom_ui_provider.dart';
import 'package:it_feels_music/features/player/video_player_provider.dart';
import 'package:it_feels_music/features/player/video_player_screen.dart';
import 'package:video_player/video_player.dart';

final videoMiniplayerControllerProvider = Provider((ref) => MiniplayerController());

class VideoMiniplayer extends ConsumerWidget {
  const VideoMiniplayer({super.key});

  static String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final h = d.inHours.toString();
      return '$h:$m:$s';
    }
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoProvider = ref.watch(videoPlayerProvider);
    final miniplayerController = ref.watch(videoMiniplayerControllerProvider);

    if (!videoProvider.isVideoActive) {
      return const SizedBox.shrink();
    }

    final bottomUiHeight = ref.watch(bottomUiProvider);
    // Video PiP should sit ON TOP of audio miniplayer + nav.
    // Make it a compact strip: audio mini (~70-90px) + thin video strip (~100px).
    final minHeight =
        (bottomUiHeight > 60 ? bottomUiHeight : 80.0) + 90.0;

    return Miniplayer(
      controller: miniplayerController,
      minHeight: minHeight,
      maxHeight: MediaQuery.of(context).size.height,
      builder: (height, percentage) {
        final isMinimized = percentage < 0.2;

        if (isMinimized) {
          final isLight = Theme.of(context).brightness == Brightness.light;
          return GestureDetector(
            onTap: () {
              miniplayerController.animateToHeight(state: PanelState.MAX);
            },
            child: Material(
              elevation: 6,
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Container(
                constraints: const BoxConstraints(minHeight: 110),
                child: Row(
                  children: [
                    // Video thumbnail with proper aspect ratio (16:9)
                    if (videoProvider.videoController != null &&
                        videoProvider.videoController!.value.isInitialized)
                      SizedBox(
                        width: 130,
                        height: double.infinity,
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Container(
                            color: Colors.black,
                            child: IgnorePointer(
                              child: VideoPlayer(
                                  videoProvider.videoController!),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 10),
                    // Title + duration info
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            videoProvider.currentTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.color,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (videoProvider.videoController != null)
  ValueListenableBuilder<VideoPlayerValue>(
    valueListenable: videoProvider.videoController!,
    builder: (context, value, child) {
      final dur = value.duration;
      return Text(
        _formatDuration(dur),
        maxLines: 1,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.color ??
              Colors.black54,
        ),
      );
    },
  ),
                        ],
                      ),
                    ),
                    // Play / Pause
                    if (videoProvider.videoController != null)
                      ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: videoProvider.videoController!,
                        builder: (context, value, child) {
                          return IconButton(
                            icon: Icon(
                              value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color:
                                  Theme.of(context).iconTheme.color,
                              size: 22,
                            ),
                            onPressed: () {
                              value.isPlaying
                                  ? videoProvider.videoController!
                                      .pause()
                                  : videoProvider.videoController!
                                      .play();
                            },
                          );
                        },
                      ),
                    // Close
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: Theme.of(context).iconTheme.color,
                        size: 20,
                      ),
                      onPressed: () =>
                          ref.read(videoPlayerProvider.notifier).closeVideo(),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
          );
        }

        // Expanded full-player
        return const VideoPlayerScreen();
      },
    );
  }
}
