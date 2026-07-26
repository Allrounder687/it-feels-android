import 'package:pixel_player_saavn/views/widgets/custom_image_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/song_model.dart';
import '../../data/services/jiosaavn_api_service.dart';
import '../../providers/audio_player_provider.dart';
import 'playlist_detail_screen.dart';

import '../widgets/song_options_sheet.dart';

class ArtistDetailScreen extends StatefulWidget {
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
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  bool _isLoading = true;
  List<Song> _topSongs = [];
  List<Playlist> _albums = [];

  @override
  void initState() {
    super.initState();
    _loadArtistData();
  }

  Future<void> _loadArtistData() async {
    final api = JioSaavnApiService();
    
    String? finalArtistId = widget.artistId;
    if (finalArtistId == null || finalArtistId.isEmpty) {
      final searchRes = await api.searchAll(widget.artistName);
      if (searchRes['artists'] != null && (searchRes['artists'] as List).isNotEmpty) {
        finalArtistId = searchRes['artists'][0]['id']?.toString();
      }
    }

    List<Song> topSongs = [];
    List<Playlist> albums = [];

    if (finalArtistId != null && finalArtistId.isNotEmpty) {
      final artistData = await api.fetchArtistDetails(finalArtistId);
      topSongs = artistData['topSongs'] as List<Song>? ?? [];
      albums = artistData['albums'] as List<Playlist>? ?? [];
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
    final playerProvider = Provider.of<AudioPlayerProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.midnightBackground,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.midnightAccent))
            : CustomScrollView(
                slivers: [
                  // App Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.midnightPill,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              widget.artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Header Artwork Avatar & Action Buttons
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Circular Artist Image Avatar
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: widget.artistImage?.isNotEmpty == true
                                  ? CustomImageWidget(
                                      imageUrl: widget.artistImage!,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: AppColors.midnightCard,
                                      child: const Icon(Icons.person, color: Colors.white, size: 64),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          Text(
                            widget.artistName,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Verified Artist",
                            style: GoogleFonts.inter(
                              color: AppColors.midnightPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Play & Shuffle Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.midnightPrimary,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                                label: Text(
                                  "Play Top Songs",
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                                ),
                                onPressed: () {
                                  if (_topSongs.isNotEmpty) {
                                    playerProvider.playSong(_topSongs[0], queue: _topSongs, index: 0);
                                  }
                                },
                              ),
                            ],
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
                          color: Colors.white,
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
                            color: AppColors.midnightCard.withValues(alpha: 0.5),
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
                                icon: const Icon(Icons.more_vert, color: Colors.white54),
                                onPressed: () {
                                  SongOptionsSheet.show(context, song, playlistContext: _topSongs);
                                },
                              ),
                              onTap: () {
                                playerProvider.playSong(song, queue: _topSongs, index: index);
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
                            color: Colors.white,
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
                                            : Container(color: AppColors.midnightCard),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      album.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
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

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
      ),
    );
  }
}
