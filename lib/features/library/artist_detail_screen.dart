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
      bottomNavigationBar: MiniPlayer(
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const NowPlayingScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                );
              },
            ),
          );
        },
      ),
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
                              child: Icon(Icons.arrow_back, color: context.themeTextColor, size: 20),
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
                                color: context.themeTextColor,
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
                                  color: context.themeInvertedTextColor.withValues(alpha: 0.4),
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
                                      color: context.themeCardColor,
                                      child: Icon(Icons.person, color: context.themeTextColor, size: 64),
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
                              color: context.themeTextColor,
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
                          const SizedBox(height: 20),

                          // Play & Shuffle Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: context.themeAccentColor,
                                  foregroundColor: context.themeInvertedTextColor,
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
                                    ref.read(audioPlayerProvider.notifier).playSong(_topSongs[0], queue: _topSongs, index: 0);
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
