import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/search_provider.dart';
import '../details/artist_detail_screen.dart';
import '../details/playlist_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedCategoryIndex = 0;
  final List<String> _categories = ["ALL", "SONGS", "ARTISTS", "ALBUMS", "PLAYLISTS"];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SearchProvider, AudioPlayerProvider>(
      builder: (context, searchProvider, playerProvider, child) {
        final songs = searchProvider.songs;
        final albums = searchProvider.albums;
        final playlists = searchProvider.playlists;

        return Scaffold(
          backgroundColor: AppColors.midnightBackground,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Search Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Search",
                        style: GoogleFonts.outfit(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Search Input Pill
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.midnightPill,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: GoogleFonts.inter(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Search songs, artists, albums, playlists...",
                            hintStyle: GoogleFonts.inter(color: AppColors.midnightTextMuted),
                            prefixIcon: const Icon(Icons.search, color: Colors.white70),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.white70),
                                    onPressed: () {
                                      _searchController.clear();
                                      searchProvider.search('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onChanged: (val) => searchProvider.search(val),
                        ),
                      ),
                    ],
                  ),
                ),

                // Category Filter Pills (ALL, SONGS, ARTISTS, ALBUMS, PLAYLISTS)
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final isSelected = index == _selectedCategoryIndex;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategoryIndex = index;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.midnightPrimary : AppColors.midnightPill,
                            borderRadius: BorderRadius.circular(19),
                          ),
                          child: Text(
                            _categories[index],
                            style: GoogleFonts.inter(
                              color: isSelected ? Colors.black : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Search Results List
                Expanded(
                  child: searchProvider.isSearching
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.midnightAccent),
                        )
                      : _searchController.text.isEmpty
                          ? Center(
                              child: Text(
                                "Search for tracks, artists, albums, or playlists",
                                style: GoogleFonts.inter(color: AppColors.midnightTextMuted),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              children: [
                                // Artists Direct Match Section
                                if (_selectedCategoryIndex == 0 || _selectedCategoryIndex == 2) ...[
                                  Text(
                                    "Artist Match",
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Material(
                                    color: AppColors.midnightCard.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(16),
                                    child: ListTile(
                                      leading: const CircleAvatar(
                                        backgroundColor: AppColors.midnightPrimary,
                                        child: Icon(Icons.person, color: Colors.black),
                                      ),
                                      title: Text(
                                        _searchController.text,
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      subtitle: Text(
                                        "Explore full artist discography",
                                        style: GoogleFonts.inter(
                                          color: AppColors.midnightTextMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ArtistDetailScreen(
                                              artistName: _searchController.text,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Songs Section
                                if ((_selectedCategoryIndex == 0 || _selectedCategoryIndex == 1) && songs.isNotEmpty) ...[
                                  Text(
                                    "Songs",
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...songs.map((song) => Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Material(
                                          color: AppColors.midnightCard.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(16),
                                          child: ListTile(
                                            leading: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: SizedBox(
                                                width: 44,
                                                height: 44,
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
                                            trailing: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                                            onTap: () {
                                              playerProvider.playSong(song, queue: songs, index: songs.indexOf(song));
                                            },
                                          ),
                                        ),
                                      )),
                                  const SizedBox(height: 16),
                                ],

                                // Albums Section
                                if ((_selectedCategoryIndex == 0 || _selectedCategoryIndex == 3) && albums.isNotEmpty) ...[
                                  Text(
                                    "Albums",
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...albums.map((album) => Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Material(
                                          color: AppColors.midnightCard.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(16),
                                          child: ListTile(
                                            leading: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: SizedBox(
                                                width: 44,
                                                height: 44,
                                                child: album.coverArt.isNotEmpty
                                                    ? CachedNetworkImage(
                                                        imageUrl: album.coverArt,
                                                        fit: BoxFit.cover,
                                                      )
                                                    : const Icon(Icons.album, color: Colors.white),
                                              ),
                                            ),
                                            title: Text(
                                              album.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            subtitle: Text(
                                              "Album",
                                              style: GoogleFonts.inter(
                                                color: AppColors.midnightTextMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => PlaylistDetailScreen(playlist: album),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      )),
                                  const SizedBox(height: 16),
                                ],

                                // Playlists Section
                                if ((_selectedCategoryIndex == 0 || _selectedCategoryIndex == 4) && playlists.isNotEmpty) ...[
                                  Text(
                                    "Playlists",
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...playlists.map((pl) => Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Material(
                                          color: AppColors.midnightCard.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(16),
                                          child: ListTile(
                                            leading: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: SizedBox(
                                                width: 44,
                                                height: 44,
                                                child: pl.coverArt.isNotEmpty
                                                    ? CachedNetworkImage(
                                                        imageUrl: pl.coverArt,
                                                        fit: BoxFit.cover,
                                                      )
                                                    : const Icon(Icons.queue_music, color: Colors.white),
                                              ),
                                            ),
                                            title: Text(
                                              pl.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            subtitle: Text(
                                              "Playlist",
                                              style: GoogleFonts.inter(
                                                color: AppColors.midnightTextMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => PlaylistDetailScreen(playlist: pl),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      )),
                                ],

                                const SizedBox(height: 80),
                              ],
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
