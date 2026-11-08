import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/intelligence/charts/chart_aggregation_service.dart';
import 'package:it_feels_music/core/intelligence/charts/chart_feed_provider.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/new_ambient_canvas.dart';
import '../theme/content_viewport_insets.dart';
import '../widgets/new_section_header.dart';
import '../widgets/new_media_tile.dart';
import '../widgets/new_action_button.dart';
import '../widgets/new_card.dart';
import '../playlist/new_playlist_detail_screen.dart';

class NewHitsScreen extends ConsumerStatefulWidget {
  const NewHitsScreen({super.key});

  @override
  ConsumerState<NewHitsScreen> createState() => _NewHitsScreenState();
}

class _NewHitsScreenState extends ConsumerState<NewHitsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      if (currentScroll >= (maxScroll * 0.85)) {
        ref.read(chartFeedProvider.notifier).loadMore();
      }
    }
  }

  String _formatLastUpdated(DateTime? date) {
    if (date == null) return 'Live Rankings';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inHours < 1) return 'Updated moments ago';
    if (diff.inHours < 24) return 'Updated today';
    return 'Updated ${date.day}/${date.month}/${date.year}';
  }

  Widget _buildRankBadge(int rank) {
    if (rank == 1) {
      return Container(
        width: 32,
        height: 24,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
          ),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
              blurRadius: 8,
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '#1',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      );
    } else if (rank == 2) {
      return Container(
        width: 32,
        height: 24,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE2E8F0), Color(0xFF94A3B8)],
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Center(
          child: Text(
            '#2',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      );
    } else if (rank == 3) {
      return Container(
        width: 32,
        height: 24,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF97316), Color(0xFFB45309)],
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Center(
          child: Text(
            '#3',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 32,
      child: Center(
        child: Text(
          '$rank',
          style: NewExperienceTokens.numericTimer(
            color: NewExperienceTokens.textMuted,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chartState = ref.watch(chartFeedProvider);
    final homeState = ref.watch(homeProvider);
    final playerNotifier = ref.read(audioPlayerProvider.notifier);

    final activeDef = ChartAggregationService.categories.firstWhere(
      (c) => c.id == chartState.activeCategory,
      orElse: () => ChartAggregationService.categories.first,
    );

    return NewAmbientCanvas(
      intensity: 0.38,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: NewExperienceTokens.accentCyan,
            backgroundColor: NewExperienceTokens.midnightSurface,
            onRefresh: () => ref.read(chartFeedProvider.notifier).refresh(),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                // ── Header Title & Subtitle ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 18, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOP CHARTS & POPULARITY',
                          style: NewExperienceTokens.eyebrowLabel(
                            color: NewExperienceTokens.accentCyan,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hits & Trending',
                          style: NewExperienceTokens.displayHero(fontSize: 28),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatLastUpdated(chartState.lastUpdated)} • ${chartState.allTracks.length} Verified Tracks',
                          style: NewExperienceTokens.captionMuted(),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Interactive Chart Category Pills ──
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 42,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: ChartAggregationService.categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = ChartAggregationService.categories[index];
                        final isSelected = cat.id == chartState.activeCategory;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref.read(chartFeedProvider.notifier).loadCategory(cat.id);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? NewExperienceTokens.accentCyan
                                  : NewExperienceTokens.cardSurface.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(NewExperienceTokens.radiusPill),
                              border: Border.all(
                                color: isSelected
                                    ? NewExperienceTokens.accentCyan
                                    : NewExperienceTokens.specularBorder,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                cat.title,
                                style: TextStyle(
                                  color: isSelected ? Colors.black : Colors.white,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 14)),

                // ── Play All & Shuffle Bar ──
                if (chartState.allTracks.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Row(
                        children: [
                          NewActionButton(
                            label: 'Play Chart',
                            icon: Icons.play_arrow_rounded,
                            onPressed: () {
                              playerNotifier.playSong(
                                chartState.allTracks.first,
                                queue: chartState.allTracks,
                                index: 0,
                              );
                            },
                          ),
                          const SizedBox(width: 10),
                          NewActionButton(
                            label: 'Shuffle',
                            icon: Icons.shuffle_rounded,
                            variant: NewActionButtonVariant.glass,
                            onPressed: () {
                              final shuffled = List<Song>.from(chartState.allTracks)..shuffle();
                              playerNotifier.playSong(
                                shuffled.first,
                                queue: shuffled,
                                index: 0,
                              );
                            },
                          ),
                          const Spacer(),
                          Text(
                            activeDef.subtitle,
                            style: NewExperienceTokens.eyebrowLabel(
                              color: NewExperienceTokens.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Editorial Chart Playlists Carousel (Optional Companion) ──
                if (homeState.chartPlaylists.isNotEmpty) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: homeState.chartPlaylists.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final chart = homeState.chartPlaylists[index];
                          final sub = chart.songCount > 0
                              ? '${chart.songCount} Tracks'
                              : (chart.customSubtitle ?? 'Chart Collection');
                          return NewCard(
                            title: chart.title,
                            subtitle: sub,
                            imageUrl: chart.image,
                            badgeText: 'CHART',
                            width: 140,
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
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ── Section Header ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: activeDef.title,
                      eyebrow: 'RANKED LEADERBOARD',
                    ),
                  ),
                ),

                // ── Ranked Tracklist ──
                if (chartState.visibleTracks.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = chartState.visibleTracks[index];
                        final rank = index + 1;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              _buildRankBadge(rank),
                              const SizedBox(width: 8),
                              Expanded(
                                child: NewMediaTile(
                                  song: song,
                                  showIndex: false,
                                  onTap: () => playerNotifier.playSong(
                                    song,
                                    queue: chartState.allTracks,
                                    index: index,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: chartState.visibleTracks.length,
                    ),
                  )
                else if (chartState.isLoading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(50),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: NewExperienceTokens.accentCyan),
                            const SizedBox(height: 16),
                            Text(
                              'Compiling verified 50-track charts...',
                              style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (chartState.error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_off_rounded, color: Colors.amber, size: 40),
                            const SizedBox(height: 12),
                            Text(chartState.error!, style: NewExperienceTokens.bodyMedium()),
                            const SizedBox(height: 12),
                            NewActionButton(
                              label: 'Retry',
                              icon: Icons.refresh_rounded,
                              onPressed: () => ref.read(chartFeedProvider.notifier).refresh(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Loading More Indicator ──
                if (chartState.isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: NewExperienceTokens.accentCyan,
                        ),
                      ),
                    ),
                  ),

                // ── Dynamic Centralized Bottom Inset ──
                ContentViewportInsets.sliverBottomSpacer(context, ref),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
