import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/new_ambient_canvas.dart';
import '../widgets/new_section_header.dart';
import '../widgets/new_media_tile.dart';
import '../widgets/new_card.dart';
import '../playlist/new_playlist_detail_screen.dart';

class NewHitsScreen extends ConsumerStatefulWidget {
  const NewHitsScreen({super.key});

  @override
  ConsumerState<NewHitsScreen> createState() => _NewHitsScreenState();
}

class _NewHitsScreenState extends ConsumerState<NewHitsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final homeState = ref.read(homeProvider);
      final homeNotifier = ref.read(homeProvider.notifier);
      if (homeState.chartPlaylists.isEmpty) {
        homeNotifier.fetchCharts();
      }
      if (homeState.trendingSongs.isEmpty) {
        homeNotifier.loadHomepageData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);
    final playerNotifier = ref.read(audioPlayerProvider.notifier);

    // Cascading fallback to ensure trending tracklist is never empty
    List<Song> effectiveTrending = homeState.trendingSongs;
    if (effectiveTrending.isEmpty) {
      if (homeState.youSongs.isNotEmpty) {
        effectiveTrending = homeState.youSongs;
      } else if (homeState.bollywoodSongs.isNotEmpty) {
        effectiveTrending = homeState.bollywoodSongs;
      } else if (homeState.hollywoodSongs.isNotEmpty) {
        effectiveTrending = homeState.hollywoodSongs;
      } else if (homeState.punjabiSongs.isNotEmpty) {
        effectiveTrending = homeState.punjabiSongs;
      }
    }

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
                        final sub = chart.songCount > 0
                            ? '${chart.songCount} Tracks'
                            : (chart.customSubtitle ?? 'Top Chart');
                        return NewCard(
                          title: chart.title,
                          subtitle: sub,
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

              // Top Trending Tracklist Section Header
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: NewSectionHeader(
                    title: 'Trending Tracks',
                    eyebrow: 'REAL-TIME POPULARITY',
                  ),
                ),
              ),

              if (effectiveTrending.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = effectiveTrending[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: NewMediaTile(
                          song: song,
                          index: index,
                          onTap: () => playerNotifier.playSong(
                            song,
                            queue: effectiveTrending,
                            index: index,
                          ),
                        ),
                      );
                    },
                    childCount: effectiveTrending.length,
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: NewExperienceTokens.accentViolet),
                          const SizedBox(height: 16),
                          Text(
                            'Fetching live chart hits...',
                            style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
                          ),
                        ],
                      ),
                    ),
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
