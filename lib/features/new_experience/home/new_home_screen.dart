import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/home/home_provider.dart';
import 'package:it_feels_music/features/library/listening_history_provider.dart';
import 'package:it_feels_music/features/settings/profile_screen.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/new_ambient_canvas.dart';
import '../widgets/new_section_header.dart';
import '../widgets/new_card.dart';
import '../widgets/new_media_tile.dart';
import '../playlist/new_playlist_detail_screen.dart';
import '../see_all/new_see_all_screen.dart';
import '../theme/content_viewport_insets.dart';
import '../widgets/new_daily_mix_cover.dart';
import 'package:it_feels_music/core/intelligence/playlists/daily_mix_orchestrator.dart';
import 'package:it_feels_music/core/intelligence/catalogue/artwork_repair_service.dart';
import 'package:it_feels_music/core/intelligence/catalogue/content_enrichment_pipeline.dart';

class NewHomeScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenFullPlayer;

  const NewHomeScreen({
    super.key,
    required this.onOpenFullPlayer,
  });

  @override
  ConsumerState<NewHomeScreen> createState() => _NewHomeScreenState();
}

class _NewHomeScreenState extends ConsumerState<NewHomeScreen> {
  String _activeFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final homeState = ref.read(homeProvider);
      if (homeState.youPlaylists.isEmpty) {
        final topArtists = ref.read(listeningHistoryProvider).getTopArtists();
        ref.read(homeProvider.notifier).fetchYouSongs(topArtists);
      }
      ContentEnrichmentPipeline.instance.scheduleDailyMixEnrichment(homeState);
    });
  }

  final List<String> _filters = [
    'All',
    'For You',
    'Bollywood',
    'International',
    'Punjabi',
    'Acoustic',
    'Charts',
  ];

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _onSelectFilter(String filter) {
    setState(() => _activeFilter = filter);
    ref.read(homeFeedProvider.notifier).setFilter(filter);
    final homeNotifier = ref.read(homeProvider.notifier);
    final homeState = ref.read(homeProvider);
    if (filter == 'Bollywood' && homeState.bollywoodSongs.isEmpty) {
      homeNotifier.fetchBollywoodSongs();
    } else if (filter == 'International' && homeState.hollywoodSongs.isEmpty) {
      homeNotifier.fetchHollywoodSongs();
    } else if (filter == 'Punjabi' && homeState.punjabiSongs.isEmpty) {
      homeNotifier.fetchPunjabiSongs();
    } else if (filter == 'Charts' && homeState.chartPlaylists.isEmpty) {
      homeNotifier.fetchCharts();
    } else if (filter == 'For You' && homeState.youSongs.isEmpty) {
      final topArtists = ref.read(listeningHistoryProvider).getTopArtists();
      homeNotifier.fetchYouSongs(topArtists);
    }
  }

  bool _isCategoryEmpty(HomeState homeState, ListeningHistoryState historyState, String filter) {
    switch (filter) {
      case 'Bollywood':
        return homeState.bollywoodSongs.isEmpty && homeState.bollywoodPlaylists.isEmpty;
      case 'International':
        return homeState.hollywoodSongs.isEmpty && homeState.hollywoodPlaylists.isEmpty;
      case 'Punjabi':
        return homeState.punjabiSongs.isEmpty && homeState.punjabiPlaylists.isEmpty;
      case 'Charts':
        return homeState.chartPlaylists.isEmpty && homeState.trendingSongs.isEmpty;
      case 'For You':
        return historyState.recentlyPlayed.isEmpty && homeState.youSongs.isEmpty && homeState.youPlaylists.isEmpty;
      default:
        return false;
    }
  }

  String _getMixCover(int index, HomeState homeState) {
    final mixId = 'daily_mix_${index + 1}';
    final dynMix = DailyMixOrchestrator.instance.getMix(mixId);
    if (dynMix?.coverArt != null && dynMix!.coverArt!.isNotEmpty) {
      return dynMix.coverArt!;
    }
    for (final p in homeState.youPlaylists) {
      if (p.id == mixId && p.coverArt.isNotEmpty) {
        return p.coverArt;
      }
    }
    final repaired = ArtworkRepairService.instance.getDailyMixCover(mixId);
    if (repaired.isNotEmpty) return repaired;
    switch (index) {
      case 0:
        if (homeState.bollywoodSongs.isNotEmpty) return homeState.bollywoodSongs.first.coverArt;
        if (homeState.trendingSongs.isNotEmpty) return homeState.trendingSongs.first.coverArt;
        return '';
      case 1:
        if (homeState.hollywoodSongs.isNotEmpty) return homeState.hollywoodSongs.first.coverArt;
        return '';
      case 2:
        if (homeState.punjabiSongs.isNotEmpty) return homeState.punjabiSongs.first.coverArt;
        return '';
      case 3:
        if (homeState.trendingSongs.isNotEmpty) return homeState.trendingSongs.first.coverArt;
        return '';
      case 4:
        if (homeState.bollywoodSongs.length > 5) return homeState.bollywoodSongs[5].coverArt;
        return '';
      case 5:
        if (homeState.trendingSongs.length > 3) return homeState.trendingSongs[3].coverArt;
        return '';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);
    final historyState = ref.watch(listeningHistoryProvider);
    final playerNotifier = ref.read(audioPlayerProvider.notifier);
    final user = ref.watch(authProvider).currentUser;

    return NewAmbientCanvas(
      intensity: 0.45,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: NewExperienceTokens.accentViolet,
            backgroundColor: NewExperienceTokens.midnightSurface,
            onRefresh: () => ref.read(homeFeedProvider.notifier).refresh(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // ── Header Bar ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 18, bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting().toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: NewExperienceTokens.eyebrowLabel(
                                color: NewExperienceTokens.accentCyan,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Discover & Flow',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: NewExperienceTokens.displayHero(fontSize: 28),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const ProfileScreen()),
                          );
                        },
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: NewExperienceTokens.accentViolet.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: NewExperienceTokens.midnightSurface,
                            backgroundImage: user?.photoURL != null
                                ? NetworkImage(user!.photoURL!)
                                : null,
                            child: user?.photoURL == null
                                ? const Icon(
                                    Icons.person_rounded,
                                    size: 20,
                                    color: NewExperienceTokens.textSecondary,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Category Filter Capsules ──
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filters.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final isSelected = _activeFilter == filter;

                      return InkWell(
                        onTap: () => _onSelectFilter(filter),
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? NewExperienceTokens.accentViolet
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : NewExperienceTokens.specularBorder,
                            ),
                          ),
                          child: Text(
                            filter,
                            style: NewExperienceTokens.bodySmall(
                              color: isSelected
                                  ? Colors.white
                                  : NewExperienceTokens.textSecondary,
                            ).copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ── Section: Recently Played / Jump Back In ──
              if ((_activeFilter == 'All' || _activeFilter == 'For You') &&
                  historyState.recentlyPlayed.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Jump Back In',
                      eyebrow: 'CONTINUE LISTENING',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NewSeeAllScreen.songs(
                            title: 'Jump Back In',
                            eyebrow: 'CONTINUE LISTENING',
                            songs: historyState.recentlyPlayed,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 220,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: historyState.recentlyPlayed.take(12).length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final song = historyState.recentlyPlayed[index];
                        return NewCard(
                          title: song.title,
                          subtitle: song.artist,
                          imageUrl: song.image,
                          width: 148,
                          onTap: () => playerNotifier.playSong(song),
                          onPlay: () => playerNotifier.playSong(song),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Section: Made For You / Daily Mixes 1-6 ──
              if (_activeFilter == 'All' || _activeFilter == 'For You') ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Made For You',
                      eyebrow: 'DAILY CLUSTERS',
                      onAction: () => _openDailyMixesSeeAll(context, homeState),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 228,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _dailyMixes.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final mix = _dailyMixes[index];
                        final mixId = 'daily_mix_${index + 1}';
                        final dynMix = DailyMixOrchestrator.instance.getMix(mixId);
                        final cover = (dynMix?.coverArt != null && dynMix!.coverArt!.isNotEmpty)
                            ? dynMix.coverArt!
                            : _getMixCover(index, homeState);
                        final songs = (dynMix?.tracks != null && dynMix!.tracks.isNotEmpty)
                            ? dynMix.tracks
                            : homeState.youPlaylists.where((p) => p.id == mixId).firstOrNull?.songs;

                        final quadUrls = (songs ?? [])
                            .map((s) => s.image)
                            .where((u) => u.isNotEmpty && !u.contains('404'))
                            .take(4)
                            .toList();

                        return NewCard(
                          title: mix['title'] as String,
                          subtitle: mix['subtitle'] as String,
                          imageUrl: cover.isNotEmpty ? cover : null,
                          customArtwork: NewDailyMixCover(
                            mixIndex: index + 1,
                            title: mix['title'] as String,
                            subtitle: mix['subtitle'] as String,
                            quadImageUrls: quadUrls.isNotEmpty ? quadUrls : null,
                            primaryImageUrl: cover.isNotEmpty ? cover : null,
                          ),
                          badgeText: 'MIX ${index + 1}',
                          width: 154,
                          onTap: () {
                            final playlist = Playlist(
                              id: mixId,
                              title: mix['title'] as String,
                              subtitle: mix['subtitle'] as String,
                              image: cover,
                              songCount: songs?.length ?? 20,
                              songs: songs,
                            );
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => NewPlaylistDetailScreen(
                                  playlist: playlist,
                                  staticTracks: songs,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Section: For You Tracks ──
              if (_activeFilter == 'For You' && homeState.youSongs.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Recommended For You',
                      eyebrow: 'PERSONALIZED PICKS',
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = homeState.youSongs[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: NewMediaTile(
                          song: song,
                          index: index,
                          onTap: () => playerNotifier.playSong(
                            song,
                            queue: homeState.youSongs,
                            index: index,
                          ),
                        ),
                      );
                    },
                    childCount: homeState.youSongs.take(20).length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Section: Bollywood Hits (Filtered or All) ──
              if ((_activeFilter == 'All' || _activeFilter == 'Bollywood') &&
                  homeState.bollywoodSongs.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Bollywood Hits',
                      eyebrow: 'DESI FAVORITES',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NewSeeAllScreen.songs(
                            title: 'Bollywood Hits',
                            eyebrow: 'DESI FAVORITES',
                            songs: homeState.bollywoodSongs,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 220,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: homeState.bollywoodSongs.take(15).length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final song = homeState.bollywoodSongs[index];
                        return NewCard(
                          title: song.title,
                          subtitle: song.artist,
                          imageUrl: song.image,
                          width: 148,
                          onTap: () => playerNotifier.playSong(song),
                          onPlay: () => playerNotifier.playSong(song),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Section: Bollywood Curated Playlists (When in Bollywood tab) ──
              if (_activeFilter == 'Bollywood' && homeState.bollywoodPlaylists.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Bollywood Playlists',
                      eyebrow: 'CURATED DESI COLLECTIONS',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NewSeeAllScreen.playlists(
                            title: 'Bollywood Playlists',
                            eyebrow: 'CURATED DESI COLLECTIONS',
                            playlists: homeState.bollywoodPlaylists,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 228,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: homeState.bollywoodPlaylists.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final playlist = homeState.bollywoodPlaylists[index];
                        final sub = playlist.songCount > 0
                            ? '${playlist.songCount} Tracks'
                            : (playlist.customSubtitle ?? 'Curated Playlist');
                        return NewCard(
                          title: playlist.title,
                          subtitle: sub,
                          imageUrl: playlist.image,
                          width: 154,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => NewPlaylistDetailScreen(playlist: playlist),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Section: Bollywood Soundtracks & Albums (When in Bollywood tab) ──
              if (_activeFilter == 'Bollywood' && homeState.bollywoodAlbums.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Bollywood Soundtracks & Albums',
                      eyebrow: 'ORIGINAL SOUNDTRACKS',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NewSeeAllScreen.playlists(
                            title: 'Bollywood Soundtracks & Albums',
                            eyebrow: 'ORIGINAL SOUNDTRACKS',
                            playlists: homeState.bollywoodAlbums,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 228,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: homeState.bollywoodAlbums.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final album = homeState.bollywoodAlbums[index];
                        final sub = album.songCount > 0
                            ? '${album.songCount} Tracks'
                            : (album.customSubtitle ?? 'OST Album');
                        return NewCard(
                          title: album.title,
                          subtitle: sub,
                          imageUrl: album.image,
                          width: 154,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => NewPlaylistDetailScreen(playlist: album),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Section: Bollywood Track Explorer (When in Bollywood tab) ──
              if (_activeFilter == 'Bollywood' && homeState.bollywoodSongs.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Explore Bollywood Tracks',
                      eyebrow: 'POPULAR RELEASES',
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = homeState.bollywoodSongs[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: NewMediaTile(
                          song: song,
                          index: index,
                          onTap: () => playerNotifier.playSong(
                            song,
                            queue: homeState.bollywoodSongs,
                            index: index,
                          ),
                        ),
                      );
                    },
                    childCount: homeState.bollywoodSongs.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Section: Pop & International Hits ──
              if ((_activeFilter == 'All' || _activeFilter == 'International') &&
                  homeState.hollywoodSongs.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Pop & Global Hits',
                      eyebrow: 'INTERNATIONAL',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NewSeeAllScreen.songs(
                            title: 'Pop & Global Hits',
                            eyebrow: 'INTERNATIONAL',
                            songs: homeState.hollywoodSongs,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 220,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: homeState.hollywoodSongs.take(15).length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final song = homeState.hollywoodSongs[index];
                        return NewCard(
                          title: song.title,
                          subtitle: song.artist,
                          imageUrl: song.image,
                          width: 148,
                          onTap: () => playerNotifier.playSong(song),
                          onPlay: () => playerNotifier.playSong(song),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Section: Global Playlists (When in International tab) ──
              if (_activeFilter == 'International' && homeState.hollywoodPlaylists.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Global Playlists',
                      eyebrow: 'WORLDWIDE SELECTIONS',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NewSeeAllScreen.playlists(
                            title: 'Global Playlists',
                            eyebrow: 'WORLDWIDE SELECTIONS',
                            playlists: homeState.hollywoodPlaylists,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 228,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: homeState.hollywoodPlaylists.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final playlist = homeState.hollywoodPlaylists[index];
                        final sub = playlist.songCount > 0
                            ? '${playlist.songCount} Tracks'
                            : (playlist.customSubtitle ?? 'Global Playlist');
                        return NewCard(
                          title: playlist.title,
                          subtitle: sub,
                          imageUrl: playlist.image,
                          width: 154,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => NewPlaylistDetailScreen(playlist: playlist),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Section: International Albums (When in International tab) ──
              if (_activeFilter == 'International' && homeState.hollywoodAlbums.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'International Masterpieces',
                      eyebrow: 'TOP CHARTER ALBUMS',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NewSeeAllScreen.playlists(
                            title: 'International Masterpieces',
                            eyebrow: 'TOP CHARTER ALBUMS',
                            playlists: homeState.hollywoodAlbums,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 228,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: homeState.hollywoodAlbums.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final album = homeState.hollywoodAlbums[index];
                        final sub = album.songCount > 0
                            ? '${album.songCount} Tracks'
                            : (album.customSubtitle ?? 'International Album');
                        return NewCard(
                          title: album.title,
                          subtitle: sub,
                          imageUrl: album.image,
                          width: 154,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => NewPlaylistDetailScreen(playlist: album),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Section: International Track Explorer (When in International tab) ──
              if (_activeFilter == 'International' && homeState.hollywoodSongs.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Explore Global Pop & Hits',
                      eyebrow: 'GLOBAL STREAMING',
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = homeState.hollywoodSongs[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: NewMediaTile(
                          song: song,
                          index: index,
                          onTap: () => playerNotifier.playSong(
                            song,
                            queue: homeState.hollywoodSongs,
                            index: index,
                          ),
                        ),
                      );
                    },
                    childCount: homeState.hollywoodSongs.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Section: Punjabi Beats ──
              if ((_activeFilter == 'All' || _activeFilter == 'Punjabi') &&
                  homeState.punjabiSongs.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Punjabi Beats',
                      eyebrow: 'HIGH ENERGY',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NewSeeAllScreen.songs(
                            title: 'Punjabi Beats',
                            eyebrow: 'HIGH ENERGY',
                            songs: homeState.punjabiSongs,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 220,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: homeState.punjabiSongs.take(15).length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final song = homeState.punjabiSongs[index];
                        return NewCard(
                          title: song.title,
                          subtitle: song.artist,
                          imageUrl: song.image,
                          width: 148,
                          onTap: () => playerNotifier.playSong(song),
                          onPlay: () => playerNotifier.playSong(song),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Section: Punjabi Playlists (When in Punjabi tab) ──
              if (_activeFilter == 'Punjabi' && homeState.punjabiPlaylists.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Punjabi Playlists',
                      eyebrow: 'BHANGRA & DESI VIBES',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NewSeeAllScreen.playlists(
                            title: 'Punjabi Playlists',
                            eyebrow: 'BHANGRA & DESI VIBES',
                            playlists: homeState.punjabiPlaylists,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 228,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: homeState.punjabiPlaylists.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final playlist = homeState.punjabiPlaylists[index];
                        final sub = playlist.songCount > 0
                            ? '${playlist.songCount} Tracks'
                            : (playlist.customSubtitle ?? 'Punjabi Playlist');
                        return NewCard(
                          title: playlist.title,
                          subtitle: sub,
                          imageUrl: playlist.image,
                          width: 154,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => NewPlaylistDetailScreen(playlist: playlist),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Section: Punjabi Albums (When in Punjabi tab) ──
              if (_activeFilter == 'Punjabi' && homeState.punjabiAlbums.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Essential Punjabi Albums',
                      eyebrow: 'ICONIC ALBUMS',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NewSeeAllScreen.playlists(
                            title: 'Essential Punjabi Albums',
                            eyebrow: 'ICONIC ALBUMS',
                            playlists: homeState.punjabiAlbums,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 228,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: homeState.punjabiAlbums.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final album = homeState.punjabiAlbums[index];
                        final sub = album.songCount > 0
                            ? '${album.songCount} Tracks'
                            : (album.customSubtitle ?? 'Punjabi Album');
                        return NewCard(
                          title: album.title,
                          subtitle: sub,
                          imageUrl: album.image,
                          width: 154,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => NewPlaylistDetailScreen(playlist: album),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Section: Punjabi Track Explorer (When in Punjabi tab) ──
              if (_activeFilter == 'Punjabi' && homeState.punjabiSongs.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Explore Punjabi Hits',
                      eyebrow: 'BHANGRA & HIP-HOP',
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = homeState.punjabiSongs[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: NewMediaTile(
                          song: song,
                          index: index,
                          onTap: () => playerNotifier.playSong(
                            song,
                            queue: homeState.punjabiSongs,
                            index: index,
                          ),
                        ),
                      );
                    },
                    childCount: homeState.punjabiSongs.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Section: Acoustic & Indie (When in Acoustic tab) ──
              if (_activeFilter == 'Acoustic') ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Acoustic & Unplugged',
                      eyebrow: 'CALM & INTIMATE',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NewSeeAllScreen.playlists(
                            title: 'Acoustic & Unplugged',
                            eyebrow: 'CALM & INTIMATE',
                            playlists: homeState.topPlaylists,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 228,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        NewCard(
                          title: 'Acoustic & Indie',
                          subtitle: 'Anuv Jain, Prateek Kuhad, Jasleen Royal',
                          imageUrl: _getMixCover(4, homeState),
                          customArtwork: NewDailyMixCover(
                            mixIndex: 5,
                            title: 'Acoustic & Indie',
                            subtitle: 'Anuv Jain, Prateek Kuhad, Jasleen Royal',
                            primaryImageUrl: _getMixCover(4, homeState),
                          ),
                          badgeText: 'MIX 5',
                          width: 154,
                          onTap: () {
                            final match = homeState.youPlaylists.where((p) => p.id == 'daily_mix_5').firstOrNull;
                            final songs = match?.songs;
                            final playlist = Playlist(
                              id: 'daily_mix_5',
                              title: 'Acoustic & Indie',
                              subtitle: 'Anuv Jain, Prateek Kuhad, Jasleen Royal',
                              image: _getMixCover(4, homeState),
                              songCount: songs?.length ?? 20,
                              songs: songs,
                            );
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => NewPlaylistDetailScreen(
                                  playlist: playlist,
                                  staticTracks: songs,
                                ),
                              ),
                            );
                          },
                        ),
                        if (homeState.topPlaylists.isNotEmpty) ...[
                          const SizedBox(width: 14),
                          ...homeState.topPlaylists.take(6).map((playlist) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: NewCard(
                                title: playlist.title,
                                subtitle: playlist.songCount > 0 ? '${playlist.songCount} Tracks' : 'Curated Playlist',
                                imageUrl: playlist.image,
                                width: 154,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => NewPlaylistDetailScreen(playlist: playlist),
                                    ),
                                  );
                                },
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Section: Charts (When Filtered or In All) ──
              if ((_activeFilter == 'All' || _activeFilter == 'Charts') &&
                  homeState.chartPlaylists.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Global Charts',
                      eyebrow: 'TOP RANKINGS',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NewSeeAllScreen.playlists(
                            title: 'Global Charts',
                            eyebrow: 'TOP RANKINGS',
                            playlists: homeState.chartPlaylists,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 228,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: homeState.chartPlaylists.take(15).length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final chart = homeState.chartPlaylists[index];
                        final sub = chart.songCount > 0
                            ? '${chart.songCount} Tracks'
                            : (chart.customSubtitle ?? 'Official Chart');
                        return NewCard(
                          title: chart.title,
                          subtitle: sub,
                          imageUrl: chart.image,
                          width: 154,
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
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Section: Trending Hits ──
              if ((_activeFilter == 'All' || _activeFilter == 'Charts') &&
                  homeState.trendingSongs.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Trending Hits',
                      eyebrow: 'CHART TOPPERS',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NewSeeAllScreen.songs(
                            title: 'Trending Hits',
                            eyebrow: 'CHART TOPPERS',
                            songs: homeState.trendingSongs,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 220,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: homeState.trendingSongs.take(15).length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final song = homeState.trendingSongs[index];
                        return NewCard(
                          title: song.title,
                          subtitle: song.artist,
                          imageUrl: song.image,
                          badgeText: '#',
                          width: 148,
                          onTap: () => playerNotifier.playSong(song),
                          onPlay: () => playerNotifier.playSong(song),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Section: Chart Tracks Explorer (When in Charts tab) ──
              if (_activeFilter == 'Charts' && homeState.trendingSongs.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Trending Track Feed',
                      eyebrow: 'NOW PLAYING WORLDWIDE',
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
                          onTap: () => playerNotifier.playSong(
                            song,
                            queue: homeState.trendingSongs,
                            index: index,
                          ),
                        ),
                      );
                    },
                    childCount: homeState.trendingSongs.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Section: Curated Playlists (When in All or Acoustic) ──
              if ((_activeFilter == 'All' || _activeFilter == 'Acoustic') && homeState.topPlaylists.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Featured Playlists',
                      eyebrow: 'HANDPICKED COLLECTIONS',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NewSeeAllScreen.playlists(
                            title: 'Featured Playlists',
                            eyebrow: 'HANDPICKED COLLECTIONS',
                            playlists: homeState.topPlaylists,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 228,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: homeState.topPlaylists.take(15).length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final playlist = homeState.topPlaylists[index];
                        final sub = playlist.songCount > 0
                            ? '${playlist.songCount} Tracks'
                            : (playlist.customSubtitle ?? 'Curated Playlist');
                        return NewCard(
                          title: playlist.title,
                          subtitle: sub,
                          imageUrl: playlist.image,
                          width: 154,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => NewPlaylistDetailScreen(playlist: playlist),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Section: Essential Albums ──
              if ((_activeFilter == 'All' || _activeFilter == 'Acoustic') && homeState.topAlbums.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Essential Albums',
                      eyebrow: 'MASTERPIECES',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NewSeeAllScreen.playlists(
                            title: 'Essential Albums',
                            eyebrow: 'MASTERPIECES',
                            playlists: homeState.topAlbums,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 228,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: homeState.topAlbums.take(12).length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final album = homeState.topAlbums[index];
                        final sub = album.songCount > 0
                            ? '${album.songCount} Tracks'
                            : (album.customSubtitle ?? 'Masterpiece Album');
                        return NewCard(
                          title: album.title,
                          subtitle: sub,
                          imageUrl: album.image,
                          width: 154,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => NewPlaylistDetailScreen(playlist: album),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],

              // ── Loading state if filtered category is fetching ──
              if (_activeFilter != 'All' && _isCategoryEmpty(homeState, historyState, _activeFilter)) ...[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: NewExperienceTokens.accentViolet),
                          const SizedBox(height: 16),
                          Text(
                            'Curating $_activeFilter recommendations...',
                            style: NewExperienceTokens.bodyMedium(color: NewExperienceTokens.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              // Centralized dynamic bottom clearance preventing obstruction by MiniPlayer & NavDock
              ContentViewportInsets.sliverBottomSpacer(context, ref),
            ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDailyMixesSeeAll(BuildContext context, HomeState homeState) {
    final orchestrator = DailyMixOrchestrator.instance;
    final mixes = _dailyMixes.asMap().entries.map((entry) {
      final idx = entry.key;
      final mix = entry.value;
      final mixId = 'daily_mix_${idx + 1}';
      final dynMix = orchestrator.getMix(mixId);
      final cover = (dynMix?.coverArt != null && dynMix!.coverArt!.isNotEmpty)
          ? dynMix.coverArt!
          : _getMixCover(idx, homeState);
      final songs = (dynMix?.tracks != null && dynMix!.tracks.isNotEmpty)
          ? dynMix.tracks
          : homeState.youPlaylists.where((p) => p.id == mixId).firstOrNull?.songs;
      return Playlist(
        id: mixId,
        title: mix['title'] as String,
        subtitle: mix['subtitle'] as String,
        coverArt: cover,
        songCount: songs?.length ?? 20,
        songs: songs,
      );
    }).toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NewSeeAllScreen.playlists(
          title: 'Made For You',
          eyebrow: 'DAILY CLUSTERS',
          playlists: mixes,
        ),
      ),
    );
  }

  static final List<Map<String, dynamic>> _dailyMixes = [
    {
      'title': 'Bollywood Romance',
      'subtitle': 'Arijit Singh, Pritam, Shreya Ghoshal',
    },
    {
      'title': 'Pop & International',
      'subtitle': 'The Weeknd, Taylor Swift, Dua Lipa',
    },
    {
      'title': 'Punjabi Beats',
      'subtitle': 'Diljit Dosanjh, Karan Aujla, AP Dhillon',
    },
    {
      'title': 'Desi Hip-Hop',
      'subtitle': 'DIVINE, Seedhe Maut, King, MC Stan',
    },
    {
      'title': 'Acoustic & Indie',
      'subtitle': 'Anuv Jain, Prateek Kuhad, Jasleen Royal',
    },
    {
      'title': 'Club & Party Anthems',
      'subtitle': 'Badshah, Yo Yo Honey Singh, DJ Snake',
    },
  ];
}
