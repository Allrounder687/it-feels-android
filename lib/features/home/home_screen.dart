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
import 'package:it_feels_music/data/models/feed_shelf.dart';
import 'package:it_feels_music/features/settings/settings_screen.dart';
import 'package:it_feels_music/features/settings/profile_screen.dart';
import 'package:it_feels_music/features/ai/ask_ai_screen.dart';
import 'package:it_feels_music/core/widgets/song_options_sheet.dart';
import 'package:it_feels_music/features/settings/profile_provider.dart';
import 'package:it_feels_music/features/home/smart_recommendations_row.dart';
import 'package:it_feels_music/features/social/room_bottom_sheet.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/widgets/tv_focusable_card.dart';
import 'package:it_feels_music/core/theme/app_dimensions.dart';

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
    if (hour < 12) return "Good Morning ☀️";
    if (hour < 17) return "Good Afternoon ☕";
    if (hour < 21) return "Good Evening 👋";
    return "Late Night Vibes 🌙";
  }

  Widget _buildHeroBanner(BuildContext context, Song heroSong, AudioPlayerState player) {
    final isWide = MediaQuery.of(context).size.width >= 600;
    return TVFocusableCard(
      onTap: () => ref.read(audioPlayerProvider.notifier).playSong(heroSong, queue: [heroSong], index: 0),
      focusedScale: 1.02,
      child: Container(
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
                  ? ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: CustomImageWidget(imageUrl: heroSong.coverArt, fit: BoxFit.cover),
                    )
                  : Container(color: context.themeSurfaceColor),
            ),
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(isWide ? 32.0 : 24.0),
              child: Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: isWide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: isWide ? 216 : double.infinity,
                      height: isWide ? 216 : 216,
                      child: heroSong.coverArt.isNotEmpty
                          ? CustomImageWidget(imageUrl: heroSong.coverArt, fit: BoxFit.cover)
                          : Container(color: context.themeSurfaceColor),
                    ),
                  ),
                  SizedBox(width: isWide ? 32 : 0, height: isWide ? 0 : 24),
                  Expanded(
                    flex: isWide ? 1 : 0,
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
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          heroSong.title,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: isWide ? 42 : 32,
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
                            fontSize: isWide ? 22 : 18,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_arrow_rounded, color: Colors.black),
                              const SizedBox(width: 8),
                              Text(
                                "Play Now",
                                style: GoogleFonts.inter(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
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
          ],
        ), // Stack
      ), // ClipRRect
      ), // Container
    );
  }

  Widget _buildSpotifyRecentGrid(BuildContext context, List<Song> songs, AudioPlayerState playerProvider) {
    if (songs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    
    // Skip the first song if it's already shown in the hero banner
    final recentSongs = songs.skip(1).take(6).toList();
    if (recentSongs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.8,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final song = recentSongs[index];
            return TVFocusableCard(
              onTap: () => ref.read(audioPlayerProvider.notifier).playSong(song, queue: recentSongs, index: index),
              onLongPress: () => SongOptionsSheet.show(context, song, playlistContext: recentSongs),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: song.coverArt.isNotEmpty
                          ? CustomImageWidget(imageUrl: song.coverArt, fit: BoxFit.cover, size: 100)
                          : Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.midnightAccent, AppColors.midnightPill],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(Icons.music_note, color: Colors.white54, size: 24),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        song.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: context.themeTextColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            );
          },
          childCount: recentSongs.length,
        ),
      ),
    );
  }

  Widget _buildTopArtistsCarousel(BuildContext context, List<String> artists) {
    if (artists.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text("Your Top Artists", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: context.themeTextColor, letterSpacing: -0.5)),
          ),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: artists.length,
              itemBuilder: (context, index) {
                final artist = artists[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: TVFocusableCard(
                    onTap: () {
                      // We can implement Search filter for Artist here in future
                    },
                    child: SizedBox(
                      width: 90,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.primaries[artist.hashCode % Colors.primaries.length].withValues(alpha: 0.8),
                                  Colors.primaries[(artist.hashCode + 1) % Colors.primaries.length].withValues(alpha: 0.8)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                )
                              ],
                            ),
                            child: Center(
                              child: Text(
                                artist.substring(0, 1).toUpperCase(),
                                style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.themeTextColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildArtistGridCarousel(BuildContext context, String title, List<String> artists) {
    if (artists.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(title, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: context.themeTextColor, letterSpacing: -0.5)),
          ),
          SizedBox(
            height: 180,
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.35,
              ),
              itemCount: artists.length,
              itemBuilder: (context, index) {
                final artist = artists[index];
                return TVFocusableCard(
                  onTap: () {},
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.themeCardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.primaries[artist.hashCode % Colors.primaries.length].withValues(alpha: 0.8),
                                Colors.primaries[(artist.hashCode + 1) % Colors.primaries.length].withValues(alpha: 0.8)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(Icons.person, color: Colors.white54, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            artist,
                            style: GoogleFonts.inter(color: context.themeTextColor, fontSize: 14, fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistCarousel(BuildContext context, String title, List<Playlist> playlists) {
    if (playlists.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 600;
    final cardWidth = isWide ? 160.0 : 130.0;
    final carouselHeight = isWide ? 210.0 : 175.0;

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
            height: carouselHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final pl = playlists[index];
                
                // Clean up Daily Mix prefixes for a cleaner layout
                String displayTitle = pl.title;
                if (displayTitle.startsWith("Daily Mix: ")) {
                  displayTitle = "${displayTitle.replaceFirst("Daily Mix: ", "")} Mix";
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: TVFocusableCard(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlaylistDetailScreen(playlist: pl))),
                    child: SizedBox(
                      width: cardWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: 1.0,
                            child: pl.coverArt.isNotEmpty
                                ? CustomImageWidget(imageUrl: pl.coverArt, fit: BoxFit.cover, size: 150)
                                : Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [AppColors.midnightAccent, AppColors.midnightPill],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: const Icon(Icons.music_note, color: Colors.white54, size: 40),
                                  ),
                          ),
                        ),
                        if (title != "Curated Moods") ...[
                          const SizedBox(height: 8),
                          Text(
                            displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: context.themeTextColor, 
                              fontSize: isWide ? 13 : 12, 
                              fontWeight: FontWeight.w600,
                            ),
                            ),
                          ], // closes if statement
                        ], // closes children
                      ), // closes Column
                    ), // closes SizedBox
                  ), // closes TVFocusableCard
                ); // closes return Padding
              },
            ), // ListView
          ), // SizedBox
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
                TVFocusableCard(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SeeAllSongsScreen(title: title, songs: songs))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Text("See All", style: GoogleFonts.inter(color: AppColors.midnightAccent, fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
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
              
              // In a horizontal GridView:
              // crossAxis is vertical (height), mainAxis is horizontal (width).
              // We want each item to be wide enough to take up most of the screen on mobile, 
              // but constrained to a reasonable max width on tablets so they don't stretch into strips.
              final itemWidth = isWide ? 260.0 : (screenWidth * 0.85);
              
              // Calculate effective row height
              // crossAxisSpacing is the vertical spacing between rows (12.0)
              final rowHeight = (carouselHeight - (crossAxisCount - 1) * 12.0) / crossAxisCount;
              final aspectRatio = rowHeight / itemWidth;
              
              return SizedBox(
                height: carouselHeight,
                child: GridView.builder(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: aspectRatio,
                    mainAxisSpacing: 16, // Horizontal spacing between items
                    crossAxisSpacing: 12, // Vertical spacing between rows
                  ),
              itemCount: songs.length > 15 ? 15 : songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return TVFocusableCard(
                  onTap: () => ref.read(audioPlayerProvider.notifier).playSong(song, queue: songs, index: index),
                  onLongPress: () => SongOptionsSheet.show(context, song, playlistContext: songs),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 56, height: 56,
                          child: song.coverArt.isNotEmpty
                              ? CustomImageWidget(imageUrl: song.coverArt, fit: BoxFit.cover, size: 150)
                              : Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [AppColors.midnightAccent, AppColors.midnightPill],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: const Icon(Icons.music_note, color: Colors.white54, size: 24),
                                ),
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
        final hour = DateTime.now().hour;
        Color topGradientColor;
        if (hour < 12) topGradientColor = const Color(0xFFFFC107).withValues(alpha: 0.15); // Morning Gold
        else if (hour < 17) topGradientColor = const Color(0xFF4CAF50).withValues(alpha: 0.10); // Afternoon Teal/Green
        else topGradientColor = const Color(0xFF3F51B5).withValues(alpha: 0.15); // Evening Indigo

        return Scaffold(
          backgroundColor: context.themeBackgroundColor,
          body: Stack(
            children: [
              // Dynamic Background Mesh Blob
              Positioned(
                top: -150,
                left: -50,
                right: -50,
                height: 400,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: topGradientColor,
                    ),
                  ),
                ),
                ),
              ),
              SafeArea(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification scrollInfo) {
                    if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 500) {
                      ref.read(homeProvider.notifier).loadMoreFeed();
                    }
                    return false;
                  },
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
                            TVFocusableCard(
                              focusedScale: 1.1,
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
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _filters.length,
                      itemBuilder: (context, index) {
                        final isSelected = index == _selectedFilterIndex;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: TVFocusableCard(
                            autofocus: index == 0,
                            focusedScale: 1.1,
                            onTap: () {
                              setState(() => _selectedFilterIndex = index);
                              ref.read(homeProvider.notifier).selectCategory(_filters[index]);
                              if (_filters[index] == "For You" && homeProv.currentCategoryPlaylists.isEmpty) {
                                ref.read(homeProvider.notifier).fetchYouSongs(historyProvider.getTopArtists());
                                if (homeProv.moodPlaylists.isEmpty) ref.read(homeProvider.notifier).fetchMoods();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  _filters[index],
                  style: GoogleFonts.inter(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Mobile/Tablet Hero Banner (Apple Music style)
                if (activeSongs.isNotEmpty && selectedCat != "Charts" && !homeProv.isLoading)
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
                    // Top Artists Section (Derived from history, fallback to trending)
                    Builder(
                      builder: (context) {
                        List<String> artists = historyProvider.getTopArtists(limit: 8);
                        if (artists.isEmpty) {
                          artists = homeProv.trendingSongs.map((e) => e.artist).where((a) => a.isNotEmpty).toSet().take(8).toList();
                        }
                        if (artists.isNotEmpty) {
                          return _buildTopArtistsCarousel(context, artists);
                        }
                        return const SliverToBoxAdapter(child: SizedBox.shrink());
                      },
                    ),
                      
                    // Spotify style 2x3 grid (Jump Back In or Quick Picks)
                    Builder(
                      builder: (context) {
                        final gridSongs = activeSongs.length > 1 ? activeSongs.take(6).toList() : homeProv.trendingSongs.take(6).toList();
                        final gridTitle = activeSongs.length > 1 ? "Jump Back In" : "Trending Picks";
                        if (gridSongs.length > 1) {
                          return SliverMainAxisGroup(
                            slivers: [
                              const SliverToBoxAdapter(child: SizedBox(height: 16)),
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                  child: Text(gridTitle, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: context.themeTextColor, letterSpacing: -0.5)),
                                ),
                              ),
                              _buildSpotifyRecentGrid(context, gridSongs, playerProvider),
                            ],
                          );
                        }
                        return const SliverToBoxAdapter(child: SizedBox.shrink());
                      },
                    ),
                    
                    const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(bottom: 16, top: 16), child: SmartRecommendationsRow())),
                    _buildPlaylistCarousel(context, "Daily Mixes", homeProv.youPlaylists),
                    _buildPlaylistCarousel(context, "Curated Moods", homeProv.moodPlaylists),
                    
                    // Moved Continue Watching to bottom and renamed logic
                    if (homeProv.continueWatching.isNotEmpty)
                      _buildSongCarousel(context, "Video History", homeProv.continueWatching, playerProvider),
                  ]
                ] 
                else if (selectedCat == "Music") ...[
                    if (activeSongs.length > 1 || homeProv.trendingSongs.isNotEmpty) ...[
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          child: Text("Quick Picks", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: context.themeTextColor, letterSpacing: -0.5)),
                        ),
                      ),
                      _buildSpotifyRecentGrid(context, activeSongs.length > 1 ? activeSongs : homeProv.trendingSongs.take(6).toList(), playerProvider),
                    ],
                    // Render Horizontal Swipeable Song Grid Carousels for Genres
                    _buildSongCarousel(context, "Trending Now", homeProv.trendingSongs, playerProvider),
                    _buildPlaylistCarousel(context, "Top Albums", homeProv.topAlbums),
                    _buildSongCarousel(context, "Bollywood Hits", homeProv.bollywoodSongs, playerProvider),
                    _buildSongCarousel(context, "Punjabi Hits", homeProv.punjabiSongs, playerProvider),
                    _buildSongCarousel(context, "Telugu Hits", homeProv.teluguSongs, playerProvider),
                    _buildSongCarousel(context, "Tamil Hits", homeProv.tamilSongs, playerProvider),
                    _buildSongCarousel(context, "Hollywood Pop", homeProv.hollywoodSongs, playerProvider),
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
                
                // Infinite Dynamic Feeds
                if (homeProv.dynamicFeeds[selectedCat] != null) ...[
                  for (var shelf in homeProv.dynamicFeeds[selectedCat]!)
                    _buildDynamicShelf(context, shelf, playerProvider),
                ],
                
                // Loading indicator for infinite feed
                if (homeProv.isLoadingFeed[selectedCat] == true)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator(color: AppColors.midnightAccent)),
                    ),
                  ),

                SliverToBoxAdapter(child: SizedBox(height: AppDimensions.bottomClearance + MediaQuery.of(context).viewPadding.bottom)),
              ],
            ),
                  ),
          ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDynamicShelf(BuildContext context, FeedShelf shelf, AudioPlayerNotifier playerProvider) {
    if (shelf.type == ShelfType.artistGrid) {
      return _buildArtistGridCarousel(context, shelf.title, shelf.items.cast<String>());
    } else if (shelf.type == ShelfType.songCarousel) {
      return _buildSongCarousel(context, shelf.title, shelf.items.cast<Song>(), playerProvider);
    } else if (shelf.type == ShelfType.playlistCarousel) {
      return _buildPlaylistCarousel(context, shelf.title, shelf.items.cast<Playlist>());
    }
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }
}
