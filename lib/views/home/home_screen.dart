import 'package:pixel_player_saavn/views/widgets/custom_image_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/hidden_songs_provider.dart';
import '../../providers/listening_history_provider.dart';
import '../../data/models/song_model.dart';
import '../details/playlist_detail_screen.dart';
import '../details/see_all_screen.dart';
import '../settings/settings_screen.dart';
import '../widgets/song_options_sheet.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback openFullPlayer;

  const HomeScreen({super.key, required this.openFullPlayer});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedFilterIndex = 0;
  final PageController _swipePageController = PageController(viewportFraction: 0.88);
  final List<String> _filters = [
    "YOU",
    "Moods",
    "Charts",
    "Bollywood",
    "Telugu",
    "Tamil",
    "Punjabi",
    "Hollywood",
    "Trending",
    "Playlists",
    "Albums",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      final historyProvider = Provider.of<ListeningHistoryProvider>(context, listen: false);
      
      // Sync selected index with provider's default
      final idx = _filters.indexOf(homeProvider.selectedCategory);
      if (idx != -1 && mounted) {
        setState(() {
          _selectedFilterIndex = idx;
        });
      }

      if (homeProvider.selectedCategory == "YOU" && homeProvider.currentCategoryPlaylists.isEmpty) {
        homeProvider.fetchYouSongs(historyProvider.getTopArtists());
      } else if (homeProvider.selectedCategory == "Moods") {
        homeProvider.fetchMoods();
      } else if (homeProvider.selectedCategory == "Charts") {
        homeProvider.fetchCharts();
      } else if (["Bollywood", "Telugu", "Tamil", "Punjabi", "Hollywood", "Albums"].contains(homeProvider.selectedCategory)) {
        homeProvider.selectCategory(homeProvider.selectedCategory);
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

  @override
  Widget build(BuildContext context) {
    return Consumer4<HomeProvider, AudioPlayerProvider, HiddenSongsProvider, ListeningHistoryProvider>(
      builder: (context, homeProvider, playerProvider, hiddenProvider, historyProvider, child) {
        final selectedCat = _filters[_selectedFilterIndex];
        
        List<Song> activeSongs = homeProvider.currentCategorySongs.where((s) => !hiddenProvider.isHidden(s.id)).toList();
        if (selectedCat == "YOU") {
          activeSongs = historyProvider.recentlyPlayed.where((s) => !hiddenProvider.isHidden(s.id)).toList();
        }
        
        final activePlaylists = homeProvider.currentCategoryPlaylists;

        return Scaffold(
          backgroundColor: AppColors.midnightBackground,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                // Top App Bar Branding ("It Feels")
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.midnightTextMuted,
                              ),
                            ),
                            Text(
                              "It Feels",
                              style: GoogleFonts.outfit(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),

                        IconButton(
                          icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 22),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SettingsScreen()),
                            );
                          },
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
                            setState(() {
                              _selectedFilterIndex = index;
                            });
                            homeProvider.selectCategory(_filters[index]);
                            if (_filters[index] == "YOU" && homeProvider.currentCategoryPlaylists.isEmpty) {
                              homeProvider.fetchYouSongs(historyProvider.getTopArtists());
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: isSelected
                                  ? null
                                  : AppColors.midnightPill.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? Colors.transparent : Colors.white10,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              _filters[index],
                              style: GoogleFonts.inter(
                                color: isSelected ? Colors.black : Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Moods Language Toggle
                if (selectedCat == "Moods")
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Curated Moods",
                            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          GestureDetector(
                            onTap: () => homeProvider.toggleMoodLanguage(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.midnightPill,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.midnightPrimary.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.language, size: 16, color: AppColors.midnightPrimary),
                                  const SizedBox(width: 6),
                                  Text(
                                    homeProvider.moodLanguage,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (selectedCat == "Moods" && homeProvider.isLoadingMoods)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator(color: AppColors.midnightAccent)),
                    ),
                  ),
                if (selectedCat == "Charts" && homeProvider.isLoadingCharts)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator(color: AppColors.midnightAccent)),
                    ),
                  ),
                  
                // Empty State for YOU Section
                if (selectedCat == "YOU" && activeSongs.isEmpty && activePlaylists.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.headphones_rounded, size: 64, color: AppColors.midnightTextMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text(
                            "Your Music, Your Rules",
                            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Listen to more songs to unlock your personalized Daily Mixes and history.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.midnightTextMuted),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // Interactive Swipeable Song Cards Carousel System
                  if (selectedCat != "Playlists" && selectedCat != "Albums" && activeSongs.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 190,
                      child: PageView.builder(
                        controller: _swipePageController,
                        itemCount: activeSongs.length > 8 ? 8 : activeSongs.length,
                        itemBuilder: (context, index) {
                          final song = activeSongs[index];
                          final isCurrent = playerProvider.currentSong?.id == song.id;

                          return Container(
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.midnightCard,
                                  AppColors.midnightPill.withValues(alpha: 0.9),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isCurrent ? AppColors.midnightAccent : Colors.white10,
                                width: isCurrent ? 1.5 : 0.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Album Artwork
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: SizedBox(
                                      width: 135,
                                      height: 135,
                                      child: song.coverArt.isNotEmpty
                                          ? CustomImageWidget(
                                              imageUrl: song.coverArt,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(color: AppColors.midnightPill),
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Song Title, Artist, & Play Controls
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "SWIPE TO EXPLORE",
                                          style: GoogleFonts.inter(
                                            color: AppColors.midnightAccent,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          song.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          song.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            color: AppColors.midnightTextMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 12),

                                        Row(
                                          children: [
                                            // Play Button
                                            GestureDetector(
                                              onTap: () {
                                                playerProvider.playSong(song, queue: activeSongs, index: index);
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isCurrent && playerProvider.isPlaying
                                                          ? Icons.pause_rounded
                                                          : Icons.play_arrow_rounded,
                                                      color: Colors.black,
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      isCurrent && playerProvider.isPlaying ? "Pause" : "Play",
                                                      style: GoogleFonts.inter(
                                                        color: Colors.black,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 20),
                                              onPressed: () {
                                                SongOptionsSheet.show(context, song, playlistContext: activeSongs);
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
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

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // Playlists / Albums Grid View
                if (selectedCat == "Playlists" || selectedCat == "Albums") ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedCat == "Albums" ? "Top Movie & Studio Albums" : "Featured Playlists & Charts",
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            "${activePlaylists.length} Collections",
                            style: GoogleFonts.inter(color: AppColors.midnightTextMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 14)),
                  if (activePlaylists.isEmpty && homeProvider.isLoading)
                    const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(color: AppColors.midnightAccent),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.82,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final pl = activePlaylists[index];
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
                                decoration: BoxDecoration(
                                  color: AppColors.midnightCard.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: pl.coverArt.isNotEmpty
                                              ? CustomImageWidget(
                                                  imageUrl: pl.coverArt,
                                                  fit: BoxFit.cover,
                                                )
                                              : Container(color: AppColors.midnightPill),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pl.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "${pl.songCount > 0 ? '${pl.songCount} Songs â€¢ ' : ''}${pl.type == 'album' ? 'Album' : 'Playlist'}",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              color: AppColors.midnightTextMuted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: activePlaylists.length,
                        ),
                      ),
                    ),
                ] else ...[
                  // Song Section Header with "See All" Button
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedCat == "YOU" ? "Recently Played" : "$selectedCat Hits",
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),

                          // "See All" Action Button
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SeeAllSongsScreen(
                                    title: selectedCat == "YOU" ? "Recently Played" : "$selectedCat Hits",
                                    songs: activeSongs,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.midnightPill,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    "See All",
                                    style: GoogleFonts.inter(
                                      color: AppColors.midnightAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.midnightAccent, size: 10),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  if (homeProvider.isLoading && activeSongs.isEmpty)
                    const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(color: AppColors.midnightAccent),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = activeSongs[index];
                          final isCurrentlyPlaying = playerProvider.currentSong?.id == song.id;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isCurrentlyPlaying
                                    ? AppColors.midnightCard.withValues(alpha: 0.9)
                                    : AppColors.midnightCard.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 0.5),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: song.coverArt.isNotEmpty
                                        ? CustomImageWidget(
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
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  "${song.artist} â€¢ ${song.album.isNotEmpty ? song.album : 'Single'}",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: AppColors.midnightTextMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                                  onPressed: () {
                                    SongOptionsSheet.show(context, song, playlistContext: activeSongs);
                                  },
                                ),
                                onTap: () {
                                  playerProvider.playSong(song, queue: activeSongs, index: index);
                                },
                                onLongPress: () {
                                  SongOptionsSheet.show(context, song, playlistContext: activeSongs);
                                },
                              ),
                            ),
                          ),
                        );},
                        childCount: activeSongs.length > 6 ? 6 : activeSongs.length,
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Playlists Section with See All / View Details
                  if (activePlaylists.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          selectedCat == "YOU" ? "Daily Mixes" : "$selectedCat Playlists",
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 180,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: activePlaylists.length,
                          itemBuilder: (context, index) {
                            final pl = activePlaylists[index];
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
                                            ? CustomImageWidget(
                                                imageUrl: pl.coverArt,
                                                fit: BoxFit.cover,
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
                ],
                ], // Close the outer else ...[ for YOU empty state

                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ),
          ),
        );
      },
    );
  }
}
