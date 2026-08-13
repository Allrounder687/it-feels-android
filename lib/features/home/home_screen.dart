import 'dart:io';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/widgets/horizontal_scroll_wrapper.dart';
import 'package:it_feels_music/core/theme/app_typography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/features/library/listening_history_provider.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/library/playlist_detail_screen.dart';
import 'package:it_feels_music/features/library/see_all_screen.dart';
import 'package:it_feels_music/data/models/feed_shelf.dart';
import 'package:it_feels_music/features/settings/settings_screen.dart';
import 'package:it_feels_music/features/settings/profile_screen.dart';
import 'package:it_feels_music/features/ai/ask_ai_screen.dart';
import 'package:it_feels_music/core/widgets/song_options_sheet.dart';
import 'package:it_feels_music/features/home/smart_recommendations_row.dart';
import 'package:it_feels_music/features/social/room_bottom_sheet.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/widgets/tv_focusable_card.dart';
import 'package:it_feels_music/core/theme/app_dimensions.dart';
import 'package:it_feels_music/features/radio/radio_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:shimmer/shimmer.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback openFullPlayer;

  const HomeScreen({super.key, required this.openFullPlayer});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedFilterIndex = 0;
  final PageController _swipePageController = PageController(
    viewportFraction: 0.88,
  );
  final List<String> _filters = ["For You", "Music", "Podcasts", "Charts"];

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

      if (homeProv.selectedCategory == "For You" &&
          homeProv.currentCategoryPlaylists.isEmpty) {
        ref
            .read(homeProvider.notifier)
            .fetchYouSongs(historyProvider.getTopArtists());
        if (homeProv.moodPlaylists.isEmpty) {
          ref.read(homeProvider.notifier).fetchMoods();
        }
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

  Widget _buildHeroBanner(
    BuildContext context,
    List<Song> heroSongs,
    AudioPlayerState player,
  ) {
    if (heroSongs.isEmpty) return const SizedBox.shrink();

    // Use up to 5 songs for the hero carousel
    final carouselSongs = heroSongs.take(5).toList();
    
    // Determine card dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    // clamp(350px, 30vw, 600px) translates to:
    final double cardWidth = (screenWidth * 0.32).clamp(300.0, 420.0);
    // 16:9 Aspect Ratio
    final double cardHeight = cardWidth * (9 / 16);

    return SizedBox(
      height: cardHeight + 40, // accommodate padding
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32),
          itemCount: carouselSongs.length,
          itemBuilder: (context, index) {
            final heroSong = carouselSongs[index];

            return Padding(
              padding: const EdgeInsets.only(right: 24.0, top: 16.0, bottom: 16.0),
              child: SizedBox(
                width: cardWidth,
                child: TVFocusableCard(
                  onTap: () => ref
                      .read(audioPlayerProvider.notifier)
                      .playSong(heroSong, queue: carouselSongs, index: index),
                  focusedScale: 1.02,
                  borderRadius: 12.0,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Background Image
                          heroSong.coverArt.isNotEmpty
                              ? CustomImageWidget(
                                  imageUrl: heroSong.coverArt,
                                  fit: BoxFit.cover,
                                )
                              : Container(color: context.themeSurfaceColor),
                          
                          // Gradient Overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.3),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.8),
                                ],
                                stops: const [0.0, 0.4, 1.0],
                              ),
                            ),
                          ),
                          
                          // Content
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Top Tag
                                Text(
                                  "NEW RELEASE",
                                  style: GoogleFonts.inter(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                    fontSize: 12,
                                    shadows: const [
                                      Shadow(offset: Offset(0, 2), blurRadius: 6.0, color: Color(0xD9000000)),
                                    ],
                                  ),
                                ),
                                
                                // Bottom Metadata
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      heroSong.title,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        shadows: const [
                                          Shadow(offset: Offset(0, 2), blurRadius: 6.0, color: Color(0xD9000000)),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      heroSong.artist,
                                      style: GoogleFonts.inter(
                                        color: Colors.white70,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        shadows: const [
                                          Shadow(offset: Offset(0, 2), blurRadius: 6.0, color: Color(0xD9000000)),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompactTrackGrid(
    BuildContext context,
    List<Song> songs,
    AudioPlayerState playerProvider, {
    String? title,
  }) {
    if (songs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    final screenWidth = MediaQuery.of(context).size.width;
    // Calculate how many columns we can fit: 1 on small screens, 2 on medium, 3 on large
    int crossAxisCount = 1;
    if (screenWidth >= 1000) {
      crossAxisCount = 3;
    } else if (screenWidth >= 600) {
      crossAxisCount = 2;
    }

    final gridSongs = songs;

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, top: 48, bottom: 16),
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800, // Premium bold
                  color: context.themeTextColor,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 32),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 350,
              mainAxisExtent: 64,
              crossAxisSpacing: 16,
              mainAxisSpacing: 12,
            ),
            itemCount: gridSongs.length,
            itemBuilder: (context, index) {
              final song = gridSongs[index];

              return TVFocusableCard(
                onTap: () => ref
                    .read(audioPlayerProvider.notifier)
                    .playSong(song, queue: gridSongs, index: index),
                onLongPress: () => SongOptionsSheet.show(
                  context,
                  song,
                  playlistContext: gridSongs,
                ),
                focusedScale: 1.02,
                borderRadius: 6.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: song.coverArt.isNotEmpty
                              ? CustomImageWidget(
                                  imageUrl: song.coverArt,
                                  fit: BoxFit.cover,
                                  size: 150,
                                )
                              : Container(color: context.themeSurfaceColor),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: context.themeTextColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: context.themeMutedTextColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.more_horiz_rounded,
                        color: context.themeMutedTextColor,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTopArtistsCarousel(
    BuildContext context,
    List<String> artists,
    ListeningHistoryState history,
    List<Song> fallbackSongs,
  ) {
    if (artists.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final Set<String> usedImages = {};

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              "Your Top Artists",
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: context.themeTextColor,
                letterSpacing: -0.5,
              ),
            ),
          ),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: artists.length,
              itemBuilder: (context, index) {
                final artist = artists[index];

                String artistImage = '';

                // 1. Try to find a song where they are the PRIMARY artist
                for (var s in [...history.recentlyPlayed, ...fallbackSongs]) {
                  if (s.artist.split(',').first.trim() == artist &&
                      s.coverArt.isNotEmpty) {
                    if (!usedImages.contains(s.coverArt)) {
                      artistImage = s.coverArt;
                      usedImages.add(s.coverArt);
                      break;
                    }
                  }
                }

                // 2. If not found, try to find ANY song they are in, but ensure it's a unique image
                if (artistImage.isEmpty) {
                  for (var s in [...history.recentlyPlayed, ...fallbackSongs]) {
                    if (s.artist.contains(artist) && s.coverArt.isNotEmpty) {
                      if (!usedImages.contains(s.coverArt)) {
                        artistImage = s.coverArt;
                        usedImages.add(s.coverArt);
                        break;
                      }
                    }
                  }
                }

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
                              image: artistImage.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(artistImage),
                                      fit: BoxFit.cover,
                                    )
                                  : const DecorationImage(
                                      image: AssetImage(
                                        'assets/images/placeholder.jpg',
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.themeTextColor,
                            ),
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

  Widget _buildArtistGridCarousel(
    BuildContext context,
    String title,
    List<dynamic> artists,
  ) {
    if (artists.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: context.themeTextColor,
                letterSpacing: -0.5,
              ),
            ),
          ),
          SizedBox(
            height: 180,
            child: HorizontalScrollWrapper(
              builder: (context, scrollController) {
                return GridView.builder(
                  controller: scrollController,
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
                    final String artistName = artist is Map
                        ? (artist['title'] ?? '')
                        : artist.toString();
                    final String? artistImage = artist is Map
                        ? artist['image']
                        : null;

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
                                image: artistImage != null && artistImage.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(artistImage),
                                        fit: BoxFit.cover,
                                      )
                                    : const DecorationImage(
                                        image: AssetImage(
                                          'assets/images/placeholder.jpg',
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                artistName,
                                style: GoogleFonts.inter(
                                  color: context.themeTextColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistCarousel(
    BuildContext context,
    String title,
    List<Playlist> playlists,
  ) {
    if (playlists.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 600;
    
    // clamp(150px, 15vw, 250px) translates to:
    final double cardWidth = (screenWidth * 0.15).clamp(150.0, 250.0);
    final carouselHeight = cardWidth + 50.0; // accommodate title

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 40, bottom: 12),
            child: Text(
              title,
              style: AppTypography.outfitExtraBold.copyWith(
                fontSize: 22,
                color: context.themeTextColor,
                letterSpacing: -0.5,
              ),
            ),
          ),
          SizedBox(
            height: carouselHeight,
            child: HorizontalScrollWrapper(
              builder: (context, scrollController) {
                return ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: ListView.builder(
                    controller: scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    clipBehavior: Clip.none,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final pl = playlists[index];

                  String displayTitle = pl.title;
                  if (displayTitle.startsWith("Daily Mix: ")) {
                    displayTitle = "${displayTitle.replaceFirst("Daily Mix: ", "")} Mix";
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: TVFocusableCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlaylistDetailScreen(playlist: pl),
                        ),
                      ),
                      focusedScale: 1.02,
                      borderRadius: 8.0,
                      child: SizedBox(
                        width: cardWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF121212),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: AspectRatio(
                                  aspectRatio: 1.0,
                                child: pl.coverArt.isNotEmpty
                                    ? CustomImageWidget(
                                        imageUrl: pl.coverArt,
                                        fit: BoxFit.cover,
                                        size: 200,
                                      )
                                    : Container(
                                        color: const Color(0xFF121212),
                                        child: const Icon(
                                          Icons.music_note,
                                          color: Colors.white54,
                                          size: 40,
                                        ),
                                      ),
                                ),
                              ),
                            ),
                            if (title != "Curated Moods") ...[
                              const SizedBox(height: 8),
                              Text(
                                displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.interSemiBold.copyWith(
                                  color: context.themeTextColor,
                                  fontSize: isWide ? 13 : 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildJumpBackInCarousel(
    BuildContext context,
    List<Song> history,
    AudioPlayerState playerProvider,
  ) {
    if (history.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 32, top: 48, bottom: 16),
            child: Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  color: context.themeAccentColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  "Jump Back In",
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: context.themeTextColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 190,
            child: HorizontalScrollWrapper(
              builder: (context, scrollController) {
                return ListView.builder(
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final song = history[index];
                    final isPlaying =
                        playerProvider.currentSong?.id == song.id &&
                        playerProvider.isPlaying;

                    return Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: TVFocusableCard(
                        onTap: () {
                          if (playerProvider.currentSong?.id != song.id) {
                            ref
                                .read(audioPlayerProvider.notifier)
                                .playSong(song, queue: history, index: index);
                          } else {
                            ref
                                .read(audioPlayerProvider.notifier)
                                .togglePlayPause();
                          }
                        },
                        child: SizedBox(
                          width: 140,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: CustomImageWidget(
                                      imageUrl: song.coverArt ?? '',
                                      width: 140,
                                      height: 140,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        color: Colors.black.withValues(alpha: 0.3),
                                      ),
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: context.themeAccentColor
                                                .withValues(alpha: 0.9),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isPlaying
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            color: context.themeInvertedTextColor,
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.interSemiBold.copyWith(
                                  color: context.themeTextColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSongCarousel(
    BuildContext context,
    String title,
    List<Song> songs,
    AudioPlayerState playerProvider,
  ) {
    if (songs.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 40, bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: context.themeTextColor,
                  ),
                ),
                TVFocusableCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SeeAllSongsScreen(title: title, songs: songs),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    child: Text(
                      "See All",
                      style: GoogleFonts.inter(
                        color: AppColors.midnightAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isWide = screenWidth >= 600;
              final crossAxisCount = isWide ? 2 : 3;
              final carouselHeight = isWide ? 150.0 : 220.0;

              // We want each item to be wide enough to take up most of the screen on mobile,
              // but constrained to a reasonable max width on tablets so they don't stretch into strips.
              return SizedBox(
                height: carouselHeight,
                child: HorizontalScrollWrapper(
                  builder: (context, scrollController) {
                    return GridView.builder(
                      controller: scrollController,
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisExtent: 350, // Constrain item width to 350px
                    mainAxisSpacing: 16, // Horizontal spacing between items
                    crossAxisSpacing: 12, // Vertical spacing between rows
                  ),
                  itemCount: songs.length > 15 ? 15 : songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return TVFocusableCard(
                      onTap: () => ref
                          .read(audioPlayerProvider.notifier)
                          .playSong(song, queue: songs, index: index),
                      onLongPress: () => SongOptionsSheet.show(
                        context,
                        song,
                        playlistContext: songs,
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: song.coverArt.isNotEmpty
                                  ? CustomImageWidget(
                                      imageUrl: song.coverArt,
                                      fit: BoxFit.cover,
                                      size: 150,
                                    )
                                  : Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.midnightAccent,
                                            AppColors.midnightPill,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.music_note,
                                        color: Colors.white54,
                                        size: 24,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: context.themeTextColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: context.themeMutedTextColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.more_vert_rounded,
                              color: context.themeMutedTextColor,
                              size: 20,
                            ),
                            onPressed: () => SongOptionsSheet.show(
                              context,
                              song,
                              playlistContext: songs,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ); // ends GridView.builder
              }), // ends HorizontalScrollWrapper builder
            ); // ends return SizedBox
          }, // ends LayoutBuilder builder
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

        List<Song> activeSongs = homeProv.currentCategorySongs
            .where((s) => !hiddenProvider.isHidden(s.id))
            .toList();
        if (selectedCat == "For You") {
          activeSongs = historyProvider.recentlyPlayed
              .where((s) => !hiddenProvider.isHidden(s.id))
              .toList();
        }
        final hour = DateTime.now().hour;
        Color topGradientColor;
        if (hour < 12) {
          topGradientColor = const Color(
            0xFFFFC107,
          ).withValues(alpha: 0.15); // Morning Gold
        } else if (hour < 17)
          topGradientColor = const Color(
            0xFF4CAF50,
          ).withValues(alpha: 0.10); // Afternoon Teal/Green
        else
          topGradientColor = const Color(
            0xFF3F51B5,
          ).withValues(alpha: 0.15); // Evening Indigo

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
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        topGradientColor,
                        topGradientColor.withValues(alpha: 0.0),
                      ],
                      stops: const [0.2, 1.0],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification scrollInfo) {
                    if (scrollInfo.metrics.axis == Axis.vertical &&
                        scrollInfo.metrics.pixels >=
                            scrollInfo.metrics.maxScrollExtent - 500) {
                      ref.read(homeProvider.notifier).loadMoreFeed();
                    }
                    return false;
                  },
                  child: CustomScrollView(
                    slivers: [
                      // Top App Bar Branding
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ref.watch(profileProvider).getGreeting(),
                                      style: GoogleFonts.outfit(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: context.themeTextColor,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!(!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux))) ...[
                                  if (ref
                                      .watch(aiSettingsProvider)
                                      .isConfigured)
                                    IconButton(
                                      icon: Icon(
                                        Icons.auto_awesome_rounded,
                                        color: context.themeTextColor,
                                        size: 22,
                                      ),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const AskAIScreen(),
                                        ),
                                      ),
                                      tooltip: 'Ask Feels',
                                    ),
                                  ],
                                  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) ...[
                                    TVFocusableCard(
                                      focusedScale: 1.1,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const ProfileScreen(),
                                        ),
                                      ),
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: Consumer(
                                          builder: (context, ref, _) {
                                            final profile = ref.watch(
                                              profileProvider,
                                            );
                                            final hasAvatar =
                                                profile.userAvatar.isNotEmpty &&
                                                File(
                                                  profile.userAvatar,
                                                ).existsSync();
                                            return CircleAvatar(
                                              radius: 16,
                                              backgroundColor: context
                                                  .themeAccentColor
                                                  .withValues(alpha: 0.2),
                                              backgroundImage: hasAvatar
                                                  ? FileImage(
                                                      File(profile.userAvatar),
                                                    )
                                                  : null,
                                              child: hasAvatar
                                                  ? null
                                                  : Icon(
                                                      Icons.person_outline,
                                                      color:
                                                          context.themeTextColor,
                                                      size: 20,
                                                    ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.cell_tower_rounded,
                                        color: playerProvider.isInRoom
                                            ? Colors.greenAccent
                                            : context.themeTextColor,
                                        size: 22,
                                      ),
                                      onPressed: () => RoomBottomSheet.show(
                                        context,
                                        isHost: false,
                                      ),
                                      tooltip: 'Listen Together',
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.radio,
                                        color: context.themeTextColor,
                                        size: 22,
                                      ),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const RadioScreen(),
                                        ),
                                      ),
                                      tooltip: 'Radio Stations',
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.settings_outlined,
                                        color: context.themeTextColor,
                                        size: 22,
                                      ),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const SettingsScreen(),
                                        ),
                                      ),
                                      tooltip: 'Settings',
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Category Filter Chips Bar
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 52,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            itemCount: _filters.length,
                            itemBuilder: (context, index) {
                              final isSelected = index == _selectedFilterIndex;
                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: _GlassmorphicChip(
                                  label: _filters[index],
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(
                                      () => _selectedFilterIndex = index,
                                    );
                                    ref
                                        .read(homeProvider.notifier)
                                        .selectCategory(_filters[index]);
                                    if (_filters[index] == "For You" &&
                                        homeProv
                                            .currentCategoryPlaylists
                                            .isEmpty) {
                                      ref
                                          .read(homeProvider.notifier)
                                          .fetchYouSongs(
                                            historyProvider.getTopArtists(),
                                          );
                                      if (homeProv.moodPlaylists.isEmpty) {
                                        ref
                                            .read(homeProvider.notifier)
                                            .fetchMoods();
                                      }
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),

                      // Mobile/Tablet Hero Banner (Apple Music style)
                      if (activeSongs.isNotEmpty &&
                          selectedCat != "Charts" &&
                          !homeProv.isLoading)
                        SliverToBoxAdapter(
                          child: _buildHeroBanner(
                            context,
                            activeSongs,
                            playerProvider,
                          ),
                        ),

                      if (homeProv.continueWatching.isNotEmpty &&
                          selectedCat == "For You")
                        _buildJumpBackInCarousel(
                          context,
                          homeProv.continueWatching,
                          playerProvider,
                        ),

                      if (homeProv.isLoading)
                        SliverToBoxAdapter(
                          child: ExcludeSemantics(
                            child: Builder(
                              builder: (context) {
                                final screenWidth = MediaQuery.of(context).size.width;
                                final double cardWidth = (screenWidth * 0.4).clamp(350.0, 600.0);
                                final double cardHeight = cardWidth * (9 / 16);
                                
                                return Shimmer.fromColors(
                                  baseColor: context.themeCardColor,
                                  highlightColor: context.themeSurfaceColor,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 16),
                                      // Hero Banner Skeleton
                                      if (selectedCat != "Charts") ...[
                                        SizedBox(
                                          height: cardHeight + 40,
                                          child: ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            padding: const EdgeInsets.symmetric(horizontal: 20),
                                            itemCount: 2,
                                            itemBuilder: (_, _) => Padding(
                                              padding: const EdgeInsets.only(right: 24, top: 16, bottom: 16),
                                              child: Container(
                                                width: cardWidth,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(24),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 16),
                                      // Section Title Skeleton
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        child: Container(
                                          width: 200,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                      // Standard Carousel Skeleton
                                      SizedBox(
                                        height: 190,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          padding: const EdgeInsets.symmetric(horizontal: 20),
                                          itemCount: 4,
                                          itemBuilder: (_, _) => Padding(
                                            padding: const EdgeInsets.only(right: 14),
                                            child: Container(
                                              width: 140,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            ),
                          ),
                        ),

                      if (selectedCat == "For You") ...[
                        if (activeSongs.isEmpty &&
                            homeProv.youPlaylists.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 40,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.headphones_rounded,
                                    size: 64,
                                    color: context.themeMutedTextColor
                                        .withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "Your Music, Your Rules",
                                    style: GoogleFonts.outfit(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: context.themeTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Listen to more songs to unlock your personalized Daily Mixes and history.",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: context.themeMutedTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else ...[
                          // Top Artists Removed by User Request
                          const SliverToBoxAdapter(child: SizedBox.shrink()),

                          // Spotify style 2x3 grid (Jump Back In or Quick Picks)
                          Builder(
                            builder: (context) {
                              final gridSongs = activeSongs.length > 1
                                  ? activeSongs.take(6).toList()
                                  : homeProv.trendingSongs.take(6).toList();
                              final gridTitle = activeSongs.length > 1
                                  ? "Jump Back In"
                                  : "Trending Picks";
                              if (gridSongs.length > 1) {
                                return _buildCompactTrackGrid(
                                  context,
                                  gridSongs,
                                  playerProvider,
                                  title: gridTitle,
                                );
                              }
                              return const SliverToBoxAdapter(
                                child: SizedBox.shrink(),
                              );
                            },
                          ),

                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 16, top: 16),
                              child: SmartRecommendationsRow(),
                            ),
                          ),
                          _buildPlaylistCarousel(
                            context,
                            "Daily Mixes",
                            homeProv.youPlaylists,
                          ),
                          _buildPlaylistCarousel(
                            context,
                            "Curated Moods",
                            homeProv.moodPlaylists,
                          ),
                        ],
                      ] else if (selectedCat == "Music") ...[
                          _buildCompactTrackGrid(
                            context,
                            activeSongs.length > 1
                                ? activeSongs.take(18).toList()
                                : homeProv.trendingSongs.take(18).toList(),
                            playerProvider,
                            title: "Quick Picks",
                          ),
                        // Render Horizontal Swipeable Song Grid Carousels for Genres
                        _buildSongCarousel(
                          context,
                          "Trending Now",
                          homeProv.trendingSongs,
                          playerProvider,
                        ),
                        _buildPlaylistCarousel(
                          context,
                          "Top Albums",
                          homeProv.topAlbums,
                        ),
                        _buildSongCarousel(
                          context,
                          "Bollywood Hits",
                          homeProv.bollywoodSongs,
                          playerProvider,
                        ),
                        _buildSongCarousel(
                          context,
                          "Punjabi Hits",
                          homeProv.punjabiSongs,
                          playerProvider,
                        ),
                        _buildSongCarousel(
                          context,
                          "Telugu Hits",
                          homeProv.teluguSongs,
                          playerProvider,
                        ),
                        _buildSongCarousel(
                          context,
                          "Tamil Hits",
                          homeProv.tamilSongs,
                          playerProvider,
                        ),
                        _buildSongCarousel(
                          context,
                          "Hollywood Pop",
                          homeProv.hollywoodSongs,
                          playerProvider,
                        ),
                      ] else if (selectedCat == "Podcasts") ...[
                        _buildPlaylistCarousel(
                          context,
                          "Top Podcasts",
                          homeProv.podcastPlaylists,
                        ),
                        _buildSongCarousel(
                          context,
                          "Latest Episodes",
                          activeSongs,
                          playerProvider,
                        ),
                      ] else if (selectedCat == "Charts") ...[
                        if (homeProv.chartPlaylists.isNotEmpty)
                          ..._buildChartGrid(context, "Global Charts", homeProv.chartPlaylists),
                      ],

                      // Infinite Dynamic Feeds
                      if (homeProv.dynamicFeeds[selectedCat] != null) ...[
                        for (var shelf in homeProv.dynamicFeeds[selectedCat]!)
                          _buildDynamicShelf(context, shelf, playerProvider),
                      ],

                      // Loading indicator for infinite feed
                      if (homeProv.isLoadingFeed[selectedCat] == true)
                        SliverToBoxAdapter(
                          child: ExcludeSemantics(
                            child: Shimmer.fromColors(
                              baseColor: context.themeCardColor,
                              highlightColor: context.themeSurfaceColor,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 24,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 150,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      height: 180,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: 4,
                                        itemBuilder: (_, _) => Padding(
                                          padding: const EdgeInsets.only(
                                            right: 14,
                                          ),
                                          child: Container(
                                            width: 140,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      SliverToBoxAdapter(
                        child: SizedBox(
                          height:
                              AppDimensions.bottomClearance +
                              MediaQuery.of(context).viewPadding.bottom,
                        ),
                      ),
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

  List<Widget> _buildChartGrid(
    BuildContext context,
    String title,
    List<Playlist> playlists,
  ) {
    return [
      SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(left: 48, right: 48, top: 40, bottom: 24),
            child: Text(
              title,
              style: AppTypography.outfitExtraBold.copyWith(
                fontSize: 24,
                color: context.themeTextColor,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240.0,
              mainAxisSpacing: 24.0,
              crossAxisSpacing: 24.0,
              childAspectRatio: 0.8, // Accommodate image + title text
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final pl = playlists[index];
                String displayTitle = pl.title;
                if (displayTitle.startsWith("Daily Mix: ")) {
                  displayTitle = "${displayTitle.replaceFirst("Daily Mix: ", "")} Mix";
                }

                return TVFocusableCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlaylistDetailScreen(playlist: pl),
                    ),
                  ),
                  focusedScale: 1.03,
                  borderRadius: 12.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 1.0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12.0),
                          child: pl.coverArt.isNotEmpty
                              ? CustomImageWidget(
                                  imageUrl: pl.coverArt,
                                  fit: BoxFit.cover,
                                  size: 240,
                                )
                              : Container(
                                  color: const Color(0xFF181818),
                                  child: const Icon(
                                    Icons.music_note,
                                    color: Colors.white54,
                                    size: 40,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                         displayTitle,
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                         style: AppTypography.interSemiBold.copyWith(
                           color: context.themeTextColor,
                           fontSize: 14,
                         ),
                      ),
                    ],
                  ),
                );
              },
              childCount: playlists.length,
            ),
          ),
        ),
    ];
  }

  Widget _buildDynamicShelf(
    BuildContext context,
    FeedShelf shelf,
    AudioPlayerState playerProvider,
  ) {
    if (shelf.type == ShelfType.artistGrid) {
      return _buildArtistGridCarousel(context, shelf.title, shelf.items);
    } else if (shelf.type == ShelfType.songCarousel) {
      return _buildSongCarousel(
        context,
        shelf.title,
        shelf.items.cast<Song>(),
        playerProvider,
      );
    } else if (shelf.type == ShelfType.playlistCarousel) {
      return _buildPlaylistCarousel(
        context,
        shelf.title,
        shelf.items.cast<Playlist>(),
      );
    }
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }
}

class _GlassmorphicChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GlassmorphicChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_GlassmorphicChip> createState() => _GlassmorphicChipState();
}

class _GlassmorphicChipState extends State<_GlassmorphicChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: TVFocusableCard(
        onTap: widget.onTap,
        focusedScale: 1.1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.white
                : (_isHovered
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              color: widget.isSelected
                  ? Colors.black
                  : Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
