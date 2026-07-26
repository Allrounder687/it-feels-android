import 'package:it_feels_music/views/widgets/custom_image_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'animated_play_pause_button.dart';
import '../../providers/audio_player_provider.dart';

class MiniPlayer extends StatelessWidget {
  final VoidCallback onTap;

  const MiniPlayer({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerProvider>(
      builder: (context, playerProvider, child) {
        final currentSong = playerProvider.currentSong;
        if (currentSong == null) return const SizedBox.shrink();

        final progress = (playerProvider.duration.inMilliseconds > 0)
            ? (playerProvider.position.inMilliseconds / playerProvider.duration.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          height: 72,
          decoration: BoxDecoration(
            color: playerProvider.themeSurfaceColor.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Top Progress Indicator Line (YouTube Music style)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 2.5,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(playerProvider.themeAccentColor),
                  ),
                ),

                // Main Mini Player Tap Area
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          // Cover Art Thumbnail with Hero
                          Hero(
                            tag: 'cover_${currentSong.id}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: currentSong.coverArt.isNotEmpty
                                    ? CustomImageWidget(
                                        imageUrl: currentSong.coverArt,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) => const Icon(Icons.music_note, color: Colors.white),
                                      )
                                    : const Icon(Icons.music_note, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Song Title & Artist
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentSong.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentSong.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Cast Action Button
                          IconButton(
                            icon: const Icon(Icons.cast_rounded, color: Colors.white70, size: 20),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Searching for Cast devices...")),
                              );
                            },
                          ),

                          // Play/Pause Button
                          GestureDetector(
                            onTap: () => playerProvider.togglePlayPause(),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: AnimatedPlayPauseButton(
                                isPlaying: playerProvider.isPlaying,
                                onPressed: () => playerProvider.togglePlayPause(),
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
