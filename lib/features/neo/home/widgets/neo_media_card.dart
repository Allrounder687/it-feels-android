import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';

class NeoMediaCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final double size;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const NeoMediaCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.size = 135.0,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      margin: const EdgeInsets.only(right: 14.0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        onLongPress: () {
          if (onLongPress != null) {
            HapticFeedback.mediumImpact();
            onLongPress!();
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1:1 Squircle Artwork with dynamic depth
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageUrl.isNotEmpty
                        ? CustomImageWidget(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              color: const Color(0xFF1B2232),
                              child: const Icon(
                                Icons.music_note_rounded,
                                color: Colors.white30,
                                size: 36,
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF1B2232),
                            child: const Icon(
                              Icons.music_note_rounded,
                              color: Colors.white30,
                              size: 36,
                            ),
                          ),

                    // Top 1px specular highlight rim
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 1.0,
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Track / Playlist Title
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),

            // Subtitle / Artist
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
