import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/data/services/deezer_api_service.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/core/widgets/skeleton_loading_list.dart';
import 'package:it_feels_music/core/widgets/song_options_sheet.dart';
import 'package:it_feels_music/core/widgets/animated_equalizer.dart';
import 'package:it_feels_music/core/widgets/hoverable_link.dart';
import 'package:it_feels_music/features/library/artist_detail_screen.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  bool _isLoading = true;
  String _title = '';
  String _coverArt = '';
  List<Song> _songs = [];

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (widget.playlist.songs != null && widget.playlist.songs!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _title = widget.playlist.title;
          _coverArt = widget.playlist.coverArt;
          _songs = widget.playlist.songs!;
          _isLoading = false;
        });
      }
      return;
    }

    Map<String, dynamic> data;

    if (widget.playlist.id.startsWith('dz_')) {
      final dzApi = DeezerApiService();
      final dzId = widget.playlist.id.replaceFirst('dz_', '');
      data = await dzApi.fetchPlaylistDetails(dzId);
    } else {
      final api = MusicApiService();
      if (widget.playlist.type == 'album') {
        data = await api.fetchAlbumDetails(widget.playlist.id);
      } else {
        data = await api.fetchPlaylistDetails(widget.playlist.id);
      }
    }

    if (mounted) {
      setState(() {
        _title = data['name'] ?? widget.playlist.title;
        _coverArt = (data['image'] as String?)?.isNotEmpty == true
            ? data['image']
            : widget.playlist.coverArt;
        _songs = List<Song>.from(data['songs'] ?? []);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = ref.read(audioPlayerProvider);
    final downloadProv = ref.watch(downloadProvider);

    return Scaffold(
      backgroundColor: context.themeBackgroundColor,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            _isLoading
                ? const SkeletonLoadingList()
                : CustomScrollView(
                    slivers: [
                  // Back Button
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    pinned: true,
                    leading: Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_rounded, color: context.themeTextColor, size: 28),
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ),
                  ),
                  // Immersive Dynamic Header
                  SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 700;
                        final horizontalPadding = isWide ? (constraints.maxWidth > 1400 ? (constraints.maxWidth - 1400) / 2 : 48.0) : 32.0;

                        return Padding(
                          padding: EdgeInsets.only(left: horizontalPadding, right: horizontalPadding, top: 32, bottom: 40),
                          child: isWide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    // Massive left-aligned cover art
                                    Container(
                                      width: 320,
                                      height: 320,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.5),
                                            blurRadius: 50,
                                            offset: const Offset(0, 24),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: _coverArt.isNotEmpty
                                            ? CustomImageWidget(imageUrl: _coverArt, fit: BoxFit.cover)
                                            : Container(color: context.themeCardColor),
                                      ),
                                    ),
                                    const SizedBox(width: 48),
                                    // Typography and Actions
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            "PLAYLIST",
                                            style: GoogleFonts.inter(
                                              color: context.themeMutedTextColor,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 2.0,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            _title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.outfit(
                                              fontSize: 64,
                                              fontWeight: FontWeight.w900,
                                              color: context.themeTextColor,
                                              height: 1.05,
                                              letterSpacing: -1.0,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            "It Feels Music • ${_songs.length} Tracks",
                                            style: GoogleFonts.inter(
                                              color: context.themeMutedTextColor,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 32),
                                          Row(
                                            children: [
                                              _buildActionButton(
                                                context: context,
                                                icon: Icons.play_arrow_rounded,
                                                label: "Play",
                                                onPressed: () {
                                                  if (_songs.isNotEmpty) ref.read(audioPlayerProvider.notifier).playSong(_songs[0], queue: _songs, index: 0);
                                                },
                                              ),
                                              const SizedBox(width: 16),
                                              _buildActionButton(
                                                context: context,
                                                icon: Icons.shuffle_rounded,
                                                label: "Shuffle",
                                                onPressed: () {
                                                  if (_songs.isNotEmpty) {
                                                    final shuffled = List<Song>.from(_songs)..shuffle();
                                                    ref.read(audioPlayerProvider.notifier).playSong(shuffled[0], queue: shuffled, index: 0);
                                                  }
                                                },
                                              ),
                                              const SizedBox(width: 16),
                                              IconButton(
                                                onPressed: () async {
                                                  if (_songs.isEmpty) return;
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text("Downloading ${_songs.length} songs...")),
                                                  );
                                                  await ref.read(downloadProvider.notifier).downloadBatch(_songs);
                                                },
                                                icon: Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: context.themeCardColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(Icons.download_rounded, color: context.themeAccentColor, size: 22),
                                                ),
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  // Mobile centered fallback
                                  children: [
                                    Container(
                                      width: 240,
                                      height: 240,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.4),
                                            blurRadius: 40,
                                            offset: const Offset(0, 20),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: _coverArt.isNotEmpty
                                            ? CustomImageWidget(imageUrl: _coverArt, fit: BoxFit.cover)
                                            : Container(color: context.themeCardColor),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      _title,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      style: GoogleFonts.outfit(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        color: context.themeTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "${_songs.length} Tracks",
                                      style: GoogleFonts.inter(
                                        color: context.themeMutedTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _buildActionButton(
                                          context: context,
                                          icon: Icons.play_arrow_rounded,
                                          label: "Play",
                                          onPressed: () {
                                            if (_songs.isNotEmpty) ref.read(audioPlayerProvider.notifier).playSong(_songs[0], queue: _songs, index: 0);
                                          },
                                        ),
                                        const SizedBox(width: 12),
                                        _buildActionButton(
                                          context: context,
                                          icon: Icons.shuffle_rounded,
                                          label: "Shuffle",
                                          onPressed: () {
                                            if (_songs.isNotEmpty) {
                                              final shuffled = List<Song>.from(_songs)..shuffle();
                                              ref.read(audioPlayerProvider.notifier).playSong(shuffled[0], queue: shuffled, index: 0);
                                            }
                                          },
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                        );
                      },
                    ),
                  ),

                  // Table Header
                  SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 700;
                        final horizontalPadding = isWide ? (constraints.maxWidth > 1400 ? (constraints.maxWidth - 1400) / 2 : 48.0) : 32.0;
                        
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                child: Text(
                                  "#",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 6,
                                child: Text(
                                  "Title",
                                  style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  "Artist",
                                  style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  "Album",
                                  style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                              SizedBox(
                                width: 60,
                                child: Icon(Icons.access_time_rounded, size: 16, color: context.themeMutedTextColor),
                              ),
                              const SizedBox(width: 60), // Actions spacing
                            ],
                          ),
                        );
                      }
                    ),
                  ),

                  // Divider
                  SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 700;
                        final horizontalPadding = isWide ? (constraints.maxWidth > 1400 ? (constraints.maxWidth - 1400) / 2 : 48.0) : 32.0;
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                          child: Divider(color: context.themeMutedTextColor.withValues(alpha: 0.2), height: 1),
                        );
                      }
                    ),
                  ),

                  // Songs List
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = _songs[index];
                        final isDown = downloadProv.isDownloaded(song.id);
                        final screenWidth = MediaQuery.of(context).size.width;
                        final isWide = screenWidth >= 700;
                        final horizontalPadding = isWide ? (screenWidth > 1400 ? (screenWidth - 1400) / 2 : 48.0) : 16.0;
                        
                        final artists = song.artist.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                        final minutes = song.duration ~/ 60;
                        final seconds = song.duration % 60;
                        final timeString = '$minutes:${seconds.toString().padLeft(2, '0')}';

                        return Consumer(
                          builder: (context, ref, child) {
                            final playerProvider = ref.watch(audioPlayerProvider);
                            final isCurrentSong = playerProvider.currentSong?.id == song.id;
                            
                            return Padding(
                              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 2),
                              child: InkWell(
                                onTap: () => ref.read(audioPlayerProvider.notifier).playSong(song, queue: _songs, index: index),
                                onLongPress: () => SongOptionsSheet.show(context, song, playlistContext: _songs),
                                borderRadius: BorderRadius.circular(8),
                                hoverColor: Colors.white.withValues(alpha: 0.05),
                                highlightColor: Colors.white.withValues(alpha: 0.1),
                                splashColor: Colors.transparent,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      // Track Number / Equalizer
                                      SizedBox(
                                        width: 40,
                                        child: Center(
                                          child: isCurrentSong && playerProvider.isPlaying
                                              ? AnimatedEqualizer(color: context.themeAccentColor)
                                              : Text(
                                                  "${index + 1}",
                                                  style: GoogleFonts.inter(
                                                    color: isCurrentSong ? context.themeAccentColor : context.themeMutedTextColor,
                                                    fontSize: 14,
                                                    fontWeight: isCurrentSong ? FontWeight.w700 : FontWeight.w500,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Title Column
                                      Expanded(
                                        flex: 6,
                                        child: Row(
                                          children: [
                                            // Optional mini thumbnail
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: SizedBox(
                                                width: 42,
                                                height: 42,
                                                child: song.coverArt.isNotEmpty
                                                    ? CustomImageWidget(imageUrl: song.coverArt, fit: BoxFit.cover, size: 100)
                                                    : Container(color: context.themeCardColor),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Text(
                                                song.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                  color: isCurrentSong ? context.themeAccentColor : context.themeTextColor,
                                                  fontWeight: isCurrentSong ? FontWeight.w700 : FontWeight.w500,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Artist Column
                                      Expanded(
                                        flex: 4,
                                        child: artists.isEmpty
                                          ? Text(
                                              song.artist,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                color: context.themeMutedTextColor,
                                                fontSize: 15,
                                              ),
                                            )
                                          : SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              physics: const NeverScrollableScrollPhysics(), // Only used to prevent vertical overflow error, ellipsis handled below ideally, but since we map widgets we just let it truncate if we had a wrap, but Row with ellipsis is tricky. Let's just build text spans if we wanted pure ellipsis, but for now scrolling disabled row is fine. Actually, a Wrap is better.
                                              child: Wrap(
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                children: artists.asMap().entries.map((entry) {
                                                  final isLast = entry.key == artists.length - 1;
                                                  return Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      HoverableLink(
                                                        text: entry.value,
                                                        style: GoogleFonts.inter(fontSize: 15),
                                                        onTap: () {
                                                          Navigator.push(context, MaterialPageRoute(builder: (_) => ArtistDetailScreen(artistName: entry.value)));
                                                        },
                                                      ),
                                                      if (!isLast) Text(", ", style: GoogleFonts.inter(color: context.themeMutedTextColor.withValues(alpha: 0.6), fontSize: 15)),
                                                    ],
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                      ),
                                      // Album Column
                                      Expanded(
                                        flex: 3,
                                        child: song.album.isNotEmpty 
                                          ? HoverableLink(
                                              text: song.album,
                                              style: GoogleFonts.inter(fontSize: 15),
                                              onTap: () async {
                                                showDialog(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  barrierColor: Colors.black.withOpacity(0.5),
                                                  builder: (_) => const Center(child: CircularProgressIndicator()),
                                                );
                                                try {
                                                  final albums = await MusicApiService().searchAlbums(song.album, count: 1);
                                                  if (context.mounted) {
                                                    Navigator.of(context, rootNavigator: true).pop();
                                                    if (albums.isNotEmpty) {
                                                      Navigator.push(context, MaterialPageRoute(builder: (_) => PlaylistDetailScreen(playlist: albums.first)));
                                                    } else {
                                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Album not found")));
                                                    }
                                                  }
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    Navigator.of(context, rootNavigator: true).pop();
                                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error loading album")));
                                                  }
                                                }
                                              },
                                            )
                                          : const SizedBox.shrink(),
                                      ),
                                      // Time Column
                                      SizedBox(
                                        width: 60,
                                        child: Text(
                                          timeString,
                                          style: GoogleFonts.inter(
                                            color: context.themeMutedTextColor,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      // Action / Download
                                      SizedBox(
                                        width: 60,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            if (isDown)
                                              Icon(Icons.download_done_rounded, color: context.themeAccentColor, size: 16),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () => SongOptionsSheet.show(context, song, playlistContext: _songs),
                                              child: Icon(Icons.more_horiz_rounded, color: context.themeMutedTextColor, size: 20),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                      childCount: _songs.length,
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 48)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 140,
      height: 36,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: context.themeCardColor.withValues(alpha: 0.8),
          foregroundColor: context.themeTextColor,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon, size: 18, color: context.themeAccentColor),
        label: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
        onPressed: onPressed,
      ),
    );
  }
}
