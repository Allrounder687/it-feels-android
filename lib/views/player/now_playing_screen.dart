import 'package:pixel_player_saavn/views/widgets/custom_image_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/download_provider.dart';
import '../lyrics/lyrics_screen.dart';
import '../widgets/song_options_sheet.dart';
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
    final artSize = (screenWidth * 0.84).clamp(250.0, 360.0);

    return Consumer2<AudioPlayerProvider, DownloadProvider>(
      builder: (context, playerProvider, downloadProvider, child) {
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

        final isFav = playerProvider.isFavorite(currentSong.id);
        final isDown = downloadProvider.isDownloaded(currentSong.id);
        final isDownloading = downloadProvider.isDownloading(currentSong.id);

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

                      // Action Buttons (Download + Lyrics + Queue Menu)
                      Row(
                        children: [
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: isDownloading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Icon(
                                      isDown ? Icons.download_done_rounded : Icons.file_download_outlined,
                                      color: isDown ? accentColor : Colors.white,
                                      size: 20,
                                    ),
                            ),
                            onPressed: () async {
                              if (isDown) {
                                await downloadProvider.removeDownload(currentSong);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Removed ${currentSong.title} from downloads")),
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Downloading ${currentSong.title}...")),
                                );
                                final ok = await downloadProvider.downloadSong(currentSong);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(ok ? "Downloaded ${currentSong.title}" : "Download failed")),
                                  );
                                }
                              }
                            },
                          ),
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                            ),
                            onPressed: () {
                              SongOptionsSheet.show(context, currentSong);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Center Album Artwork with Hero Animation
                  Hero(
                    tag: 'cover_${currentSong.id}',
                    child: Container(
                      width: artSize,
                      height: artSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: currentSong.coverArt.isNotEmpty
                            ? CustomImageWidget(
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

                  // Song Title & Artist
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentSong.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentSong.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.burgundyTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Spacious Action Pills Row (Like, Download, Lyrics)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Favorite / Like Pill
                        GestureDetector(
                          onTap: () => playerProvider.toggleFavorite(currentSong),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: surfaceColor.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: isFav ? Colors.pinkAccent : Colors.white70,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isFav ? "Liked" : "Like",
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Download Pill
                        GestureDetector(
                          onTap: () async {
                            if (isDown) {
                              await downloadProvider.removeDownload(currentSong);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Removed ${currentSong.title} from downloads")),
                                );
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Downloading ${currentSong.title}...")),
                              );
                              final ok = await downloadProvider.downloadSong(currentSong);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(ok ? "Downloaded ${currentSong.title}" : "Download failed")),
                                );
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: surfaceColor.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                isDownloading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Icon(
                                        isDown ? Icons.download_done_rounded : Icons.file_download_outlined,
                                        color: isDown ? accentColor : Colors.white70,
                                        size: 18,
                                      ),
                                const SizedBox(width: 8),
                                Text(
                                  isDown ? "Downloaded" : "Download",
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Lyrics Pill
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LyricsScreen()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: surfaceColor.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lyrics_outlined, color: Colors.white70, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  "Lyrics",
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Signature Wavy Seek Bar Progress Slider
                  WavySeekBar(
                    position: playerProvider.position,
                    duration: playerProvider.duration,
                    activeColor: accentColor,
                    inactiveColor: Colors.white24,
                    onSeek: (newPos) => playerProvider.seek(newPos),
                  ),

                  // Timestamps Row
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

                  const SizedBox(height: 16),

                  // Primary Control Bar (Play/Pause, Prev, Next, Seek -10s/+10s)
                  Container(
                    height: 80,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.replay_10_rounded, color: Colors.white70, size: 28),
                          onPressed: () => playerProvider.seekBackward(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 36),
                          onPressed: () => playerProvider.skipToPrevious(),
                        ),

                        // Center Big Play/Pause Toggle
                        GestureDetector(
                          onTap: () => playerProvider.togglePlayPause(),
                          child: Container(
                            width: 62,
                            height: 62,
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
                        IconButton(
                          icon: const Icon(Icons.forward_10_rounded, color: Colors.white70, size: 28),
                          onPressed: () => playerProvider.seekForward(),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Bottom Drag Handle & "Your queue" Button
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const QueueBottomSheet(),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white38,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Your queue",
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
