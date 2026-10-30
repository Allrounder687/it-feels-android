import 'package:flutter/material.dart';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:it_feels_music/data/models/song_model.dart';

class NeoAlbumArt extends StatelessWidget {
  final Song song;
  final bool isPlaying;
  final Color glowColor;
  final double size;

  const NeoAlbumArt({
    super.key,
    required this.song,
    required this.isPlaying,
    required this.glowColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedScale(
        scale: isPlaying ? 1.0 : 0.92,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: isPlaying ? 0.40 : 0.20),
                blurRadius: isPlaying ? 38 : 22,
                spreadRadius: isPlaying ? 4 : 0,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'cover_${song.id}',
                  child: song.coverArt.isNotEmpty
                      ? CustomImageWidget(
                          imageUrl: song.coverArt,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFF1E2433),
                            child: const Icon(
                              Icons.music_note_rounded,
                              size: 64,
                              color: Colors.white38,
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF1E2433),
                          child: const Icon(
                            Icons.music_note_rounded,
                            size: 64,
                            color: Colors.white38,
                          ),
                        ),
                ),

                // Subtle top specular rim highlight on the glass edge
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 1.5,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.35),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
