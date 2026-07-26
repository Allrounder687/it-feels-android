import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';

import '../../providers/audio_player_provider.dart';
import '../../providers/home_provider.dart';
import '../details/playlist_detail_screen.dart';
import '../widgets/hero_collage.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback openFullPlayer;

  const HomeScreen({super.key, required this.openFullPlayer});

  @override
  Widget build(BuildContext context) {
    return Consumer2<HomeProvider, AudioPlayerProvider>(
      builder: (context, homeProvider, playerProvider, child) {
        final trending = homeProvider.trendingSongs;
        final playlists = homeProvider.topPlaylists;

        return Scaffold(
          backgroundColor: AppColors.midnightBackground,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                // Top App Bar Icons
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.grid_view_rounded, color: Colors.white),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined, color: Colors.white),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ),

                // Headline Section: "Your Mix" + "Today's Mix for you" + Circular Action Play Button
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Your\nMix",
                              style: GoogleFonts.outfit(
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Today's Mix for you",
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.midnightTextMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        // Large Circular Play Accent Button
                        GestureDetector(
                          onTap: () {
                            if (trending.isNotEmpty) {
                              playerProvider.playSong(trending[0], queue: trending, index: 0);
                            }
                          },
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: AppColors.playButtonBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Color(0xFF09142E),
                              size: 36,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Organic Hero Artwork Collage
                SliverToBoxAdapter(
                  child: HeroCollage(
                    songs: trending,
                    onPlayTap: () {
                      if (trending.isNotEmpty) {
                        playerProvider.playSong(trending[0], queue: trending, index: 0);
                      }
                    },
                  ),
                ),

                // Top Playlists Horizontal Section
                if (playlists.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24, right: 20, top: 20, bottom: 12),
                      child: Text(
                        "Featured Playlists",
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 170,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: playlists.length,
                        itemBuilder: (context, index) {
                          final pl = playlists[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlaylistDetailScreen(playlist: pl),
                                ),
                              );
                            },
                            child: Container(
                              width: 130,
                              margin: const EdgeInsets.only(right: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: AspectRatio(
                                      aspectRatio: 1.0,
                                      child: pl.coverArt.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: pl.coverArt,
                                              fit: BoxFit.cover,
                                              errorWidget: (context, url, error) =>
                                                  Container(color: AppColors.midnightCard),
                                            )
                                          : Container(color: AppColors.midnightCard),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    pl.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // Trending Songs Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 24, right: 20, top: 24, bottom: 12),
                    child: Text(
                      "Trending Now",
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                if (homeProvider.isLoading)
                  const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(color: AppColors.midnightAccent),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = trending[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          child: Material(
                            color: AppColors.midnightCard.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(16),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: song.coverArt.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: song.coverArt,
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(Icons.music_note, color: Colors.white),
                                ),
                              ),
                              title: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: AppColors.midnightTextMuted,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: const Icon(Icons.more_vert, color: Colors.white54),
                              onTap: () {
                                playerProvider.playSong(song, queue: trending, index: index);
                              },
                            ),
                          ),
                        );
                      },
                      childCount: trending.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        );
      },
    );
  }
}
