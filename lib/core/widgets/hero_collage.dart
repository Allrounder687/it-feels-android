import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

class HeroCollage extends StatelessWidget {
  final List<Song> songs;
  final VoidCallback? onPlayTap;

  const HeroCollage({
    super.key,
    required this.songs,
    this.onPlayTap,
  });

  @override
  Widget build(BuildContext context) {
    final images = songs.map((s) => s.coverArt).where((img) => img.isNotEmpty).toList();

    return Container(
      width: double.infinity,
      height: 240,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Stack(
        children: [
          // Main Center Rounded Organic Shape
          Positioned(
            left: 30,
            right: 30,
            top: 20,
            bottom: 10,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(48),
                boxShadow: [
                  BoxShadow(
                    color: context.themeInvertedTextColor.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(48),
                child: images.isNotEmpty
                    ? CustomImageWidget(
                        imageUrl: images[0],
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(color: const Color(0xFF2C1622)),
                      )
                    : Container(color: const Color(0xFF2C1622)),
              ),
            ),
          ),

          // Top Left Floating Bubble Tile
          Positioned(
            left: 10,
            top: 40,
            width: 70,
            height: 70,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(35),
              child: images.length > 1
                  ? CustomImageWidget(
                      imageUrl: images[1],
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(color: Colors.pinkAccent.withValues(alpha: 0.3)),
                    )
                  : Container(color: Colors.pinkAccent.withValues(alpha: 0.3)),
            ),
          ),

          // Bottom Right Floating Bubble Tile
          Positioned(
            right: 15,
            bottom: 20,
            width: 80,
            height: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: images.length > 2
                  ? CustomImageWidget(
                      imageUrl: images[2],
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(color: Colors.blueAccent.withValues(alpha: 0.3)),
                    )
                  : Container(color: Colors.blueAccent.withValues(alpha: 0.3)),
            ),
          ),
        ],
      ),
    );
  }
}
