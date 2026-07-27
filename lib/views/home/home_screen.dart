import 'package:it_feels_music/views/widgets/custom_image_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/hidden_songs_provider.dart';
import '../../providers/listening_history_provider.dart';
import '../../providers/ai_settings_provider.dart';
import '../../data/models/song_model.dart';
import '../details/playlist_detail_screen.dart';
import '../details/see_all_screen.dart';
import '../settings/settings_screen.dart';
import '../ai/ask_ai_screen.dart';
import '../widgets/song_options_sheet.dart';
import 'smart_recommendations_row.dart';

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
    "For You",
    "Music",
    "Podcasts",
    "Charts",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      final historyProvider = Provider.of<ListeningHistoryProvider>(context, listen: false);
      
      final idx = _filters.indexOf(homeProvider.selectedCategory);
      if (idx != -1 && mounted) {
        setState(() {
          _selectedFilterIndex = idx;
        });
      }

      if (homeProvider.selectedCategory == "For You" && homeProvider.currentCategoryPlaylists.isEmpty) {
        homeProvider.fetchYouSongs(historyProvider.getTopArtists());
        if (homeProvider.moodPlaylists.isEmpty) homeProvider.fetchMoods();
      } else if (homeProvider.selectedCategory == "Charts") {
        homeProvider.fetchCharts();
      } else if (homeProvider.selectedCategory == "Music") {
        homeProvider.selectCategory("Music");
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
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
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
                                : Container(color: AppColors.midnightCard),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          pl.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
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

  Widget _buildSongCarousel(BuildContext context, String title, List<Song> songs, AudioPlayerProvider playerProvider) {
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
                Text(title, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SeeAllSongsScreen(title: title, songs: songs))),
                  child: Text("See All", style: GoogleFonts.inter(color: AppColors.midnightAccent, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 220, // 3 rows of songs
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.25,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
              ),
              itemCount: songs.length > 15 ? 15 : songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return GestureDetector(
                  onTap: () => playerProvider.playSong(song, queue: songs, index: index),
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
                            Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: AppColors.midnightTextMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 20),
                        onPressed: () => SongOptionsSheet.show(context, song, playlistContext: songs),
                      )
                    ],
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

  @override
  Widget build(BuildContext context) {
    return Consumer4<HomeProvider, AudioPlayerProvider, HiddenSongsProvider, ListeningHistoryProvider>(
      builder: (context, homeProvider, playerProvider, hiddenProvider, historyProvider, child) {
        final selectedCat = _filters[_selectedFilterIndex];
        
        List<Song> activeSongs = homeProvider.currentCategorySongs.where((s) => !hiddenProvider.isHidden(s.id)).toList();
        if (selectedCat == "For You") {
          activeSongs = historyProvider.recentlyPlayed.where((s) => !hiddenProvider.isHidden(s.id)).toList();
        }
        
        return Scaffold(
          backgroundColor: AppColors.midnightBackground,
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
                            Text(_getGreeting(), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.midnightTextMuted)),
                            Text("It Feels", style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (context.watch<AISettingsProvider>().isConfigured)
                              IconButton(
                                icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AskAIScreen())),
                                tooltip: 'Ask Feels',
                              ),
                            IconButton(
                              icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 22),
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
                            homeProvider.selectCategory(_filters[index]);
                            if (_filters[index] == "For You" && homeProvider.currentCategoryPlaylists.isEmpty) {
                              homeProvider.fetchYouSongs(historyProvider.getTopArtists());
                              if (homeProvider.moodPlaylists.isEmpty) homeProvider.fetchMoods();
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFF9C27B0)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                                  : null,
                              color: isSelected ? null : AppColors.midnightPill.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? Colors.transparent : Colors.white10, width: 0.5),
                            ),
                            child: Text(
                              _filters[index],
                              style: GoogleFonts.inter(color: isSelected ? Colors.black : Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                if (homeProvider.isLoading && activeSongs.isEmpty && selectedCat != "For You")
                  const SliverToBoxAdapter(
                    child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: AppColors.midnightAccent))),
                  ),

                if (selectedCat == "For You") ...[
                  if (activeSongs.isEmpty && homeProvider.youPlaylists.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.headphones_rounded, size: 64, color: AppColors.midnightTextMuted.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            Text("Your Music, Your Rules", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                            const SizedBox(height: 8),
                            Text("Listen to more songs to unlock your personalized Daily Mixes and history.", textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: AppColors.midnightTextMuted)),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(bottom: 24), child: SmartRecommendationsRow())),
                    _buildPlaylistCarousel(context, "Curated Moods", homeProvider.moodPlaylists),
                    _buildPlaylistCarousel(context, "Daily Mixes", homeProvider.youPlaylists),
                    _buildSongCarousel(context, "Recently Played", activeSongs, playerProvider),
                  ]
                ] 
                else if (selectedCat == "Music") ...[
                  // Render Horizontal Swipeable Song Grid Carousels for Genres
                  _buildSongCarousel(context, "Trending Now", homeProvider.trendingSongs, playerProvider),
                  _buildSongCarousel(context, "Bollywood Hits", homeProvider.bollywoodSongs, playerProvider),
                  _buildSongCarousel(context, "Punjabi Hits", homeProvider.punjabiSongs, playerProvider),
                  _buildSongCarousel(context, "Telugu Hits", homeProvider.teluguSongs, playerProvider),
                  _buildSongCarousel(context, "Tamil Hits", homeProvider.tamilSongs, playerProvider),
                  _buildSongCarousel(context, "Hollywood Pop", homeProvider.hollywoodSongs, playerProvider),
                  _buildPlaylistCarousel(context, "Top Albums", homeProvider.topAlbums),
                ]
                else if (selectedCat == "Podcasts") ...[
                  _buildPlaylistCarousel(context, "Top Podcasts", homeProvider.podcastPlaylists),
                  _buildSongCarousel(context, "Latest Episodes", activeSongs, playerProvider),
                ]
                else if (selectedCat == "Charts") ...[
                  _buildPlaylistCarousel(context, "Global Charts", homeProvider.chartPlaylists),
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
