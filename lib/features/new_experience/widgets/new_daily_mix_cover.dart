import 'package:flutter/material.dart';
import '../theme/new_experience_tokens.dart';
import 'new_artwork_image.dart';

/// Preset visual configuration for each of the 6 Daily Mixes.
class DailyMixThemeConfig {
  final List<Color> gradientColors;
  final Color accentColor;
  final String genreTag;
  final IconData genreIcon;

  const DailyMixThemeConfig({
    required this.gradientColors,
    required this.accentColor,
    required this.genreTag,
    required this.genreIcon,
  });

  static const List<DailyMixThemeConfig> presets = [
    // Mix 1: Bollywood Romance
    DailyMixThemeConfig(
      gradientColors: [Color(0xFF8E0E00), Color(0xFF4A0012), Color(0xFF190006)],
      accentColor: Color(0xFFFF3366),
      genreTag: 'ROMANCE',
      genreIcon: Icons.favorite_rounded,
    ),
    // Mix 2: Pop & International
    DailyMixThemeConfig(
      gradientColors: [Color(0xFF47289E), Color(0xFF281169), Color(0xFF0F0523)],
      accentColor: Color(0xFF8A53FF),
      genreTag: 'INTERNATIONAL',
      genreIcon: Icons.public_rounded,
    ),
    // Mix 3: Punjabi Beats
    DailyMixThemeConfig(
      gradientColors: [Color(0xFFD9480F), Color(0xFF7A2002), Color(0xFF220800)],
      accentColor: Color(0xFFFF9436),
      genreTag: 'PUNJABI',
      genreIcon: Icons.local_fire_department_rounded,
    ),
    // Mix 4: Desi Hip-Hop
    DailyMixThemeConfig(
      gradientColors: [Color(0xFF064E3B), Color(0xFF022C22), Color(0xFF01140F)],
      accentColor: Color(0xFF00F5A0),
      genreTag: 'HIP-HOP',
      genreIcon: Icons.mic_external_on_rounded,
    ),
    // Mix 5: Acoustic & Indie
    DailyMixThemeConfig(
      gradientColors: [Color(0xFF115E59), Color(0xFF042F2E), Color(0xFF021616)],
      accentColor: Color(0xFF38D39F),
      genreTag: 'ACOUSTIC',
      genreIcon: Icons.nature_people_rounded,
    ),
    // Mix 6: Club & Party Anthems
    DailyMixThemeConfig(
      gradientColors: [Color(0xFF9D174D), Color(0xFF500724), Color(0xFF1B000C)],
      accentColor: Color(0xFFFF2E93),
      genreTag: 'CLUB & PARTY',
      genreIcon: Icons.nightlife_rounded,
    ),
  ];

  static DailyMixThemeConfig forIndex(int mixIndex) {
    final idx = (mixIndex - 1).clamp(0, presets.length - 1);
    return presets[idx];
  }
}

/// Standalone, Spotify-grade Daily Mix Cover widget.
/// Guarantees that Mixes 1-6 ALWAYS have vibrant, high-contrast, designed artwork,
/// whether offline, loading, or populated with live track album art.
class NewDailyMixCover extends StatelessWidget {
  final int mixIndex; // 1 to 6
  final String? title;
  final String? subtitle;
  final List<String>? quadImageUrls;
  final String? primaryImageUrl;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const NewDailyMixCover({
    super.key,
    required this.mixIndex,
    this.title,
    this.subtitle,
    this.quadImageUrls,
    this.primaryImageUrl,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(NewExperienceTokens.radiusMedium);
    final theme = DailyMixThemeConfig.forIndex(mixIndex);

    // Clean valid track image URLs
    final validImages = (quadImageUrls ?? [])
        .where((u) => u.trim().isNotEmpty && !u.contains('404') && !u.contains('default_artwork'))
        .toList();

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.gradientColors,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: Concentric Vinyl Record Grooves (CustomPainter)
            CustomPaint(
              painter: _VinylGroovesPainter(accentColor: theme.accentColor),
            ),

            // Layer 2: Live Quad-Art or Hero Art (if valid images available)
            if (validImages.length >= 4)
              _buildQuadArt(validImages)
            else if (validImages.isNotEmpty)
              _buildHeroArt(validImages.first)
            else if (primaryImageUrl != null &&
                primaryImageUrl!.trim().isNotEmpty &&
                !primaryImageUrl!.contains('404') &&
                !primaryImageUrl!.contains('Broken-Heart'))
              _buildHeroArt(primaryImageUrl!),

            // Layer 3: Branded Daily Mix Glass Typography Overlay
            _buildBrandedOverlay(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildQuadArt(List<String> images) {
    return Opacity(
      opacity: 0.82,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: NewArtworkImage(imageUrl: images[0], fit: BoxFit.cover)),
                Expanded(child: NewArtworkImage(imageUrl: images[1], fit: BoxFit.cover)),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: NewArtworkImage(imageUrl: images[2], fit: BoxFit.cover)),
                Expanded(child: NewArtworkImage(imageUrl: images[3], fit: BoxFit.cover)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroArt(String imageUrl) {
    return Opacity(
      opacity: 0.85,
      child: NewArtworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildBrandedOverlay(DailyMixThemeConfig theme) {
    final hasImages = (quadImageUrls != null && quadImageUrls!.isNotEmpty) ||
        (primaryImageUrl != null && primaryImageUrl!.isNotEmpty && !primaryImageUrl!.contains('404'));

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: hasImages ? 0.35 : 0.15),
            Colors.black.withValues(alpha: hasImages ? 0.75 : 0.40),
          ],
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top: DAILY MIX header pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Text(
                  'DAILY MIX',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              Icon(
                theme.genreIcon,
                color: theme.accentColor.withValues(alpha: 0.9),
                size: 15,
              ),
            ],
          ),

          // Center: Large prominent Mix Numeral
          Center(
            child: Text(
              '$mixIndex',
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.5,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                  Shadow(
                    color: theme.accentColor.withValues(alpha: 0.5),
                    blurRadius: 24,
                  ),
                ],
              ),
            ),
          ),

          // Bottom: Genre Tag with mini equalizer bars
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.accentColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    theme.genreTag,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.accentColor,
                      fontSize: 8.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Mini Equalizer soundwave indicator
              _buildMiniEqualizer(theme.accentColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniEqualizer(Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _bar(color, 6),
        const SizedBox(width: 2),
        _bar(color, 11),
        const SizedBox(width: 2),
        _bar(color, 8),
        const SizedBox(width: 2),
        _bar(color, 13),
      ],
    );
  }

  Widget _bar(Color color, double height) {
    return Container(
      width: 2.5,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Custom painter for authentic vinyl groove arcs
class _VinylGroovesPainter extends CustomPainter {
  final Color accentColor;

  const _VinylGroovesPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width * 0.9, size.height * 0.1);
    final maxRadius = size.width * 1.2;

    for (double r = 20; r < maxRadius; r += 16) {
      final alpha = (0.04 + (r / maxRadius) * 0.05).clamp(0.02, 0.12);
      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
