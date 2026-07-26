import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 64,
          decoration: BoxDecoration(
            color: playerProvider.themeSurfaceColor.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(32),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // Album Cover Thumbnail with Hero Transition
                    Hero(
                      tag: 'cover_${currentSong.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: SizedBox(
                          width: 46,
                          height: 46,
                          child: currentSong.coverArt.isNotEmpty
                              ? CachedNetworkImage(
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

                    // Play/Pause Pill Button
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: playerProvider.themeAccentColor.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          playerProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
                      onPressed: () => playerProvider.togglePlayPause(),
                    ),

                    // Skip Next Button
                    IconButton(
                      icon: const Icon(Icons.skip_next, color: Colors.white70, size: 24),
                      onPressed: () => playerProvider.skipToNext(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
