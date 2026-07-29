import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import '../../providers/audio_player_provider.dart';
import '../widgets/custom_image_widget.dart';

class DrivingModeScreen extends StatelessWidget {
  const DrivingModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // High contrast
      body: Consumer<AudioPlayerProvider>(
        builder: (context, playerProvider, _) {
          final song = playerProvider.currentSong;
          final isPlaying = playerProvider.isPlaying;

          if (song == null) {
            return Center(
              child: Text(
                "No music playing",
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 24),
              ),
            );
          }

          return GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! < 0) {
                  // Swipe Left -> Next
                  playerProvider.skipToNext();
                } else if (details.primaryVelocity! > 0) {
                  // Swipe Right -> Previous
                  playerProvider.skipToPrevious();
                }
              }
            },
            onTap: () => playerProvider.togglePlayPause(),
            child: Container(
              color: Colors.black,
              width: double.infinity,
              height: double.infinity,
              child: SafeArea(
                child: Stack(
                  children: [
                    // Background blur of cover art
                    Opacity(
                      opacity: 0.3,
                      child: CustomImageWidget(
                        url: song.coverArt,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    
                    // Main UI
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(),
                          // Huge Text
                          Text(
                            song.title,
                            style: GoogleFonts.outfit(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.1,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            song.artist,
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          
                          // Play/Pause Icon Indicator
                          Icon(
                            isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                            size: 120,
                            color: context.themeAccentColor,
                          ),
                          
                          const SizedBox(height: 48),
                          
                          // Swipe instructions
                          Text(
                            "Tap to Play/Pause • Swipe Left/Right to Skip",
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Exit button
                    Positioned(
                      top: 16,
                      left: 16,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
