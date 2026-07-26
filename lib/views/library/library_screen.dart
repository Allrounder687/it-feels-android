import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/song_model.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/home_provider.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _selectedTabIndex = 0;
  final List<String> _tabs = ["SONGS", "FAVORITES", "ALBUMS", "ARTIST", "PLAYLISTS"];

  @override
  Widget build(BuildContext context) {
    return Consumer2<HomeProvider, AudioPlayerProvider>(
      builder: (context, homeProvider, playerProvider, child) {
        List<Song> displaySongs;
        if (_selectedTabIndex == 1) {
          // FAVORITES tab
          displaySongs = playerProvider.favoriteSongs;
        } else {
          // SONGS & Default
          displaySongs = homeProvider.trendingSongs;
        }

        return Scaffold(
          backgroundColor: AppColors.midnightBackground,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: "Library" + Settings Gear Icon
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Library",
                        style: GoogleFonts.outfit(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.midnightPill,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                        ),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),

                // Horizontal Filter Pill Tabs (SONGS, FAVORITES, ALBUMS, ARTIST, PLAYLISTS)
                SizedBox(
                  height: 42,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _tabs.length,
                    itemBuilder: (context, index) {
                      final isSelected = index == _selectedTabIndex;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTabIndex = index;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.midnightPrimary : AppColors.midnightPill,
                            borderRadius: BorderRadius.circular(21),
                          ),
                          child: Text(
                            _tabs[index],
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

                const SizedBox(height: 16),

                // Action Bar: "Shuffle" Pill Button + Filter Icon
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.midnightPill,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        icon: const Icon(Icons.shuffle, size: 18),
                        label: Text(
                          "Shuffle",
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () {
                          if (displaySongs.isNotEmpty) {
                            final shuffled = List<Song>.from(displaySongs)..shuffle();
                            playerProvider.playSong(shuffled[0], queue: shuffled, index: 0);
                          }
                        },
                      ),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.midnightPill,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.sort_rounded, color: Colors.white, size: 18),
                        ),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Track List View
                Expanded(
                  child: displaySongs.isEmpty
                      ? Center(
                          child: Text(
                            _selectedTabIndex == 1
                                ? "No favorite songs added yet"
                                : "No tracks found",
                            style: GoogleFonts.inter(color: AppColors.midnightTextMuted),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: displaySongs.length,
                          itemBuilder: (context, index) {
                            final song = displaySongs[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: AppColors.midnightCard.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(16),
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: song.coverArt.isNotEmpty
                                          ? CachedNetworkImage(
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
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: AppColors.midnightTextMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      playerProvider.isFavorite(song.id)
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      color: playerProvider.isFavorite(song.id)
                                          ? Colors.pinkAccent
                                          : Colors.white54,
                                      size: 20,
                                    ),
                                    onPressed: () => playerProvider.toggleFavorite(song),
                                  ),
                                  onTap: () {
                                    playerProvider.playSong(song, queue: displaySongs, index: index);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }
}
