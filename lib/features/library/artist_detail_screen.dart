import 'dart:ui';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/features/library/playlist_detail_screen.dart';
import 'package:it_feels_music/core/widgets/song_options_sheet.dart';
import 'package:it_feels_music/core/widgets/mini_player.dart';
import 'package:it_feels_music/features/player/now_playing_screen.dart';
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
  List<dynamic> _albums = [];

  @override
  void initState() {
    super.initState();
    _loadArtistData();
  }

  Future<void> _loadArtistData() async {
    final api = MusicApiService();
    
    String? finalArtistId = widget.artistId;
    if (finalArtistId == null || finalArtistId.isEmpty) {
      final searchRes = await api.searchAll(widget.artistName);
      if (searchRes['artists'] != null && (searchRes['artists'] as List).isNotEmpty) {
        finalArtistId = searchRes['artists'][0]['id']?.toString();
      }
    }

    List<Song> topSongs = [];
    List<dynamic> albums = [];

    if (finalArtistId != null && finalArtistId.isNotEmpty) {
      final artistData = await api.fetchArtistDetails(finalArtistId);
      topSongs = artistData['topSongs'] as List<Song>? ?? [];
      albums = artistData['albums'] as List<dynamic>? ?? [];
    } else {
      topSongs = await api.searchSongs(widget.artistName, count: 50);
      albums = await api.searchAlbums(widget.artistName, count: 20);
    }

    if (mounted) {
      setState(() {
        _topSongs = topSongs;
        _albums = albums;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = ref.read(audioPlayerProvider);

    return Scaffold(
      backgroundColor: context.themeBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.midnightAccent))
            : CustomScrollView(
                slivers: [
                  // Immersive Dynamic Header
                  SliverAppBar(
                    expandedHeight: 340,
                    pinned: true,
                    backgroundColor: context.themeBackgroundColor,
                    leading: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.themeBackgroundColor.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_back, color: context.themeTextColor, size: 20),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    flexibleSpace: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final top = constraints.biggest.height;
                        final minHeight = MediaQuery.of(context).padding.top + kToolbarHeight;
                        final scrollPercent = ((top - minHeight) / (340 - minHeight)).clamp(0.0, 1.0);
                        final isCollapsed = top <= minHeight + 20;

                        return FlexibleSpaceBar(
                          titlePadding: const EdgeInsets.only(left: 64, right: 64, bottom: 16),
                          title: isCollapsed
                              ? Text(
                                  widget.artistName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: context.themeTextColor,
                                  ),
                                )
                              : const SizedBox.shrink(),
                          background: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Blurred Artist Image Background
                              if (widget.artistImage?.isNotEmpty == true)
                                ImageFiltered(
                                  imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                                  child: CustomImageWidget(
                                    imageUrl: widget.artistImage!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              Positioned.fill(
                                child: Container(color: context.themeBackgroundColor.withValues(alpha: 0.7)),
                              ),
                              // Foreground Avatar and Text
                              Opacity(
                                opacity: scrollPercent,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      width: 140,
                                      height: 140,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.4),
                                            blurRadius: 30,
                                            offset: const Offset(0, 15),
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: widget.artistImage?.isNotEmpty == true
                                            ? CustomImageWidget(imageUrl: widget.artistImage!, fit: BoxFit.cover)
                                            : Container(color: context.themeCardColor, child: Icon(Icons.person, color: context.themeTextColor, size: 60)),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      child: Text(
                                        widget.artistName,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: context.themeTextColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Verified Artist",
                                      style: GoogleFonts.inter(
                                        color: context.themeAccentColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Play Buttons Apple Music Style
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.themeCardColor.withValues(alpha: 0.8),
                                foregroundColor: context.themeTextColor,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: Icon(Icons.play_arrow_rounded, size: 24, color: context.themeAccentColor),
                              label: Text("Play Top Songs", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                              onPressed: () {
                                if (_topSongs.isNotEmpty) ref.read(audioPlayerProvider.notifier).playSong(_topSongs[0], queue: _topSongs, index: 0);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top Songs Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 8),
                      child: Text(
                        "Top Songs",
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: context.themeTextColor,
                        ),
                      ),
                    ),
                  ),

                  // Top Songs List
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = _topSongs[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
                              subtitle: Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: context.themeMutedTextColor,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.more_vert, color: context.themeMutedTextColor),
                                onPressed: () {
                                  SongOptionsSheet.show(context, song, playlistContext: _topSongs);
                                },
                              ),
                              onTap: () {
                                ref.read(audioPlayerProvider.notifier).playSong(song, queue: _topSongs, index: index);
                              },
                              onLongPress: () {
                                SongOptionsSheet.show(context, song, playlistContext: _topSongs);
                              },
                            ),
                          ),
                        );
                      },
                      childCount: _topSongs.length,
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

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
      ),
    );
  }
}
