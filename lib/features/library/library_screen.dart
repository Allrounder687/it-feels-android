import 'dart:io';
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
import 'package:it_feels_music/services/download_service.dart';

enum LibrarySortOption {
  dateAdded,
  titleAsc,
  titleDesc,
  artistAsc,
  duration,
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _selectedTabIndex = 0;
  final List<String> _tabs = ["SONGS", "FAVORITES", "DOWNLOADS", "ALBUMS", "ARTIST", "MY PLAYLISTS"];
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  LibrarySortOption _currentSort = LibrarySortOption.dateAdded;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
                            _searchQuery = '';
                            _searchController.clear();
                            _isSearching = false;
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
      return _buildSongListView(
        downloaded,
        playerProvider,
        "No downloaded tracks for offline playback",
        isDownloadsTab: true,
        downloadState: downloadProviderLocal,
      );
    } else if (_selectedTabIndex == 3) {
      // ALBUMS TAB
      final albums = playlists.where((p) => p.type == 'album').toList();
      final displayAlbums = albums.isNotEmpty ? albums : playlists;

      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
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

  List<Song> _applySortAndFilter(List<Song> songs) {
    var list = List<Song>.from(songs);
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((s) =>
        s.title.toLowerCase().contains(q) ||
        s.artist.toLowerCase().contains(q) ||
        s.album.toLowerCase().contains(q)
      ).toList();
    }
    switch (_currentSort) {
      case LibrarySortOption.dateAdded:
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
      case LibrarySortOption.titleAsc:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case LibrarySortOption.titleDesc:
        list.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case LibrarySortOption.artistAsc:
        list.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
      case LibrarySortOption.duration:
        list.sort((a, b) => b.duration.compareTo(a.duration));
        break;
    }
    return list;
  }

  String _formatTotalDuration(List<Song> songs) {
    final totalSeconds = songs.fold<int>(0, (sum, s) => sum + s.duration);
    if (totalSeconds <= 0) return '';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours hr ${minutes > 0 ? '$minutes min' : ''}';
    }
    return '$minutes min';
  }

  String _calculateDownloadsSize(List<Song> songs) {
    int totalBytes = 0;
    for (final song in songs) {
      if (song.encryptedMediaUrl != null && song.encryptedMediaUrl!.isNotEmpty) {
        try {
          final f = File(song.encryptedMediaUrl!);
          if (f.existsSync()) {
            totalBytes += f.lengthSync();
            final cover = File('${f.parent.path}/cover.jpg');
            if (cover.existsSync()) totalBytes += cover.lengthSync();
          }
        } catch (_) {}
      }
    }
    if (totalBytes < 1024 * 1024) {
      return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    } else if (totalBytes < 1024 * 1024 * 1024) {
      return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  PopupMenuItem<LibrarySortOption> _buildSortMenuItem(
    BuildContext context,
    LibrarySortOption option,
    String title,
    IconData icon,
  ) {
    final isSelected = _currentSort == option;
    return PopupMenuItem<LibrarySortOption>(
      value: option,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? context.themeAccentColor : context.themeMutedTextColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                color: isSelected ? context.themeAccentColor : context.themeTextColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          if (isSelected)
            Icon(Icons.check_rounded, size: 16, color: context.themeAccentColor),
        ],
      ),
    );
  }

  Widget _buildSongListView(
    List<Song> songs,
    AudioPlayerState playerProvider,
    String emptyMessage, {
    bool isDownloadsTab = false,
    DownloadState? downloadState,
  }) {
    if (songs.isEmpty) {
      IconData iconData = Icons.music_note_rounded;
      if (emptyMessage.contains("favorite")) iconData = Icons.favorite_border_rounded;
      if (emptyMessage.contains("download")) iconData = Icons.download_done_rounded;
      
      return Column(
        children: [
          if (isDownloadsTab) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.themeAccentColor,
                        side: BorderSide(color: context.themeAccentColor.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: (downloadState?.isScanning ?? false)
                          ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: context.themeAccentColor))
                          : const Icon(Icons.sync_rounded, size: 20),
                      label: Text(
                        (downloadState?.isScanning ?? false) ? "Scanning Device Storage..." : "Scan Device Storage for Downloads",
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      onPressed: (downloadState?.isScanning ?? false)
                          ? null
                          : () async {
                              final scanned = await ref.read(downloadProvider.notifier).scanAndSync();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Scan complete: Found ${scanned.length} downloaded tracks")),
                                );
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: PremiumEmptyState(
              icon: iconData,
              title: "It's empty here",
              message: emptyMessage,
              ctaText: "Discover Music",
              onCtaPressed: () {
                context.go('/search');
              },
            ),
          ),
        ],
      );
    }

    final processedSongs = _applySortAndFilter(songs);
    final durationStr = _formatTotalDuration(processedSongs);
    final sizeStr = isDownloadsTab ? _calculateDownloadsSize(processedSongs) : null;

    return Column(
      children: [
        // Action Bar: Play All, Shuffle, Sort, Search/Filter, Rescan
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search field (if active)
              if (_isSearching) ...[
                Container(
                  height: 44,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: context.themeCardColor.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.themeTextColor24),
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: GoogleFonts.inter(color: context.themeTextColor, fontSize: 14),
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      hintText: "Filter ${processedSongs.length} tracks...",
                      hintStyle: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: context.themeMutedTextColor, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, color: context.themeMutedTextColor, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],

              // Header Row: Count & Info | Search | Sort | Rescan
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${processedSongs.length} Tracks${durationStr.isNotEmpty ? ' • $durationStr' : ''}",
                          style: GoogleFonts.inter(
                            color: context.themeTextColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        if (sizeStr != null) ...[
                          Text(
                            "$sizeStr storage used",
                            style: GoogleFonts.inter(
                              color: context.themeMutedTextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Search toggle icon
                  IconButton(
                    icon: Icon(
                      _isSearching ? Icons.close_rounded : Icons.search_rounded,
                      color: _isSearching ? context.themeAccentColor : context.themeMutedTextColor,
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    tooltip: "Search in tab",
                    onPressed: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _searchQuery = '';
                          _searchController.clear();
                        }
                      });
                    },
                  ),

                  // Sort Menu
                  PopupMenuButton<LibrarySortOption>(
                    icon: Icon(Icons.sort_rounded, color: context.themeMutedTextColor, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    tooltip: "Sort songs",
                    color: context.themeSurfaceColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onSelected: (opt) {
                      setState(() => _currentSort = opt);
                    },
                    itemBuilder: (ctx) => [
                      _buildSortMenuItem(ctx, LibrarySortOption.dateAdded, "Date Added", Icons.calendar_today_rounded),
                      _buildSortMenuItem(ctx, LibrarySortOption.titleAsc, "Title (A - Z)", Icons.sort_by_alpha_rounded),
                      _buildSortMenuItem(ctx, LibrarySortOption.titleDesc, "Title (Z - A)", Icons.sort_by_alpha_rounded),
                      _buildSortMenuItem(ctx, LibrarySortOption.artistAsc, "Artist (A - Z)", Icons.person_outline_rounded),
                      _buildSortMenuItem(ctx, LibrarySortOption.duration, "Duration", Icons.timer_outlined),
                    ],
                  ),

                  // Downloads Tab Rescan button
                  if (isDownloadsTab) ...[
                    IconButton(
                      icon: (downloadState?.isScanning ?? false)
                          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: context.themeAccentColor))
                          : Icon(Icons.sync_rounded, color: context.themeAccentColor, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      tooltip: "Rescan Device Storage for Downloads",
                      onPressed: (downloadState?.isScanning ?? false)
                          ? null
                          : () async {
                              final scanned = await ref.read(downloadProvider.notifier).scanAndSync();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Scan complete: Found ${scanned.length} downloaded tracks on device")),
                                );
                              }
                            },
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 10),

              // Action Buttons Row: Play All & Shuffle Play
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.themeAccentColor,
                        foregroundColor: context.themeInvertedTextColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: Text(
                        "Play All",
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      onPressed: processedSongs.isNotEmpty
                          ? () {
                              ref.read(audioPlayerProvider.notifier).playSong(
                                    processedSongs[0],
                                    queue: processedSongs,
                                    index: 0,
                                  );
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: context.themeCardColor.withValues(alpha: 0.5),
                        foregroundColor: context.themeTextColor,
                        side: BorderSide(color: context.themeTextColor24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.shuffle_rounded, size: 20),
                      label: Text(
                        "Shuffle",
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      onPressed: processedSongs.isNotEmpty
                          ? () {
                              final shuffled = List<Song>.from(processedSongs)..shuffle();
                              ref.read(audioPlayerProvider.notifier).playSong(
                                    shuffled[0],
                                    queue: shuffled,
                                    index: 0,
                                  );
                            }
                          : null,
                    ),
                  ),
                ],
              ),

              // Missing Details Restoration Banner (Downloads Tab)
              if (isDownloadsTab && ((downloadState?.missingDetailsCount ?? 0) > 0 || (downloadState?.isRestoring ?? false))) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.themeAccentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.themeAccentColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_fix_high_rounded, color: context.themeAccentColor, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (downloadState?.isRestoring ?? false)
                                  ? (downloadState?.restorationStatus ?? "Restoring metadata...")
                                  : "${downloadState!.missingDetailsCount} songs missing artwork or details",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.themeTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (downloadState?.isRestoring ?? false) ...[
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (downloadState?.restorationProgress ?? 0) > 0 ? downloadState!.restorationProgress : null,
                                  backgroundColor: context.themeAccentColor.withValues(alpha: 0.2),
                                  valueColor: AlwaysStoppedAnimation(context.themeAccentColor),
                                  minHeight: 4,
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 2),
                              Text(
                                "Recover album art, titles, and lyrics from JioSaavn",
                                style: GoogleFonts.inter(fontSize: 11, color: context.themeMutedTextColor),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!(downloadState?.isRestoring ?? false))
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.themeAccentColor,
                            foregroundColor: context.themeInvertedTextColor,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            elevation: 0,
                          ),
                          onPressed: () {
                            ref.read(downloadProvider.notifier).restoreMissingMetadata();
                          },
                          child: Text("Fix All", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Song List View
        Expanded(
          child: processedSongs.isEmpty
              ? Center(
                  child: Text(
                    "No tracks match '$_searchQuery'",
                    style: GoogleFonts.inter(color: context.themeMutedTextColor),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  itemCount: processedSongs.length,
                  itemBuilder: (context, index) {
                    final song = processedSongs[index];
                    final isPlaying = playerProvider.currentSong?.id == song.id && playerProvider.isPlaying;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: isPlaying
                            ? context.themeAccentColor.withValues(alpha: 0.12)
                            : context.themeCardColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Stack(
                                children: [
                                  song.coverArt.isNotEmpty
                                      ? CustomImageWidget(imageUrl: song.coverArt, fit: BoxFit.cover, width: 48, height: 48)
                                      : Container(
                                          color: context.themeCardColor,
                                          child: Icon(Icons.music_note, color: context.themeTextColor),
                                        ),
                                  if (isPlaying)
                                    Container(
                                      color: Colors.black45,
                                      child: Center(
                                        child: Icon(Icons.equalizer_rounded, color: context.themeAccentColor, size: 24),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: isPlaying ? context.themeAccentColor : context.themeTextColor,
                              fontWeight: isPlaying ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              if (isDownloadsTab) ...[
                                Icon(Icons.download_done_rounded, size: 13, color: context.themeAccentColor),
                                const SizedBox(width: 4),
                              ],
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
                              if (song.duration > 0) ...[
                                Text(
                                  DownloadService.formatDuration(song.duration),
                                  style: GoogleFonts.inter(
                                    color: context.themeMutedTextColor,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.more_vert, color: context.themeMutedTextColor),
                            onPressed: () {
                              SongOptionsSheet.show(context, song, playlistContext: processedSongs);
                            },
                          ),
                          onTap: () {
                            ref.read(audioPlayerProvider.notifier).playSong(song, queue: processedSongs, index: index);
                          },
                          onLongPress: () {
                            SongOptionsSheet.show(context, song, playlistContext: processedSongs);
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
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
