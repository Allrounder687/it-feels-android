import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:it_feels_music/core/widgets/tv_focusable_card.dart';
import 'package:it_feels_music/data/models/song_model.dart';

class HomeHeroBanner extends ConsumerWidget {
  final List<Song> heroSongs;

  const HomeHeroBanner({
    super.key,
    required this.heroSongs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (heroSongs.isEmpty) return const SizedBox.shrink();

    // Use up to 5 songs for the hero carousel
    final carouselSongs = heroSongs.take(5).toList();
    
    // Determine card dimensions adaptively from smallest to largest screen
    final screenWidth = MediaQuery.of(context).size.width;
    final hPadding = screenWidth < 600 ? 16.0 : 32.0;
    final double cardWidth = screenWidth < 400
        ? (screenWidth * 0.80).clamp(210.0, 280.0)
        : (screenWidth < 600
            ? (screenWidth * 0.72).clamp(260.0, 340.0)
            : (screenWidth * 0.32).clamp(300.0, 460.0));
    final double cardHeight = cardWidth * (9 / 16);

    return SizedBox(
      height: cardHeight + (screenWidth < 600 ? 28 : 40),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: hPadding),
          itemCount: carouselSongs.length,
          itemBuilder: (context, index) {
            final heroSong = carouselSongs[index];

            return Padding(
              padding: const EdgeInsets.only(right: 24.0, top: 16.0, bottom: 16.0),
              child: SizedBox(
                width: cardWidth,
                child: TVFocusableCard(
                  onTap: () => ref
                      .read(audioPlayerProvider.notifier)
                      .playSong(heroSong, queue: carouselSongs, index: index),
                  focusedScale: 1.02,
                  borderRadius: 12.0,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Background Image
                          heroSong.coverArt.isNotEmpty
                              ? CustomImageWidget(
                                  imageUrl: heroSong.coverArt,
                                  fit: BoxFit.cover,
                                )
                              : Container(color: context.themeSurfaceColor),
                          
                          // Gradient Overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.3),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.8),
                                ],
                                stops: const [0.0, 0.4, 1.0],
                              ),
                            ),
                          ),
                          
                          // Content
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Top Tag
                                Text(
                                  "NEW RELEASE",
                                  style: GoogleFonts.inter(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                    fontSize: 12,
                                    shadows: const [
                                      Shadow(offset: Offset(0, 2), blurRadius: 6.0, color: Color(0xD9000000)),
                                    ],
                                  ),
                                ),
                                
                                // Bottom Metadata
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      heroSong.title,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        shadows: const [
                                          Shadow(offset: Offset(0, 2), blurRadius: 6.0, color: Color(0xD9000000)),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      heroSong.artist,
                                      style: GoogleFonts.inter(
                                        color: Colors.white70,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        shadows: const [
                                          Shadow(offset: Offset(0, 2), blurRadius: 6.0, color: Color(0xD9000000)),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
