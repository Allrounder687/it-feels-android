import 'package:it_feels_music/views/widgets/custom_image_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/lyrics_provider.dart';
import '../widgets/wavy_seek_bar.dart';

class LyricsScreen extends StatelessWidget {
  const LyricsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<LyricsProvider, AudioPlayerProvider>(
      builder: (context, lyricsProvider, playerProvider, child) {
        final currentSong = playerProvider.currentSong;
        final position = playerProvider.position;

        if (currentSong != null) {
          lyricsProvider.loadLyricsIfNeeded(currentSong, position);
        }

        return Scaffold(
          backgroundColor: AppColors.midnightBackground,
          body: SafeArea(
            child: Column(
              children: [
                // Top Navigation Bar (Back Arrow, Title, Toggle Pill)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.midnightPill,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        "Lyrics",
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),

                      // Synced vs Static Mode Pill
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.midnightPill,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => lyricsProvider.setMode(LyricsMode.synced),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: lyricsProvider.mode == LyricsMode.synced
                                      ? AppColors.midnightPrimary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  "Synced",
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: lyricsProvider.mode == LyricsMode.synced
                                        ? Colors.black
                                        : Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => lyricsProvider.setMode(LyricsMode.static),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: lyricsProvider.mode == LyricsMode.static
                                      ? AppColors.midnightPrimary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  "Static",
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: lyricsProvider.mode == LyricsMode.static
                                        ? Colors.black
                                        : Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Lyrics View Container
                Expanded(
                  child: lyricsProvider.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.midnightAccent),
                        )
                      : lyricsProvider.mode == LyricsMode.synced &&
                              lyricsProvider.result.hasSynced
                          ? ListView.builder(
                              controller: lyricsProvider.scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                              itemCount: lyricsProvider.result.syncedLyrics.length,
                              itemBuilder: (context, index) {
                                final line = lyricsProvider.result.syncedLyrics[index];
                                final isActive = index == lyricsProvider.activeIndex;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                    style: GoogleFonts.outfit(
                                      fontSize: isActive ? 30 : 22,
                                      fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
                                      color: isActive
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.4),
                                      height: 1.3,
                                      shadows: isActive
                                          ? [
                                              BoxShadow(
                                                color: AppColors.midnightAccent.withValues(alpha: 0.6),
                                                blurRadius: 16,
                                                offset: const Offset(0, 4),
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: Text(line.text),
                                  ),
                                );
                              },
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                              child: Text(
                                lyricsProvider.result.staticLyrics ?? "No lyrics available for this track",
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                  height: 1.6,
                                ),
                              ),
                            ),
                ),

                // Bottom Floating Mini Control Bar Overlay
                if (currentSong != null)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.midnightCard.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: currentSong.coverArt.isNotEmpty
                                ? CustomImageWidget(imageUrl: currentSong.coverArt, fit: BoxFit.cover)
                                : const Icon(Icons.music_note, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentSong.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              WavySeekBar(
                                position: playerProvider.position,
                                duration: playerProvider.duration,
                                activeColor: AppColors.midnightAccent,
                                inactiveColor: Colors.white24,
                                onSeek: (pos) => playerProvider.seek(pos),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        GestureDetector(
                          onTap: () => playerProvider.togglePlayPause(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: AppColors.midnightPrimary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              playerProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.black,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
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
