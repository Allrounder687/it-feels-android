import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';

class ShareStoryCanvas extends StatelessWidget {
  final Song song;
  final Color dominantColor;

  const ShareStoryCanvas({
    super.key,
    required this.song,
    required this.dominantColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1080,
      height: 1920,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            dominantColor.withValues(alpha: 0.8),
            AppColors.midnightBackground,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Background blurred image
          Positioned.fill(
            child: Opacity(
              opacity: 0.2,
              child: CustomImageWidget(
                imageUrl: song.coverArt,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Artwork
                Container(
                  width: 800,
                  height: 800,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 40,
                        spreadRadius: 10,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: CustomImageWidget(
                      imageUrl: song.coverArt,
                      width: 800,
                      height: 800,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 80),
                
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 100),
                  child: Text(
                    song.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Artist
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 100),
                  child: Text(
                    song.artist,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 48,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Branding
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Icon(Icons.music_note_rounded, color: Colors.white54, size: 48),
                const SizedBox(height: 16),
                Text(
                  'It Feels Music',
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
