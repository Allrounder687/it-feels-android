import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:it_feels_music/core/widgets/skeleton_loading_list.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/features/library/playlist_detail_screen.dart';
import 'package:it_feels_music/core/widgets/song_options_sheet.dart';
import 'package:it_feels_music/core/widgets/animated_equalizer.dart';
import 'package:it_feels_music/core/widgets/hoverable_link.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

class ArtistDetailScreen extends ConsumerStatefulWidget {
  final String artistName;
  final String? artistImage;
  final String? artistId;

  const ArtistDetailScreen({
    super.key,
    required this.artistName,
    this.artistImage,
    this.artistId,
  });

  @override
  ConsumerState<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends ConsumerState<ArtistDetailScreen> {
  bool _isLoading = true;
  List<Song> _topSongs = [];
  List<Song> _allSongs = [];
  List<dynamic> _albums = [];
  String _artistImage = '';
  bool _showingAllSongs = false;

  @override
  void initState() {
    super.initState();
    _loadArtistData();
  }

  Future<void> _loadArtistData() async {
    final api = MusicApiService();
    
    String? finalArtistId = widget.artistId;
    String? fetchedImage = widget.artistImage;

    // Resolve missing ID or missing image
    if (finalArtistId == null || finalArtistId.isEmpty || fetchedImage == null || fetchedImage.isEmpty) {
      final searchRes = await api.searchAll(widget.artistName);
      if (searchRes['artists'] != null && (searchRes['artists'] as List).isNotEmpty) {
        final artistsList = List<Map<String, dynamic>>.from(searchRes['artists']);
        final artistObj = artistsList.firstWhere(
            (a) => a['title'].toString().toLowerCase() == widget.artistName.toLowerCase(),
            orElse: () => artistsList.first);
            
        finalArtistId ??= artistObj['id']?.toString();
        fetchedImage ??= artistObj['image']?.toString();
      }
    }

    List<Song> topSongs = [];
    List<dynamic> albums = [];

    if (finalArtistId != null && finalArtistId.isNotEmpty) {
      final artistData = await api.fetchArtistDetails(finalArtistId);
      topSongs = artistData['topSongs'] as List<Song>? ?? [];
      albums = artistData['albums'] as List<dynamic>? ?? [];
      if (fetchedImage == null || fetchedImage.isEmpty) {
        fetchedImage = artistData['image'] as String?;
      }
    } 
    
    // Fetch the massive tracklist for the deep discography view with Deduplication
    List<Song> allSongs = [];
    final Set<String> seenTitles = {};
    
    // Fetch up to 5 pages (250 tracks) to bypass hard limits
    for (int page = 1; page <= 5; page++) {
      final pageSongs = await api.searchSongs(widget.artistName, page: page, count: 50);
      for (var song in pageSongs) {
        final normalizedTitle = song.title.trim().toLowerCase();
        if (!seenTitles.contains(normalizedTitle)) {
          seenTitles.add(normalizedTitle);
          allSongs.add(song);
        }
      }
      if (pageSongs.length < 50) break; // Reached end of results
    }
    
    if (topSongs.isEmpty) {
      topSongs = allSongs.take(10).toList();
    }
    if (albums.isEmpty) {
      albums = await api.searchAlbums(widget.artistName, count: 20);
    }

    // Ultimate fallback for missing artist image: grab from top album or song
    if (fetchedImage == null || fetchedImage.isEmpty || fetchedImage.contains('default')) {
      if (albums.isNotEmpty) fetchedImage = albums.first.coverArt;
      else if (allSongs.isNotEmpty) fetchedImage = allSongs.first.coverArt;
    }

    if (mounted) {
      setState(() {
        _topSongs = topSongs.isNotEmpty ? topSongs.take(10).toList() : allSongs.take(10).toList();
        _allSongs = allSongs;
        _albums = albums;
        _artistImage = fetchedImage ?? '';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.themeBackgroundColor,
      body: SafeArea(
        child: _isLoading
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
                                    // Massive left-aligned avatar
                                    Container(
                                      width: 320,
                                      height: 320,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.5),
                                            blurRadius: 50,
                                            offset: const Offset(0, 24),
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: _artistImage.isNotEmpty
                                            ? CustomImageWidget(imageUrl: _artistImage, fit: BoxFit.cover)
                                            : Container(color: context.themeCardColor, child: Icon(Icons.person, color: context.themeTextColor, size: 80)),
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
                                            "ARTIST",
                                            style: GoogleFonts.inter(
                                              color: context.themeMutedTextColor,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 2.0,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            widget.artistName,
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
                                          Row(
                                            children: [
                                              Icon(Icons.verified, color: context.themeAccentColor, size: 18),
                                              const SizedBox(width: 8),
                                              Text(
                                                "Verified Artist",
                                                style: GoogleFonts.inter(
                                                  color: context.themeMutedTextColor,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 32),
                                          Row(
                                            children: [
                                              _buildActionButton(
                                                context: context,
                                                icon: Icons.play_arrow_rounded,
                                                label: "Play",
                                                onPressed: () {
                                                  if (_topSongs.isNotEmpty) ref.read(audioPlayerProvider.notifier).playSong(_topSongs[0], queue: _topSongs, index: 0);
                                                },
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
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.4),
                                            blurRadius: 40,
                                            offset: const Offset(0, 20),
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: widget.artistImage?.isNotEmpty == true
                                            ? CustomImageWidget(imageUrl: widget.artistImage!, fit: BoxFit.cover)
                                            : Container(color: context.themeCardColor, child: Icon(Icons.person, color: context.themeTextColor, size: 80)),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      widget.artistName,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      style: GoogleFonts.outfit(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        color: context.themeTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.verified, color: context.themeAccentColor, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Verified Artist",
                                          style: GoogleFonts.inter(
                                            color: context.themeMutedTextColor,
                                          ),
                                        ),
                                      ],
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
                                            if (_topSongs.isNotEmpty) ref.read(audioPlayerProvider.notifier).playSong(_topSongs[0], queue: _topSongs, index: 0);
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

                  // Top Songs Header
                  SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 700;
                        final horizontalPadding = isWide ? (constraints.maxWidth > 1400 ? (constraints.maxWidth - 1400) / 2 : 48.0) : 32.0;
                        return Padding(
                          padding: EdgeInsets.only(left: horizontalPadding, right: horizontalPadding, top: 12, bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _showingAllSongs ? "All Songs" : "Top Songs",
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: context.themeTextColor,
                                ),
                              ),
                              if (_allSongs.length > 10)
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _showingAllSongs = !_showingAllSongs;
                                    });
                                  },
                                  child: Text(
                                    _showingAllSongs ? "Show Less" : "See All Songs",
                                    style: GoogleFonts.inter(
                                      color: context.themeAccentColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }
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
                        final displaySongs = _showingAllSongs ? _allSongs : _topSongs;
                        final song = displaySongs[index];
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
                                onTap: () => ref.read(audioPlayerProvider.notifier).playSong(song, queue: displaySongs, index: index),
                                onLongPress: () => SongOptionsSheet.show(context, song, playlistContext: displaySongs),
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
                                              physics: const NeverScrollableScrollPhysics(),
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
                                                          // Optional: maybe check if we're already on this artist's page before pushing again.
                                                          if (widget.artistName != entry.value) {
                                                            Navigator.push(context, MaterialPageRoute(builder: (_) => ArtistDetailScreen(artistName: entry.value)));
                                                          }
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
                                      // Action
                                      SizedBox(
                                        width: 60,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            InkWell(
                                              onTap: () => SongOptionsSheet.show(context, song, playlistContext: displaySongs),
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
                      childCount: _showingAllSongs ? _allSongs.length : _topSongs.length,
                    ),
                  ),

                  // Albums Section Header
                  if (_albums.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8),
                        child: Text(
                          "Albums & Discography",
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: context.themeTextColor,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 170,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _albums.length,
                          itemBuilder: (context, index) {
                            final album = _albums[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PlaylistDetailScreen(playlist: album),
                                  ),
                                );
                              },
                              child: Container(
                                width: 130,
                                margin: const EdgeInsets.only(right: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: AspectRatio(
                                        aspectRatio: 1.0,
                                        child: album.coverArt.isNotEmpty
                                            ? CustomImageWidget(
                                                imageUrl: album.coverArt,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(color: context.themeCardColor),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      album.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: context.themeTextColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
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
