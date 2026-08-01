import 'dart:io';
import 'dart:ui';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/features/home/home_provider.dart';
import 'package:it_feels_music/features/settings/hidden_songs_provider.dart';
import 'package:it_feels_music/features/library/listening_history_provider.dart';
import 'package:it_feels_music/features/ai/ai_settings_provider.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/library/playlist_detail_screen.dart';
import 'package:it_feels_music/features/library/see_all_screen.dart';
import 'package:it_feels_music/features/settings/settings_screen.dart';
import 'package:it_feels_music/features/settings/profile_screen.dart';
import 'package:it_feels_music/features/ai/ask_ai_screen.dart';
import 'package:it_feels_music/core/widgets/song_options_sheet.dart';
import 'package:it_feels_music/features/settings/profile_provider.dart';
import 'package:it_feels_music/features/home/smart_recommendations_row.dart';
import 'package:it_feels_music/features/social/room_bottom_sheet.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback openFullPlayer;

  const HomeScreen({super.key, required this.openFullPlayer});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedFilterIndex = 0;
  final PageController _swipePageController = PageController(viewportFraction: 0.88);
  final List<String> _filters = [
    "For You",
    "Music",
    "Podcasts",
    "Charts",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final homeProv = ref.read(homeProvider);
      final historyProvider = ref.read(listeningHistoryProvider);
      
      final idx = _filters.indexOf(homeProv.selectedCategory);
      if (idx != -1 && mounted) {
        setState(() {
          _selectedFilterIndex = idx;
        });
      }

      if (homeProv.selectedCategory == "For You" && homeProv.currentCategoryPlaylists.isEmpty) {
        ref.read(homeProvider.notifier).fetchYouSongs(historyProvider.getTopArtists());
        if (homeProv.moodPlaylists.isEmpty) ref.read(homeProvider.notifier).fetchMoods();
      } else if (homeProv.selectedCategory == "Charts") {
        ref.read(homeProvider.notifier).fetchCharts();
      } else if (homeProv.selectedCategory == "Music") {
        ref.read(homeProvider.notifier).selectCategory("Music");
      }
    });
  }

  @override
  void dispose() {
    _swipePageController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    if (hour < 21) return "Good Evening";
    return "Late Night Vibes";
  }

  Widget _buildHeroBanner(BuildContext context, Song heroSong, AudioPlayerState player) {
    return Container(
      height: 280,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: context.themeInvertedTextColor.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: heroSong.coverArt.isNotEmpty
                  ? CustomImageWidget(imageUrl: heroSong.coverArt, fit: BoxFit.cover)
                  : Container(color: context.themeSurfaceColor),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 216,
                      height: 216,
                      child: heroSong.coverArt.isNotEmpty
                          ? CustomImageWidget(imageUrl: heroSong.coverArt, fit: BoxFit.cover)
                          : Container(color: context.themeSurfaceColor),
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "FEATURED",
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          heroSong.title,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          heroSong.artist,
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => ref.read(audioPlayerProvider.notifier).playSong(heroSong, queue: [heroSong], index: 0),
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.black),
                          label: Text(
                            "Play Now",
                            style: GoogleFonts.inter(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildPlaylistCarousel(BuildContext context, String title, List<Playlist> playlists) {
    if (playlists.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              title,
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: context.themeTextColor),
            ),
          ),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final pl = playlists[index];
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlaylistDetailScreen(playlist: pl))),
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: 1.0,
                            child: pl.coverArt.isNotEmpty
                                ? CustomImageWidget(imageUrl: pl.coverArt, fit: BoxFit.cover)
                                : Container(color: context.themeCardColor),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          pl.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(color: context.themeTextColor, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSongCarousel(BuildContext context, String title, List<Song> songs, AudioPlayerState playerProvider) {
    if (songs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: context.themeTextColor)),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SeeAllSongsScreen(title: title, songs: songs))),
                  child: Text("See All", style: GoogleFonts.inter(color: AppColors.midnightAccent, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isWide = screenWidth >= 600;
              final crossAxisCount = isWide ? 4 : 3;
              final carouselHeight = isWide ? 290.0 : 220.0;
              
              return SizedBox(
                height: carouselHeight,
                child: GridView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.25,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                  ),
              itemCount: songs.length > 15 ? 15 : songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return GestureDetector(
                  onTap: () => ref.read(audioPlayerProvider.notifier).playSong(song, queue: songs, index: index),
                  onLongPress: () => SongOptionsSheet.show(context, song, playlistContext: songs),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 56, height: 56,
                          child: song.coverArt.isNotEmpty
                              ? CustomImageWidget(imageUrl: song.coverArt, fit: BoxFit.cover)
                              : Container(color: AppColors.midnightPill),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: context.themeTextColor, fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.more_vert_rounded, color: context.themeMutedTextColor, size: 20),
                        onPressed: () => SongOptionsSheet.show(context, song, playlistContext: songs),
                      )
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final homeProv = ref.watch(homeProvider);
        final playerProvider = ref.watch(audioPlayerProvider);
        final hiddenProvider = ref.watch(hiddenSongsProvider);
        final historyProvider = ref.watch(listeningHistoryProvider);
        final selectedCat = _filters[_selectedFilterIndex];
        
        List<Song> activeSongs = homeProv.currentCategorySongs.where((s) => !hiddenProvider.isHidden(s.id)).toList();
        if (selectedCat == "For You") {
          activeSongs = historyProvider.recentlyPlayed.where((s) => !hiddenProvider.isHidden(s.id)).toList();
        }
        
        return Scaffold(
          backgroundColor: context.themeBackgroundColor,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [


                // Top App Bar Branding
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ref.watch(profileProvider).getGreeting(), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.themeMutedTextColor)),
                            Text("It Feels", style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w900, color: context.themeTextColor, letterSpacing: -0.5)),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (ref.watch(aiSettingsProvider).isConfigured)
                              IconButton(
                                icon: Icon(Icons.auto_awesome_rounded, color: context.themeTextColor, size: 22),
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AskAIScreen())),
                                tooltip: 'Ask Feels',
                              ),
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                child: Consumer(builder: (context, ref, _) { final profile = ref.watch(profileProvider); 
                                    final hasAvatar = profile.userAvatar.isNotEmpty && File(profile.userAvatar).existsSync();
                                    return CircleAvatar(
                                      radius: 16,
                                      backgroundColor: context.themeAccentColor.withValues(alpha: 0.2),
                                      backgroundImage: hasAvatar ? FileImage(File(profile.userAvatar)) : null,
                                      child: hasAvatar
                                          ? null
                                          : Icon(Icons.person_outline, color: context.themeTextColor, size: 20),
                                    );
                                  },
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.cell_tower_rounded, 
                                color: playerProvider.isInRoom ? Colors.greenAccent : context.themeTextColor, 
                                size: 22
                              ),
                              onPressed: () => RoomBottomSheet.show(context, isHost: false),
                              tooltip: 'Listen Together',
                            ),
                            IconButton(
                              icon: Icon(Icons.settings_outlined, color: context.themeTextColor, size: 22),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Category Filter Chips Bar
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _filters.length,
                      itemBuilder: (context, index) {
                        final isSelected = index == _selectedFilterIndex;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedFilterIndex = index);
                            ref.read(homeProvider.notifier).selectCategory(_filters[index]);
                            if (_filters[index] == "For You" && homeProv.currentCategoryPlaylists.isEmpty) {
                              ref.read(homeProvider.notifier).fetchYouSongs(historyProvider.getTopArtists());
                              if (homeProv.moodPlaylists.isEmpty) ref.read(homeProvider.notifier).fetchMoods();
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFF9C27B0)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                                  : null,
                              color: isSelected ? null : context.themeUnselectedPillColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? Colors.transparent : context.themeTextColor10, width: 0.5),
                            ),
                            child: Text(
                              _filters[index],
                              style: GoogleFonts.inter(color: isSelected ? Colors.white : context.themeUnselectedPillTextColor, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Tablet Hero Banner
                if (MediaQuery.of(context).size.width >= 700 && activeSongs.isNotEmpty && selectedCat == "For You")
                  SliverToBoxAdapter(
                    child: _buildHeroBanner(context, activeSongs.first, playerProvider),
                  ),

                if (homeProv.isLoading && activeSongs.isEmpty && selectedCat != "For You")
                  const SliverToBoxAdapter(
                    child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: AppColors.midnightAccent))),
                  ),

                if (selectedCat == "For You") ...[
                  if (activeSongs.isEmpty && homeProv.youPlaylists.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.headphones_rounded, size: 64, color: context.themeMutedTextColor.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            Text("Your Music, Your Rules", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: context.themeTextColor)),
                            const SizedBox(height: 8),
                            Text("Listen to more songs to unlock your personalized Daily Mixes and history.", textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: context.themeMutedTextColor)),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(bottom: 24), child: SmartRecommendationsRow())),
                    _buildPlaylistCarousel(context, "Curated Moods", homeProv.moodPlaylists),
                    _buildPlaylistCarousel(context, "Daily Mixes", homeProv.youPlaylists),
                    _buildSongCarousel(context, "Recently Played", activeSongs, playerProvider),
                  ]
                ] 
                else if (selectedCat == "Music") ...[
                  // Render Horizontal Swipeable Song Grid Carousels for Genres
                  _buildSongCarousel(context, "Trending Now", homeProv.trendingSongs, playerProvider),
                  _buildSongCarousel(context, "Bollywood Hits", homeProv.bollywoodSongs, playerProvider),
                  _buildSongCarousel(context, "Punjabi Hits", homeProv.punjabiSongs, playerProvider),
                  _buildSongCarousel(context, "Telugu Hits", homeProv.teluguSongs, playerProvider),
                  _buildSongCarousel(context, "Tamil Hits", homeProv.tamilSongs, playerProvider),
                  _buildSongCarousel(context, "Hollywood Pop", homeProv.hollywoodSongs, playerProvider),
                  _buildPlaylistCarousel(context, "Top Albums", homeProv.topAlbums),
                ]
                else if (selectedCat == "Podcasts") ...[
                  _buildPlaylistCarousel(context, "Top Podcasts", homeProv.podcastPlaylists),
                  _buildSongCarousel(context, "Latest Episodes", activeSongs, playerProvider),
                ]
                else if (selectedCat == "Charts") ...[
                  _buildPlaylistCarousel(context, "Global Charts", homeProv.chartPlaylists.take(5).toList()),
                  _buildPlaylistCarousel(context, "Billboard Hot 100", homeProv.chartPlaylists.skip(5).take(5).toList()),
                  _buildPlaylistCarousel(context, "Viral 50", homeProv.chartPlaylists.skip(10).take(5).toList()),
                  _buildPlaylistCarousel(context, "Top 50", homeProv.chartPlaylists.skip(15).take(5).toList()),
                ],

                SliverToBoxAdapter(child: SizedBox(height: 168 + MediaQuery.of(context).viewPadding.bottom)),
              ],
            ),
          ),
        );
      },
    );
  }
}
