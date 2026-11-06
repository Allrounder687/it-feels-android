import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/home/home_provider.dart';
import 'package:it_feels_music/features/settings/profile_screen.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/new_ambient_canvas.dart';
import '../widgets/new_section_header.dart';
import '../widgets/new_card.dart';
import '../widgets/new_media_tile.dart';
import '../playlist/new_playlist_detail_screen.dart';

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
  }

  String _getMixCover(int index, HomeState homeState) {
    final mixId = 'daily_mix_${index + 1}';
    for (final p in homeState.youPlaylists) {
      if (p.id == mixId && p.coverArt.isNotEmpty) {
        return p.coverArt;
      }
    }
    switch (index) {
      case 0:
        if (homeState.bollywoodSongs.isNotEmpty) return homeState.bollywoodSongs.first.coverArt;
        if (homeState.trendingSongs.isNotEmpty) return homeState.trendingSongs.first.coverArt;
        return 'https://c.saavncdn.com/152/Arijit-Singh-Broken-Heart-Hindi-2022-20220422171542-500x500.jpg';
      case 1:
        if (homeState.hollywoodSongs.isNotEmpty) return homeState.hollywoodSongs.first.coverArt;
        return 'https://c.saavncdn.com/830/Starboy-English-2016-500x500.jpg';
      case 2:
        if (homeState.punjabiSongs.isNotEmpty) return homeState.punjabiSongs.first.coverArt;
        return 'https://c.saavncdn.com/269/Ghost-Punjabi-2023-20230929054714-500x500.jpg';
      case 3:
        return 'https://c.saavncdn.com/568/Kohinoor-Hindi-2019-20191008064504-500x500.jpg';
      case 4:
        return 'https://c.saavncdn.com/131/Alag-Aasman-Hindi-2020-20200730073539-500x500.jpg';
      case 5:
        return 'https://c.saavncdn.com/712/Badshah-Greatest-Hits-Hindi-2022-20220317053036-500x500.jpg';
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
                      onAction: () {},
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
                      onAction: () {},
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
                        final cover = _getMixCover(index, homeState);
                        final mixId = 'daily_mix_${index + 1}';
                        final match = homeState.youPlaylists.where((p) => p.id == mixId).firstOrNull;
                        final songs = (match?.songs != null && match!.songs!.isNotEmpty) ? match.songs : null;

                        return NewCard(
                          title: mix['title'] as String,
                          subtitle: mix['subtitle'] as String,
                          imageUrl: cover.isNotEmpty ? cover : null,
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
                      onAction: () {},
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

              // ── Section: Pop & International Hits ──
              if ((_activeFilter == 'All' || _activeFilter == 'International') &&
                  homeState.hollywoodSongs.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Pop & Global Hits',
                      eyebrow: 'INTERNATIONAL',
                      onAction: () {},
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

              // ── Section: Punjabi Beats ──
              if ((_activeFilter == 'All' || _activeFilter == 'Punjabi') &&
                  homeState.punjabiSongs.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Punjabi Beats',
                      eyebrow: 'HIGH ENERGY',
                      onAction: () {},
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

              // ── Section: Charts (When Filtered or In All) ──
              if ((_activeFilter == 'All' || _activeFilter == 'Charts') &&
                  homeState.chartPlaylists.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Global Charts',
                      eyebrow: 'TOP RANKINGS',
                      onAction: () {},
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
                      onAction: () {},
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

              // ── Section: Curated Playlists ──
              if (_activeFilter == 'All' && homeState.topPlaylists.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Featured Playlists',
                      eyebrow: 'HANDPICKED COLLECTIONS',
                      onAction: () {},
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
              if (_activeFilter == 'All' && homeState.topAlbums.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Essential Albums',
                      eyebrow: 'MASTERPIECES',
                      onAction: () {},
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

              // Bottom clearance so content never collides with docked playback bar
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
            ),
          ),
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
