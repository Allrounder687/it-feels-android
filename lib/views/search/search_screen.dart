import 'package:it_feels_music/views/widgets/custom_image_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/search_provider.dart';
import '../details/artist_detail_screen.dart';
import '../details/playlist_detail_screen.dart';

import '../../providers/hidden_songs_provider.dart';

import '../widgets/song_options_sheet.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

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
    return Consumer3<SearchProvider, AudioPlayerProvider, HiddenSongsProvider>(
      builder: (context, searchProvider, playerProvider, hiddenProvider, child) {
        final songs = searchProvider.songs.where((s) => !hiddenProvider.isHidden(s.id)).toList();
        final albums = searchProvider.albums;
        final playlists = searchProvider.playlists;

        return Scaffold(
          backgroundColor: context.themeBackgroundColor,
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
                          color: context.themeTextColor,
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
                          style: GoogleFonts.inter(color: context.themeTextColor),
                          decoration: InputDecoration(
                            hintText: "Search songs, artists, albums, playlists...",
                            hintStyle: GoogleFonts.inter(color: context.themeMutedTextColor),
                            prefixIcon: Icon(Icons.search, color: context.themeMutedTextColor),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, color: context.themeMutedTextColor),
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
                            color: isSelected ? context.themeAccentColor : AppColors.midnightPill,
                            borderRadius: BorderRadius.circular(19),
                          ),
                          child: Text(
                            _categories[index],
                            style: GoogleFonts.inter(
                              color: isSelected ? context.themeInvertedTextColor : context.themeTextColor,
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
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: searchProvider.isSearching
                          ? const Center(
                              child: CircularProgressIndicator(color: AppColors.midnightAccent),
                            )
                          : _searchController.text.isEmpty
                          ? Center(
                              child: Text(
                                "Search for tracks, artists, albums, or playlists",
                                style: GoogleFonts.inter(color: context.themeMutedTextColor),
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
                                      color: context.themeTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...searchProvider.artists.map((artist) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Material(
                                      color: context.themeCardColor.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(16),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: context.themeAccentColor,
                                          backgroundImage: artist['image']?.toString().isNotEmpty == true 
                                              ? CachedNetworkImageProvider(artist['image']) 
                                              : null,
                                          child: artist['image']?.toString().isNotEmpty == true 
                                              ? null 
                                              : Icon(Icons.person, color: context.themeInvertedTextColor),
                                        ),
                                        title: Text(
                                          artist['title'] ?? _searchController.text,
                                          style: GoogleFonts.inter(
                                            color: context.themeTextColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        subtitle: Text(
                                          "Explore full artist discography",
                                          style: GoogleFonts.inter(
                                            color: context.themeMutedTextColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                        trailing: Icon(Icons.chevron_right, color: context.themeMutedTextColor),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ArtistDetailScreen(
                                                artistName: artist['title'] ?? _searchController.text,
                                                artistImage: artist['image'],
                                                artistId: artist['id']?.toString(),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  )),
                                  const SizedBox(height: 16),
                                ],

                                // Songs Section
                                if ((_selectedCategoryIndex == 0 || _selectedCategoryIndex == 1) && songs.isNotEmpty) ...[
                                  Text(
                                    "Songs",
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: context.themeTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...songs.map((song) => Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Material(
                                          color: context.themeCardColor.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(16),
                                          child: ListTile(
                                            leading: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: SizedBox(
                                                width: 44,
                                                height: 44,
                                                child: song.coverArt.isNotEmpty
                                                    ? CustomImageWidget(
                                                        imageUrl: song.coverArt,
                                                        fit: BoxFit.cover,
                                                      )
                                                    : Icon(Icons.music_note, color: context.themeTextColor),
                                              ),
                                            ),
                                            title: Text(
                                              song.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                color: context.themeTextColor,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            subtitle: Row(
                                              children: [
                                                _buildProviderBadge(context, song.id),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    song.artist,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.inter(
                                                      color: context.themeMutedTextColor,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            trailing: IconButton(
                                              icon: Icon(Icons.more_vert, color: context.themeMutedTextColor),
                                              onPressed: () {
                                                SongOptionsSheet.show(context, song, playlistContext: songs);
                                              },
                                            ),
                                            onTap: () {
                                              playerProvider.playSong(song, queue: songs, index: songs.indexOf(song));
                                            },
                                            onLongPress: () {
                                              SongOptionsSheet.show(context, song, playlistContext: songs);
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
                                      color: context.themeTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...albums.map((album) => Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Material(
                                          color: context.themeCardColor.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(16),
                                          child: ListTile(
                                            leading: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: SizedBox(
                                                width: 44,
                                                height: 44,
                                                child: album.coverArt.isNotEmpty
                                                    ? CustomImageWidget(
                                                        imageUrl: album.coverArt,
                                                        fit: BoxFit.cover,
                                                      )
                                                    : Icon(Icons.album, color: context.themeTextColor),
                                              ),
                                            ),
                                            title: Text(
                                              album.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                color: context.themeTextColor,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            subtitle: Text(
                                              "Album",
                                              style: GoogleFonts.inter(
                                                color: context.themeMutedTextColor,
                                                fontSize: 12,
                                              ),
                                            ),
                                            trailing: Icon(Icons.chevron_right, color: context.themeMutedTextColor),
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
                                      color: context.themeTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...playlists.map((pl) => Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Material(
                                          color: context.themeCardColor.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(16),
                                          child: ListTile(
                                            leading: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: SizedBox(
                                                width: 44,
                                                height: 44,
                                                child: pl.coverArt.isNotEmpty
                                                    ? CustomImageWidget(
                                                        imageUrl: pl.coverArt,
                                                        fit: BoxFit.cover,
                                                      )
                                                    : Icon(Icons.queue_music, color: context.themeTextColor),
                                              ),
                                            ),
                                            title: Text(
                                              pl.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                color: context.themeTextColor,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            subtitle: Text(
                                              "Playlist",
                                              style: GoogleFonts.inter(
                                                color: context.themeMutedTextColor,
                                                fontSize: 12,
                                              ),
                                            ),
                                            trailing: Icon(Icons.chevron_right, color: context.themeMutedTextColor),
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

                                SizedBox(height: 168 + MediaQuery.of(context).viewPadding.bottom),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProviderBadge(BuildContext context, String songId) {
    String label = 'SAAVN';
    Color badgeColor = const Color(0xFF00B0FF); // Cool Saavn Blue

    if (songId.startsWith('youtube:')) {
      label = 'YOUTUBE';
      badgeColor = const Color(0xFFFF3D00); // YouTube Red
    } else if (songId.startsWith('spotify:')) {
      label = 'SPOTIFY';
      badgeColor = const Color(0xFF1DB954); // Spotify Green
    } else if (songId.startsWith('soundcloud:')) {
      label = 'SOUNDCLOUD';
      badgeColor = const Color(0xFFFF5500); // SoundCloud Orange
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: badgeColor.withValues(alpha: 0.35), width: 0.7),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          color: badgeColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
