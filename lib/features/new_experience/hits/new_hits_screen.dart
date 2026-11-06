import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/new_ambient_canvas.dart';
import '../widgets/new_section_header.dart';
import '../widgets/new_media_tile.dart';
import '../widgets/new_card.dart';
import '../playlist/new_playlist_detail_screen.dart';

class NewHitsScreen extends ConsumerWidget {
  const NewHitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeProvider);
    final playerNotifier = ref.read(audioPlayerProvider.notifier);

    return NewAmbientCanvas(
      intensity: 0.35,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 18, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CHARTS & TOP CHARTS',
                        style: NewExperienceTokens.eyebrowLabel(
                          color: NewExperienceTokens.accentCyan,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hits & Trending',
                        style: NewExperienceTokens.displayHero(fontSize: 28),
                      ),
                    ],
                  ),
                ),
              ),

              // Chart Playlists Cards
              if (homeState.chartPlaylists.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 220,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      scrollDirection: Axis.horizontal,
                      itemCount: homeState.chartPlaylists.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final chart = homeState.chartPlaylists[index];
                        return NewCard(
                          title: chart.title,
                          subtitle: chart.subtitle,
                          imageUrl: chart.image,
                          badgeText: 'CHART',
                          width: 150,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => NewPlaylistDetailScreen(playlist: chart),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ],

              // Top Trending Tracklist
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: NewSectionHeader(
                    title: 'Trending Tracks',
                    eyebrow: 'REAL-TIME POPULARITY',
                  ),
                ),
              ),

              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = homeState.trendingSongs[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: NewMediaTile(
                        song: song,
                        index: index,
                        onTap: () => playerNotifier.playSong(song, queue: homeState.trendingSongs, index: index),
                      ),
                    );
                  },
                  childCount: homeState.trendingSongs.length,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }
}
