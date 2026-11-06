import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/settings/profile_screen.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/new_ambient_canvas.dart';
import '../widgets/new_card.dart';
import '../widgets/new_section_header.dart';
import '../playlist/new_playlist_detail_screen.dart';

class NewHomeScreen extends ConsumerStatefulWidget {
  final VoidCallback? onOpenFullPlayer;

  const NewHomeScreen({super.key, this.onOpenFullPlayer});

  @override
  ConsumerState<NewHomeScreen> createState() => _NewHomeScreenState();
}

class _NewHomeScreenState extends ConsumerState<NewHomeScreen> {
  String _activeFilter = 'All';

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
    if (hour < 5) return 'Late Night Vibe';
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);
    final historyState = ref.watch(listeningHistoryProvider);
    final playerNotifier = ref.read(audioPlayerProvider.notifier);
    final authState = ref.watch(authProvider);
    final user = authState.currentUser;

    return NewAmbientCanvas(
      intensity: 0.38,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header / Editorial Greeting ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 18, bottom: 8),
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
                        onTap: () => setState(() => _activeFilter = filter),
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

              // ── Section 1: Recently Played / Jump Back In ──
              if (historyState.recentlyPlayed.isNotEmpty) ...[
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

              // ── Section 2: Made For You / Daily Mixes 1-6 ──
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
                      return NewCard(
                        title: mix['title'] as String,
                        subtitle: mix['subtitle'] as String,
                        imageUrl: mix['imageUrl'] as String?,
                        badgeText: 'MIX ${index + 1}',
                        width: 154,
                        onTap: () {
                          // Navigate to playlist detail
                          final playlist = Playlist(
                            id: 'daily_mix_${index + 1}',
                            title: mix['title'] as String,
                            subtitle: mix['subtitle'] as String,
                            image: mix['imageUrl'] as String? ?? '',
                            songCount: 20,
                          );
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

              // ── Section 3: Trending Now & Fresh Releases ──
              if (homeState.trendingSongs.isNotEmpty) ...[
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
                          badgeText: '#${index + 1}',
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

              // ── Section 4: Curated Playlists ──
              if (homeState.topPlaylists.isNotEmpty) ...[
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
                        return NewCard(
                          title: playlist.title,
                          subtitle: '${playlist.songCount} Tracks',
                          imageUrl: playlist.image,
                          width: 154,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    NewPlaylistDetailScreen(playlist: playlist),
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

              // ── Section 5: Essential Albums ──
              if (homeState.topAlbums.isNotEmpty) ...[
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
                        return NewCard(
                          title: album.title,
                          subtitle: album.subtitle,
                          imageUrl: album.image,
                          width: 154,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    NewPlaylistDetailScreen(playlist: album),
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
    );
  }

  static final List<Map<String, dynamic>> _dailyMixes = [
    {
      'title': 'Bollywood Romance',
      'subtitle': 'Arijit Singh, Pritam, Shreya Ghoshal',
      'imageUrl': 'https://c.saavncdn.com/editorial/RomanticHits2023Hindi_20231208053738.jpg',
    },
    {
      'title': 'Pop & International',
      'subtitle': 'The Weeknd, Taylor Swift, Dua Lipa',
      'imageUrl': 'https://c.saavncdn.com/editorial/PopHits2023_20231208053805.jpg',
    },
    {
      'title': 'Punjabi Beats',
      'subtitle': 'Diljit Dosanjh, Karan Aujla, AP Dhillon',
      'imageUrl': 'https://c.saavncdn.com/editorial/PunjabiHits2023_20231208053820.jpg',
    },
    {
      'title': 'Desi Hip-Hop',
      'subtitle': 'DIVINE, Seedhe Maut, King, MC Stan',
      'imageUrl': 'https://c.saavncdn.com/editorial/DesiHipHop_20231208053835.jpg',
    },
    {
      'title': 'Acoustic & Indie',
      'subtitle': 'Anuv Jain, Prateek Kuhad, Jasleen Royal',
      'imageUrl': 'https://c.saavncdn.com/editorial/IndieHits_20231208053850.jpg',
    },
    {
      'title': 'Club & Party Anthems',
      'subtitle': 'Badshah, Yo Yo Honey Singh, DJ Snake',
      'imageUrl': 'https://c.saavncdn.com/editorial/PartyHits2023_20231208053905.jpg',
    },
  ];
}
