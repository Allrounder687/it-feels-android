import 'package:pixel_player_saavn/views/widgets/custom_image_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/song_model.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/home_provider.dart';
import '../details/artist_detail_screen.dart';
import '../details/playlist_detail_screen.dart';
import '../settings/settings_screen.dart';
import '../widgets/song_options_sheet.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _selectedTabIndex = 0;
  final List<String> _tabs = ["SONGS", "FAVORITES", "DOWNLOADS", "ALBUMS", "ARTIST", "PLAYLISTS"];

  final List<Map<String, String>> _topArtists = [
    {'name': 'Atif Aslam', 'image': 'https://c.saavncdn.com/artists/Atif_Aslam_500x500.jpg'},
    {'name': 'Arijit Singh', 'image': 'https://c.saavncdn.com/artists/Arijit_Singh_500x500.jpg'},
    {'name': 'Pritam', 'image': 'https://c.saavncdn.com/artists/Pritam_500x500.jpg'},
    {'name': 'Shreya Ghoshal', 'image': 'https://c.saavncdn.com/artists/Shreya_Ghoshal_500x500.jpg'},
    {'name': 'Badshah', 'image': 'https://c.saavncdn.com/artists/Badshah_500x500.jpg'},
    {'name': 'Diljit Dosanjh', 'image': 'https://c.saavncdn.com/artists/Diljit_Dosanjh_500x500.jpg'},
    {'name': 'Anirudh Ravichander', 'image': 'https://c.saavncdn.com/artists/Anirudh_Ravichander_500x500.jpg'},
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer3<HomeProvider, AudioPlayerProvider, DownloadProvider>(
      builder: (context, homeProvider, playerProvider, downloadProvider, child) {
        final trending = homeProvider.trendingSongs;
        final playlists = homeProvider.topPlaylists;

        return Scaffold(
          backgroundColor: AppColors.midnightBackground,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: "Library" + Settings Gear Icon
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

                // Filter Pill Tabs (SONGS, FAVORITES, DOWNLOADS, ALBUMS, ARTIST, PLAYLISTS)
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
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.midnightPrimary : AppColors.midnightPill,
                            borderRadius: BorderRadius.circular(21),
                          ),
                          child: Text(
                            _tabs[index],
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

                const SizedBox(height: 16),

                // Main Content View per selected Tab
                Expanded(
                  child: _buildTabContent(homeProvider, playerProvider, downloadProvider, trending, playlists),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabContent(
    HomeProvider homeProvider,
    AudioPlayerProvider playerProvider,
    DownloadProvider downloadProvider,
    List<Song> trending,
    List<Playlist> playlists,
  ) {
    if (_selectedTabIndex == 1) {
      // FAVORITES TAB
      final favorites = playerProvider.favoriteSongs;
      return _buildSongListView(favorites, playerProvider, "No favorite songs added yet");
    } else if (_selectedTabIndex == 2) {
      // DOWNLOADS TAB
      final downloaded = downloadProvider.downloadedSongs;
      return _buildSongListView(downloaded, playerProvider, "No downloaded tracks for offline playback");
    } else if (_selectedTabIndex == 3) {
      // ALBUMS TAB
      final albums = playlists.where((p) => p.type == 'album').toList();
      final displayAlbums = albums.isNotEmpty ? albums : playlists;

      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: displayAlbums.length,
        itemBuilder: (context, index) {
          final album = displayAlbums[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PlaylistDetailScreen(playlist: album)),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: album.coverArt.isNotEmpty
                        ? CustomImageWidget(imageUrl: album.coverArt, fit: BoxFit.cover, width: double.infinity)
                        : Container(color: AppColors.midnightCard),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  album.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
          );
        },
      );
    } else if (_selectedTabIndex == 4) {
      // ARTIST TAB
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _topArtists.length,
        itemBuilder: (context, index) {
          final artist = _topArtists[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: AppColors.midnightCard.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                leading: ClipOval(
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: CustomImageWidget(
                      imageUrl: artist['image']!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.white),
                    ),
                  ),
                ),
                title: Text(
                  artist['name']!,
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Text(
                  "Artist",
                  style: GoogleFonts.inter(color: AppColors.midnightTextMuted, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ArtistDetailScreen(
                        artistName: artist['name']!,
                        artistImage: artist['image'],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      );
    } else if (_selectedTabIndex == 5) {
      // PLAYLISTS TAB
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          final pl = playlists[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: AppColors.midnightCard.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: pl.coverArt.isNotEmpty
                        ? CustomImageWidget(imageUrl: pl.coverArt, fit: BoxFit.cover)
                        : const Icon(Icons.queue_music, color: Colors.white),
                  ),
                ),
                title: Text(
                  pl.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  "Featured Playlist",
                  style: GoogleFonts.inter(color: AppColors.midnightTextMuted, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PlaylistDetailScreen(playlist: pl)),
                  );
                },
              ),
            ),
          );
        },
      );
    } else {
      // SONGS TAB (Default)
      return _buildSongListView(trending, playerProvider, "No tracks available");
    }
  }

  Widget _buildSongListView(List<Song> songs, AudioPlayerProvider playerProvider, String emptyMessage) {
    if (songs.isEmpty) {
      return Center(
        child: Text(emptyMessage, style: GoogleFonts.inter(color: AppColors.midnightTextMuted)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: AppColors.midnightCard.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: song.coverArt.isNotEmpty
                      ? CustomImageWidget(imageUrl: song.coverArt, fit: BoxFit.cover)
                      : const Icon(Icons.music_note, color: Colors.white),
                ),
              ),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(color: AppColors.midnightTextMuted, fontSize: 12),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white54),
                onPressed: () {
                  SongOptionsSheet.show(context, song, playlistContext: songs);
                },
              ),
              onTap: () {
                playerProvider.playSong(song, queue: songs, index: index);
              },
              onLongPress: () {
                SongOptionsSheet.show(context, song, playlistContext: songs);
              },
            ),
          ),
        );
      },
    );
  }
}
