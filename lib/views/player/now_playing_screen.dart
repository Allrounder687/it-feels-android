import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/audio_player_provider.dart';
import '../lyrics/lyrics_screen.dart';
import '../widgets/wavy_seek_bar.dart';
import 'queue_bottom_sheet.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final artSize = (screenWidth * 0.82).clamp(240.0, 350.0);

    return Consumer<AudioPlayerProvider>(
      builder: (context, playerProvider, child) {
        final currentSong = playerProvider.currentSong;
        final bgColor = playerProvider.themeBackgroundColor;
        final surfaceColor = playerProvider.themeSurfaceColor;
        final accentColor = playerProvider.themeAccentColor;

        if (currentSong == null) {
          return Scaffold(
            backgroundColor: AppColors.burgundyBackground,
            body: Center(
              child: Text(
                "No song selected",
                style: GoogleFonts.inter(color: Colors.white70),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  // Top App Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Collapse Down Arrow
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 32),
                        onPressed: () => Navigator.pop(context),
                      ),

                      // "Now Playing" Title
                      Text(
                        "Now Playing",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      // Action Buttons (Lyrics Badge + Queue Menu)
                      Row(
                        children: [
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.lyrics_outlined, color: Colors.white, size: 20),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const LyricsScreen()),
                              );
                            },
                          ),
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 20),
                            ),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const QueueBottomSheet(),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Center Album Artwork with Hero Animation & Responsive Fitting
                  Hero(
                    tag: 'cover_${currentSong.id}',
                    child: Container(
                      width: artSize,
                      height: artSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: currentSong.coverArt.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: currentSong.coverArt,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    Container(color: surfaceColor),
                              )
                            : Container(color: surfaceColor),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Song Title & Artist Name
                  Text(
                    currentSong.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currentSong.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.burgundyTextMuted,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Wavy / Squiggly Seekbar Progress Slider
                  WavySeekBar(
                    position: playerProvider.position,
                    duration: playerProvider.duration,
                    activeColor: accentColor,
                    inactiveColor: Colors.white24,
                    onSeek: (newPos) => playerProvider.seek(newPos),
                  ),

                  // Timestamp Row (Current Time vs Total Duration)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(playerProvider.position),
                          style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
                        ),
                        Text(
                          _formatDuration(playerProvider.duration),
                          style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Primary Control Bar (Muted Pill Container with Play/Pause, Prev, Next)
                  Container(
                    height: 84,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(42),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 36),
                          onPressed: () => playerProvider.skipToPrevious(),
                        ),

                        // Center Big Play/Pause Toggle
                        GestureDetector(
                          onTap: () => playerProvider.togglePlayPause(),
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              playerProvider.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 38,
                            ),
                          ),
                        ),

                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 36),
                          onPressed: () => playerProvider.skipToNext(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Secondary Controls Row (Shuffle, Repeat, Favorite)
                  Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: surfaceColor.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(27),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.shuffle_rounded,
                            color: playerProvider.isShuffle ? accentColor : Colors.white54,
                            size: 22,
                          ),
                          onPressed: () => playerProvider.toggleShuffle(),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.repeat_rounded,
                            color: playerProvider.isRepeat ? accentColor : Colors.white54,
                            size: 22,
                          ),
                          onPressed: () => playerProvider.toggleRepeat(),
                        ),
                        IconButton(
                          icon: Icon(
                            playerProvider.isFavorite(currentSong.id)
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: playerProvider.isFavorite(currentSong.id)
                                ? Colors.pinkAccent
                                : Colors.white54,
                            size: 22,
                          ),
                          onPressed: () => playerProvider.toggleFavorite(currentSong),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
