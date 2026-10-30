import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/providers/bottom_ui_provider.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/library/playlist_detail_screen.dart';
import 'package:it_feels_music/features/settings/profile_screen.dart';
import 'package:it_feels_music/features/neo/home/widgets/neo_editorial_card.dart';
import 'package:it_feels_music/features/neo/home/widgets/neo_media_card.dart';
import 'package:it_feels_music/features/neo/home/widgets/neo_shelf_header.dart';

class NeoHomeScreen extends ConsumerStatefulWidget {
  final VoidCallback openFullPlayer;

  const NeoHomeScreen({super.key, required this.openFullPlayer});

  @override
  ConsumerState<NeoHomeScreen> createState() => _NeoHomeScreenState();
}

class _NeoHomeScreenState extends ConsumerState<NeoHomeScreen> {
  final List<String> _categories = [
    "For You",
    "Bollywood",
    "Hollywood",
    "Punjabi",
    "Telugu",
    "Tamil",
    "Charts",
    "Moods",
  ];

  int _selectedCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final homeProv = ref.read(homeProvider);
      final historyProvider = ref.read(listeningHistoryProvider);

      if (homeProv.trendingSongs.isEmpty) {
        ref.read(homeProvider.notifier).loadHomepageData();
      }
      if (homeProv.youSongs.isEmpty) {
        ref.read(homeProvider.notifier).fetchYouSongs(historyProvider.getTopArtists());
      }
      if (homeProv.topAlbums.isEmpty) {
        ref.read(homeProvider.notifier).fetchIndianAlbums();
      }
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    if (hour < 21) return "Good Evening";
    return "Late Night";
  }

  void _onCategorySelected(int index) {
    if (_selectedCategoryIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategoryIndex = index;
    });

    final selected = _categories[index];
    final notifier = ref.read(homeProvider.notifier);

    switch (selected) {
      case "For You":
        notifier.selectCategory("For You");
        break;
      case "Bollywood":
        notifier.fetchBollywoodSongs();
        break;
      case "Hollywood":
        notifier.fetchHollywoodSongs();
        break;
      case "Punjabi":
        notifier.fetchPunjabiSongs();
        break;
      case "Telugu":
        notifier.fetchTeluguSongs();
        break;
      case "Tamil":
        notifier.fetchTamilSongs();
        break;
      case "Charts":
        notifier.fetchCharts();
        break;
      case "Moods":
        notifier.fetchMoods();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);
    final historyState = ref.watch(listeningHistoryProvider);
    final playerState = ref.watch(audioPlayerProvider);
    final profile = ref.watch(profileProvider);
    final bottomUiHeight = ref.watch(bottomUiProvider);
    final accentColor = playerState.themeAccentColor;

    final selectedCat = _categories[_selectedCategoryIndex];

    // Pick active lists based on category selection
    List<Song> activeSongs;
    List<Playlist> activePlaylists;
    List<Playlist> activeAlbums;

    switch (selectedCat) {
      case "Bollywood":
        activeSongs = homeState.bollywoodSongs.isNotEmpty ? homeState.bollywoodSongs : homeState.trendingSongs;
        activePlaylists = homeState.bollywoodPlaylists.isNotEmpty ? homeState.bollywoodPlaylists : homeState.topPlaylists;
        activeAlbums = homeState.bollywoodAlbums.isNotEmpty ? homeState.bollywoodAlbums : homeState.topAlbums;
        break;
      case "Hollywood":
        activeSongs = homeState.hollywoodSongs.isNotEmpty ? homeState.hollywoodSongs : homeState.trendingSongs;
        activePlaylists = homeState.hollywoodPlaylists.isNotEmpty ? homeState.hollywoodPlaylists : homeState.topPlaylists;
        activeAlbums = homeState.hollywoodAlbums.isNotEmpty ? homeState.hollywoodAlbums : homeState.topAlbums;
        break;
      case "Punjabi":
        activeSongs = homeState.punjabiSongs.isNotEmpty ? homeState.punjabiSongs : homeState.trendingSongs;
        activePlaylists = homeState.punjabiPlaylists.isNotEmpty ? homeState.punjabiPlaylists : homeState.topPlaylists;
        activeAlbums = homeState.punjabiAlbums.isNotEmpty ? homeState.punjabiAlbums : homeState.topAlbums;
        break;
      case "Telugu":
        activeSongs = homeState.teluguSongs.isNotEmpty ? homeState.teluguSongs : homeState.trendingSongs;
        activePlaylists = homeState.teluguPlaylists.isNotEmpty ? homeState.teluguPlaylists : homeState.topPlaylists;
        activeAlbums = homeState.teluguAlbums.isNotEmpty ? homeState.teluguAlbums : homeState.topAlbums;
        break;
      case "Tamil":
        activeSongs = homeState.tamilSongs.isNotEmpty ? homeState.tamilSongs : homeState.trendingSongs;
        activePlaylists = homeState.tamilPlaylists.isNotEmpty ? homeState.tamilPlaylists : homeState.topPlaylists;
        activeAlbums = homeState.tamilAlbums.isNotEmpty ? homeState.tamilAlbums : homeState.topAlbums;
        break;
      case "Charts":
        activeSongs = homeState.trendingSongs;
        activePlaylists = homeState.chartPlaylists.isNotEmpty ? homeState.chartPlaylists : homeState.topPlaylists;
        activeAlbums = homeState.topAlbums;
        break;
      case "Moods":
        activeSongs = homeState.trendingSongs;
        activePlaylists = homeState.moodPlaylists.isNotEmpty ? homeState.moodPlaylists : homeState.topPlaylists;
        activeAlbums = homeState.topAlbums;
        break;
      case "For You":
      default:
        activeSongs = homeState.youSongs.isNotEmpty ? homeState.youSongs : homeState.trendingSongs;
        activePlaylists = homeState.youPlaylists.isNotEmpty ? homeState.youPlaylists : homeState.topPlaylists;
        activeAlbums = homeState.topAlbums;
        break;
    }

    final recentSongs = historyState.recentlyPlayed.take(10).toList();
    final spotlightSongs = activeSongs.take(4).toList();
    final shelfSongs = activeSongs.length > 4 ? activeSongs.skip(4).toList() : activeSongs;

    final hasAvatar = profile.userAvatar.isNotEmpty && File(profile.userAvatar).existsSync();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E18),
      body: SafeArea(
        top: true,
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Editorial Header with Profile Launcher ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 12.0, bottom: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting().toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: Colors.white.withValues(alpha: 0.50),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Listen Now",
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    // Profile & Sign-in Launcher (No duplicate Settings!)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        );
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.20),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          backgroundImage: hasAvatar ? FileImage(File(profile.userAvatar)) : null,
                          child: hasAvatar
                              ? null
                              : const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Frosted Filter Capsules ──
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 6.0),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategoryIndex == index;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _onCategorySelected(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8.0),
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accentColor.withValues(alpha: 0.22)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected
                                ? accentColor.withValues(alpha: 0.45)
                                : Colors.white.withValues(alpha: 0.10),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            cat,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? accentColor : Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Editorial Spotlight Carousel ──
            if (spotlightSongs.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14.0),
                  child: SizedBox(
                    height: 195,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      itemCount: spotlightSongs.length,
                      itemBuilder: (context, index) {
                        final song = spotlightSongs[index];
                        final eyebrow = index == 0
                            ? "FEATURED SPOTLIGHT"
                            : (index == 1 ? "POPULAR PICK" : "TRENDING NOW");

                        return NeoEditorialCard(
                          song: song,
                          eyebrow: eyebrow,
                          onTap: () {
                            ref.read(audioPlayerProvider.notifier).playSong(
                                  song,
                                  queue: spotlightSongs,
                                  index: index,
                                );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],

            // ── Shelf: Recently Played (Exclusive to "For You") ──
            if (selectedCat == "For You" && recentSongs.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: NeoShelfHeader(
                  title: "Recently Played",
                  subtitle: "HEAVY ROTATION",
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 175,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    itemCount: recentSongs.length,
                    itemBuilder: (context, index) {
                      final song = recentSongs[index];
                      return NeoMediaCard(
                        title: song.title,
                        subtitle: song.artist,
                        imageUrl: song.coverArt,
                        size: 120,
                        onTap: () {
                          ref.read(audioPlayerProvider.notifier).playSong(
                                song,
                                queue: recentSongs,
                                index: index,
                              );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],

            // ── Shelf: Category Hits & Top Picks ──
            if (shelfSongs.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: NeoShelfHeader(
                  title: selectedCat == "For You" ? "Top Picks" : "$selectedCat Hits",
                  subtitle: "HANDPICKED AUDIO",
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    itemCount: shelfSongs.length,
                    itemBuilder: (context, index) {
                      final song = shelfSongs[index];
                      return NeoMediaCard(
                        title: song.title,
                        subtitle: song.artist,
                        imageUrl: song.coverArt,
                        size: 130,
                        onTap: () {
                          ref.read(audioPlayerProvider.notifier).playSong(
                                song,
                                queue: shelfSongs,
                                index: index,
                              );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],

            // ── Shelf: Curated Playlists & Mixes ──
            if (activePlaylists.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: NeoShelfHeader(
                  title: selectedCat == "For You"
                      ? "Daily Mixes"
                      : (selectedCat == "Moods"
                          ? "Moods & Vibes"
                          : (selectedCat == "Charts" ? "Top Charts" : "$selectedCat Playlists")),
                  subtitle: "CURATED EXPERIENCES",
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 205,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    itemCount: activePlaylists.length,
                    itemBuilder: (context, index) {
                      final playlist = activePlaylists[index];
                      return NeoMediaCard(
                        title: playlist.title,
                        subtitle: "${playlist.songCount} Songs",
                        imageUrl: playlist.coverArt,
                        size: 150,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlaylistDetailScreen(playlist: playlist),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],

            // ── Shelf: Essential Albums ──
            if (activeAlbums.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: NeoShelfHeader(
                  title: selectedCat == "For You" ? "Essential Albums" : "$selectedCat Albums",
                  subtitle: "STUDIO RECORDINGS",
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 195,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    itemCount: activeAlbums.length,
                    itemBuilder: (context, index) {
                      final album = activeAlbums[index];
                      return NeoMediaCard(
                        title: album.title,
                        subtitle: album.type == 'album' ? "Album" : "${album.songCount} Songs",
                        imageUrl: album.coverArt,
                        size: 140,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlaylistDetailScreen(playlist: album),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],

            // ── Bottom Clearance for Floating Island Dock ──
            SliverToBoxAdapter(
              child: SizedBox(height: bottomUiHeight + 36),
            ),
          ],
        ),
      ),
    );
  }
}
