import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/features/library/download_provider.dart';
import 'package:it_feels_music/core/widgets/empty_state_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:it_feels_music/features/home/home_provider.dart';
import 'package:it_feels_music/features/library/custom_playlist_provider.dart';
import 'package:it_feels_music/features/library/artist_detail_screen.dart';
import 'package:it_feels_music/features/library/playlist_detail_screen.dart';
import 'package:it_feels_music/features/library/custom_playlist_detail_screen.dart';
import 'package:it_feels_music/features/settings/settings_screen.dart';
import 'package:it_feels_music/core/widgets/song_options_sheet.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/theme/app_dimensions.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _selectedTabIndex = 0;
  final List<String> _tabs = ["SONGS", "FAVORITES", "DOWNLOADS", "ALBUMS", "ARTIST", "MY PLAYLISTS"];

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
    return Consumer(
      builder: (context, ref, child) {
        final homeProv = ref.watch(homeProvider);
        final playerProvider = ref.watch(audioPlayerProvider);
        final downloadProviderLocal = ref.watch(downloadProvider);
        final customPlaylistProviderLocal = ref.watch(customPlaylistProvider);
        final trending = homeProv.trendingSongs;
        final playlists = homeProv.topPlaylists;

        return Scaffold(
          backgroundColor: context.themeBackgroundColor,
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
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back, color: context.themeTextColor),
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/');
                              }
                            },
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                          ),
                          Text(
                            "Library",
                            style: GoogleFonts.outfit(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: context.themeTextColor,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.themeUnselectedPillColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.settings_outlined, color: context.themeTextColor, size: 20),
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
                            color: isSelected ? context.themeAccentColor : context.themeUnselectedPillColor,
                            borderRadius: BorderRadius.circular(21),
                          ),
                          child: Text(
                            _tabs[index],
                            style: GoogleFonts.inter(
                              color: isSelected ? context.themeInvertedTextColor : context.themeUnselectedPillTextColor,
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
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: _buildTabContent(homeProv, playerProvider, downloadProviderLocal, customPlaylistProviderLocal, trending, playlists),
                    ),
                  ),
                ),

                SizedBox(height: AppDimensions.bottomClearance + MediaQuery.of(context).viewPadding.bottom),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabContent(
    HomeState homeProv,
    AudioPlayerState playerProvider,
    DownloadState downloadProviderLocal,
    CustomPlaylistState customPlaylistProviderLocal,
    List<Song> trending,
    List<Playlist> playlists,
  ) {
    if (_selectedTabIndex == 1) {
      // FAVORITES TAB
      final favorites = playerProvider.favoriteSongs;
      return _buildSongListView(favorites, playerProvider, "No favorite songs added yet");
    } else if (_selectedTabIndex == 2) {
      // DOWNLOADS TAB
      final downloaded = downloadProviderLocal.downloadedSongs;
      return _buildSongListView(downloaded, playerProvider, "No downloaded tracks for offline playback");
    } else if (_selectedTabIndex == 3) {
      // ALBUMS TAB
      final albums = playlists.where((p) => p.type == 'album').toList();
      final displayAlbums = albums.isNotEmpty ? albums : playlists;

      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
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
                        : Container(color: context.themeCardColor),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  album.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: context.themeTextColor, fontWeight: FontWeight.w600, fontSize: 14),
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
              color: context.themeCardColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                leading: ClipOval(
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: CustomImageWidget(
                      imageUrl: artist['image']!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Icon(Icons.person, color: context.themeTextColor),
                    ),
                  ),
                ),
                title: Text(
                  artist['name']!,
                  style: GoogleFonts.inter(color: context.themeTextColor, fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Text(
                  "Artist",
                  style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12),
                ),
                trailing: Icon(Icons.chevron_right, color: context.themeMutedTextColor),
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
      // MY PLAYLISTS TAB
      final myPlaylists = customPlaylistProviderLocal.playlists;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.midnightPill,
                foregroundColor: context.themeTextColor,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.add),
              label: Text("Create New Playlist", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              onPressed: () {
                _showCreatePlaylistDialog(context, customPlaylistProviderLocal);
              },
            ),
          ),
          Expanded(
            child: myPlaylists.isEmpty
                ? Center(
                    child: Text("You haven't created any playlists yet.",
                        style: GoogleFonts.inter(color: context.themeMutedTextColor)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: myPlaylists.length,
                    itemBuilder: (context, index) {
                      final pl = myPlaylists[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: context.themeCardColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: pl.songs.isNotEmpty && pl.songs.first.coverArt.isNotEmpty
                                    ? CustomImageWidget(imageUrl: pl.songs.first.coverArt, fit: BoxFit.cover)
                                    : Icon(Icons.queue_music, color: context.themeTextColor),
                              ),
                            ),
                            title: Text(
                              pl.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(color: context.themeTextColor, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: Text(
                              "${pl.songs.length} tracks",
                              style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12),
                            ),
                            trailing: Icon(Icons.chevron_right, color: context.themeMutedTextColor),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => CustomPlaylistDetailScreen(playlist: pl)),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    } else {
      // SONGS TAB (Default)
      return _buildSongListView(trending, playerProvider, "No tracks available");
    }
  }

  Widget _buildSongListView(List<Song> songs, AudioPlayerState playerProvider, String emptyMessage) {
    if (songs.isEmpty) {
      IconData iconData = Icons.music_note_rounded;
      if (emptyMessage.contains("favorite")) iconData = Icons.favorite_border_rounded;
      if (emptyMessage.contains("download")) iconData = Icons.download_done_rounded;
      
      return PremiumEmptyState(
        icon: iconData,
        title: "It's empty here",
        message: emptyMessage,
        ctaText: "Discover Music",
        onCtaPressed: () {
          context.go('/search');
        },
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
            color: context.themeCardColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: song.coverArt.isNotEmpty
                      ? CustomImageWidget(imageUrl: song.coverArt, fit: BoxFit.cover)
                      : Icon(Icons.music_note, color: context.themeTextColor),
                ),
              ),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(color: context.themeTextColor, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12),
              ),
              trailing: IconButton(
                icon: Icon(Icons.more_vert, color: context.themeMutedTextColor),
                onPressed: () {
                  SongOptionsSheet.show(context, song, playlistContext: songs);
                },
              ),
              onTap: () {
                ref.read(audioPlayerProvider.notifier).playSong(song, queue: songs, index: index);
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

  void _showCreatePlaylistDialog(BuildContext context, CustomPlaylistState provider) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.themeSurfaceColor,
        title: Text("New Playlist", style: GoogleFonts.outfit(color: context.themeTextColor)),
        content: TextField(
          controller: controller,
          style: GoogleFonts.inter(color: context.themeTextColor),
          decoration: InputDecoration(
            hintText: "Playlist Name",
            hintStyle: GoogleFonts.inter(color: context.themeMutedTextColor),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: context.themeTextColor24)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.midnightAccent)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            child: Text("Cancel", style: TextStyle(color: context.themeMutedTextColor)),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text("Create", style: TextStyle(color: AppColors.midnightAccent)),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(customPlaylistProvider.notifier).createPlaylist(controller.text.trim());
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}
