import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/core/widgets/song_options_sheet.dart';
import 'package:it_feels_music/features/cast/cast_bottom_sheet.dart';
import 'package:it_feels_music/features/cast/cast_service.dart';
import 'package:it_feels_music/features/player/lyrics_screen.dart';
import 'package:it_feels_music/features/player/queue_bottom_sheet.dart';
import 'package:it_feels_music/features/player/sleep_timer_sheet.dart';
import 'package:it_feels_music/features/neo/theme/neo_ambient_mesh.dart';
import 'package:it_feels_music/features/neo/player/widgets/neo_album_art.dart';
import 'package:it_feels_music/features/neo/player/widgets/neo_scrubber.dart';
import 'package:it_feels_music/features/neo/player/widgets/neo_playback_controls.dart';

class NeoNowPlayingScreen extends ConsumerStatefulWidget {
  const NeoNowPlayingScreen({super.key});

  @override
  ConsumerState<NeoNowPlayingScreen> createState() => _NeoNowPlayingScreenState();
}

class _NeoNowPlayingScreenState extends ConsumerState<NeoNowPlayingScreen> {
  @override
  Widget build(BuildContext context) {
    ref.listen(audioPlayerProvider.select((p) => p.currentSong), (previous, next) {
      if (next != null) {
        ref.read(lyricsProvider.notifier).loadLyricsIfNeeded(next);
      }
    });

    final playerState = ref.watch(audioPlayerProvider);
    final downloadState = ref.watch(downloadProvider);
    final currentSong = playerState.currentSong;

    if (currentSong == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF090D16),
        body: Center(
          child: Text(
            "No song selected",
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
          ),
        ),
      );
    }

    final accentColor = playerState.themeAccentColor;
    final primaryColor = playerState.themeBackgroundColor;
    final isFav = playerState.isFavorite(currentSong.id);
    final isDown = downloadState.isDownloaded(currentSong.id);
    final isDownloading = downloadState.isDownloading(currentSong.id);

    final screenSize = MediaQuery.of(context).size;
    final artSize = (screenSize.width * 0.78).clamp(240.0, 340.0);

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: NeoAmbientMesh(
        primaryColor: primaryColor,
        accentColor: accentColor,
        darkMutedColor: const Color(0xFF101726),
        child: SafeArea(
          bottom: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null && details.primaryVelocity! > 180) {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22.0),
              child: Column(
                children: [
                  // ── Top Bar: Sheet Handle & Secondary Utilities ──
                  const SizedBox(height: 6),
                  Center(
                    child: Container(
                      width: 38,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        tooltip: 'Collapse Player',
                      ),
                      // Hi-Res Audio Micro-Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          "LOSSLESS • 320 KBPS",
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Builder(builder: (context) {
                            final isCasting = locator<CastService>().isConnected;
                            return IconButton(
                              icon: Icon(
                                isCasting ? Icons.cast_connected_rounded : Icons.cast_rounded,
                                color: isCasting ? accentColor : Colors.white70,
                                size: 22,
                              ),
                              onPressed: () => CastBottomSheet.show(context),
                              tooltip: 'Cast Audio',
                            );
                          }),
                          IconButton(
                            icon: const Icon(
                              Icons.more_horiz_rounded,
                              color: Colors.white70,
                              size: 24,
                            ),
                            onPressed: () => SongOptionsSheet.show(context, currentSong),
                            tooltip: 'More Options',
                          ),
                        ],
                      ),
                    ],
                  ),

                  // ── Middle: 1:1 Elevated Squircle Artwork ──
                  const Spacer(flex: 1),
                  NeoAlbumArt(
                    song: currentSong,
                    isPlaying: playerState.isPlaying,
                    glowColor: accentColor,
                    size: artSize,
                  ),
                  const Spacer(flex: 2),

                  // ── Lower Third: Thumb Command Center ──
                  // 1. Song Title & Artist + Favorite Heart
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentSong.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              currentSong.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? const Color(0xFFFF2D55) : Colors.white54,
                          size: 26,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ref.read(audioPlayerProvider.notifier).toggleFavorite(currentSong);
                        },
                        tooltip: 'Favorite',
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 2. Neo Scrubber
                  NeoScrubber(accentColor: accentColor),

                  const SizedBox(height: 16),

                  // 3. Primary Playback Controls Cluster
                  NeoPlaybackControls(accentColor: accentColor),

                  const SizedBox(height: 20),

                  // 4. Utility Row (Lyrics, Queue, Timer, Download)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Lyrics Drawer Button
                      IconButton(
                        icon: const Icon(Icons.lyrics_rounded, color: Colors.white60, size: 22),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LyricsScreen()),
                          );
                        },
                        tooltip: 'Live Synced Lyrics',
                      ),

                      // Queue Drawer Button
                      IconButton(
                        icon: const Icon(Icons.queue_music_rounded, color: Colors.white60, size: 22),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const QueueBottomSheet(),
                          );
                        },
                        tooltip: 'Up Next Queue',
                      ),

                      // Sleep Timer Button
                      IconButton(
                        icon: const Icon(Icons.bedtime_rounded, color: Colors.white60, size: 22),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const SleepTimerSheet(),
                          );
                        },
                        tooltip: 'Sleep Timer',
                      ),

                      // Download Status Button
                      IconButton(
                        icon: isDownloading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white70,
                                ),
                              )
                            : Icon(
                                isDown ? Icons.download_done_rounded : Icons.download_rounded,
                                color: isDown ? accentColor : Colors.white60,
                                size: 22,
                              ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          if (!isDown && !isDownloading) {
                            ref.read(downloadProvider.notifier).downloadSong(currentSong);
                          }
                        },
                        tooltip: isDown ? 'Downloaded' : 'Download Offline',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
