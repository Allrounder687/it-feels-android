import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/providers/bottom_ui_provider.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:it_feels_music/core/widgets/song_options_sheet.dart';
import 'package:it_feels_music/data/models/custom_playlist.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/library/custom_playlist_detail_screen.dart';
import 'package:it_feels_music/features/library/playlist_detail_screen.dart';
import 'package:it_feels_music/features/neo/home/widgets/neo_media_card.dart';

class NeoLibraryScreen extends ConsumerStatefulWidget {
  const NeoLibraryScreen({super.key});

  @override
  ConsumerState<NeoLibraryScreen> createState() => _NeoLibraryScreenState();
}

class _NeoLibraryScreenState extends ConsumerState<NeoLibraryScreen> {
  int _activeDrawerIndex = 0; // 0: Playlists, 1: Downloads, 2: Favorites, 3: Artists, 4: Albums
  final List<String> _drawerTitles = ["Playlists", "Downloads", "Favorites", "Artists", "Albums"];

  @override
  Widget build(BuildContext context) {
    final homeProv = ref.watch(homeProvider);
    final playerState = ref.watch(audioPlayerProvider);
    final downloadState = ref.watch(downloadProvider);
    final customPlaylistState = ref.watch(customPlaylistProvider);
    final bottomUiHeight = ref.watch(bottomUiProvider);
    final accentColor = playerState.themeAccentColor;

    final userPlaylists = customPlaylistState.playlists;
    final downloadedSongs = downloadState.downloadedSongs;
    final favoriteSongs = homeProv.trendingSongs.where((s) => s.isFavorite).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E18),
      body: SafeArea(
        top: true,
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Editorial Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 12.0, bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "YOUR COLLECTION",
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Colors.white.withValues(alpha: 0.50),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Library",
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Apple Music Navigational Drawers (Tier 2 Contextual Navigation) ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildDrawerTile(
                        icon: Icons.queue_music_rounded,
                        title: "Playlists",
                        count: userPlaylists.length,
                        index: 0,
                        accentColor: accentColor,
                      ),
                      _buildDivider(),
                      _buildDrawerTile(
                        icon: Icons.download_done_rounded,
                        title: "Downloaded Music",
                        count: downloadedSongs.length,
                        index: 1,
                        accentColor: accentColor,
                      ),
                      _buildDivider(),
                      _buildDrawerTile(
                        icon: Icons.favorite_rounded,
                        title: "Favorites",
                        count: favoriteSongs.length,
                        index: 2,
                        accentColor: accentColor,
                      ),
                      _buildDivider(),
                      _buildDrawerTile(
                        icon: Icons.person_rounded,
                        title: "Artists",
                        count: homeProv.trendingSongs.map((s) => s.artist).toSet().length,
                        index: 3,
                        accentColor: accentColor,
                      ),
                      _buildDivider(),
                      _buildDrawerTile(
                        icon: Icons.album_rounded,
                        title: "Albums",
                        count: homeProv.topAlbums.length,
                        index: 4,
                        accentColor: accentColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Drawer Title & Quick Play Actions Row ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _drawerTitles[_activeDrawerIndex],
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (_activeDrawerIndex == 1 && downloadedSongs.isNotEmpty)
                      GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Scanning device storage for music...", style: GoogleFonts.inter()),
                              backgroundColor: const Color(0xFF1B2232),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          await ref.read(downloadProvider.notifier).scanAndSync();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh_rounded, color: accentColor, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                "Rescan",
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.85),
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

            // ── Content Builder Based on Active Drawer ──
            ..._buildActiveDrawerContent(
              activeDrawer: _activeDrawerIndex,
              customPlaylists: userPlaylists,
              downloadedSongs: downloadedSongs,
              favoriteSongs: favoriteSongs,
              topAlbums: homeProv.topAlbums,
              trendingSongs: homeProv.trendingSongs,
              accentColor: accentColor,
            ),

            // ── Bottom Clearance for Floating Island Dock ──
            SliverToBoxAdapter(
              child: SizedBox(height: bottomUiHeight + 36),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    required int count,
    required int index,
    required Color accentColor,
  }) {
    final isSelected = _activeDrawerIndex == index;

    return ListTile(
      dense: true,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _activeDrawerIndex = index;
        });
      },
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isSelected ? accentColor : Colors.white.withValues(alpha: 0.70),
          size: 18,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14.5,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.85),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? accentColor : Colors.white.withValues(alpha: 0.60),
                ),
              ),
            ),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white.withValues(alpha: 0.30),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 56,
      endIndent: 16,
      color: Colors.white.withValues(alpha: 0.06),
    );
  }

  List<Widget> _buildActiveDrawerContent({
    required int activeDrawer,
    required List<CustomPlaylist> customPlaylists,
    required List<Song> downloadedSongs,
    required List<Song> favoriteSongs,
    required List<Playlist> topAlbums,
    required List<Song> trendingSongs,
    required Color accentColor,
  }) {
    switch (activeDrawer) {
      // 0: Playlists
      case 0:
        if (customPlaylists.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Center(
                  child: Text(
                    "No custom playlists yet.\nCreate one from any song menu!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.40),
                    ),
                  ),
                ),
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final playlist = customPlaylists[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.queue_music_rounded, color: accentColor),
                      ),
                      title: Text(
                        playlist.title,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        "${playlist.songs.length} Songs",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.50),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white30),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomPlaylistDetailScreen(playlist: playlist),
                          ),
                        );
                      },
                    ),
                  );
                },
                childCount: customPlaylists.length,
              ),
            ),
          ),
        ];

      // 1: Downloads
      case 1:
        if (downloadedSongs.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.download_for_offline_rounded, size: 48, color: Colors.white24),
                      const SizedBox(height: 12),
                      Text(
                        "No offline downloads found.",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.50),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ];
        }
        return [
          _buildSongListSliver(downloadedSongs, accentColor),
        ];

      // 2: Favorites
      case 2:
        if (favoriteSongs.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Center(
                  child: Text(
                    "No favorite songs yet.\nHeart songs to add them here!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.40),
                    ),
                  ),
                ),
              ),
            ),
          ];
        }
        return [
          _buildSongListSliver(favoriteSongs, accentColor),
        ];

      // 4: Albums
      case 4:
        return [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.78,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final album = topAlbums[index];
                  return NeoMediaCard(
                    title: album.title,
                    subtitle: album.type == 'album' ? "Album" : "${album.songCount} Songs",
                    imageUrl: album.coverArt,
                    size: 155,
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
                childCount: topAlbums.length,
              ),
            ),
          ),
        ];

      // 3: Artists / Default
      default:
        final artists = trendingSongs.map((s) => s.artist).toSet().toList();
        return [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final artist = artists[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white.withValues(alpha: 0.10),
                        child: const Icon(Icons.person, color: Colors.white70, size: 20),
                      ),
                      title: Text(
                        artist,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white30),
                      onTap: () {
                        ref.read(searchProvider.notifier).search(artist);
                      },
                    ),
                  );
                },
                childCount: artists.length,
              ),
            ),
          ),
        ];
    }
  }

  Widget _buildSongListSliver(List<Song> songList, Color accentColor) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final song = songList[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8.0),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: CustomImageWidget(imageUrl: song.coverArt, fit: BoxFit.cover),
                  ),
                ),
                title: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.60),
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white.withValues(alpha: 0.60),
                    size: 20,
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => SongOptionsSheet(song: song),
                    );
                  },
                ),
                onTap: () {
                  ref.read(audioPlayerProvider.notifier).playSong(
                        song,
                        queue: songList,
                        index: index,
                      );
                },
              ),
            );
          },
          childCount: songList.length,
        ),
      ),
    );
  }
}
