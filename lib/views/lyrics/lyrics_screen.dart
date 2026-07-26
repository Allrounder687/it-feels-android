import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/lyrics_provider.dart';
import '../widgets/wavy_seek_bar.dart';

class LyricsScreen extends StatefulWidget {
  const LyricsScreen({super.key});

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final playerProvider = Provider.of<AudioPlayerProvider>(context, listen: false);
      final lyricsProvider = Provider.of<LyricsProvider>(context, listen: false);

      if (playerProvider.currentSong != null) {
        lyricsProvider.fetchLyrics(playerProvider.currentSong!);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveLine(int activeIndex, int totalLines) {
    if (!_scrollController.hasClients || activeIndex < 0) return;
    const itemHeight = 44.0;
    final targetOffset = (activeIndex * itemHeight) - 120.0;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AudioPlayerProvider, LyricsProvider>(
      builder: (context, playerProvider, lyricsProvider, child) {
        final mode = lyricsProvider.mode;
        final lyricsResult = lyricsProvider.lyricsResult;
        final activeIndex = lyricsProvider.getActiveLineIndex(playerProvider.position);

        // CONCEPTUAL UI NOTE:
        // With the addition of `lyricsProvider.lyricsNotFound`, this section
        // should be updated to show a specific "No Lyrics Found" message.
        // For example:
        //
        // if (lyricsProvider.isLoading) {
        //   return const Center(child: CircularProgressIndicator(color: Colors.white));
        // } else if (lyricsProvider.lyricsNotFound) {
        //   return const Center(child: Text("No lyrics available for this song", style: TextStyle(color: Colors.white70)));
        // } else if (mode == LyricsMode.synced && lyricsResult != null && lyricsResult.hasSynced) {
        //   // ... existing ListView.builder
        // } else {
        //   // ... existing SingleChildScrollView for static lyrics
        // }
        //
        // This ensures the user gets clear feedback when lyrics are not available.

        if (mode == LyricsMode.synced && lyricsResult != null && lyricsResult.hasSynced) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToActiveLine(activeIndex, lyricsResult.syncedLyrics.length);
          });
        }

        return Scaffold(
          backgroundColor: playerProvider.themeBackgroundColor,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    // Header Bar (Back Arrow + "Lyrics" Title)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: playerProvider.themeSurfaceColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              "Lyrics",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48), // Spacer for center alignment
                        ],
                      ),
                    ),

                    // Toggle Switch Pill (Synced vs Static)
                    Container(
                      height: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: playerProvider.themeSurfaceColor,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => lyricsProvider.setMode(LyricsMode.synced),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: mode == LyricsMode.synced
                                      ? playerProvider.themeAccentColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Center(
                                  child: Text(
                                    "Synced",
                                    style: GoogleFonts.inter(
                                      color: mode == LyricsMode.synced ? Colors.black : Colors.white70,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => lyricsProvider.setMode(LyricsMode.static),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: mode == LyricsMode.static
                                      ? playerProvider.themeAccentColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Center(
                                  child: Text(
                                    "Static",
                                    style: GoogleFonts.inter(
                                      color: mode == LyricsMode.static ? Colors.black : Colors.white70,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Lyrics Text View
                    Expanded(
                      child: lyricsProvider.isLoading
                          ? const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            )
                          : mode == LyricsMode.synced && lyricsResult != null && lyricsResult.hasSynced
                              ? ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                  itemCount: lyricsResult.syncedLyrics.length,
                                  itemBuilder: (context, index) {
                                    final line = lyricsResult.syncedLyrics[index];
                                    final isActive = index == activeIndex;

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      child: Text(
                                        line.text,
                                        style: GoogleFonts.outfit(
                                          fontSize: isActive ? 22 : 18,
                                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                                          color: isActive
                                              ? Colors.white
                                              : AppColors.burgundyTextMuted.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                  child: Text(
                                    lyricsResult?.staticLyrics ?? "No lyrics available for this song",
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      height: 1.6,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                    ),

                    const SizedBox(height: 100),
                  ],
                ),

                // Floating Mini Control Overlay with Play/Pause & Mini Wavy Seekbar
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.burgundySurface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Play/Pause Square Button (Screen 4 style)
                        GestureDetector(
                          onTap: () => playerProvider.togglePlayPause(),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4E1B3),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              playerProvider.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Mini Wavy Seekbar & Timestamps
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              WavySeekBar(
                                position: playerProvider.position,
                                duration: playerProvider.duration,
                                activeColor: Colors.white,
                                inactiveColor: Colors.white24,
                                onSeek: (newPos) => playerProvider.seek(newPos),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(playerProvider.position),
                                    style: GoogleFonts.inter(color: Colors.white60, fontSize: 11),
                                  ),
                                  Text(
                                    _formatDuration(playerProvider.duration),
                                    style: GoogleFonts.inter(color: Colors.white60, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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
