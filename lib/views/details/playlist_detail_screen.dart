import 'package:it_feels_music/views/widgets/custom_image_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/song_model.dart';
import '../../data/services/music_api_service.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/download_provider.dart';
import '../widgets/song_options_sheet.dart';
import '../widgets/animated_equalizer.dart';
import '../widgets/mini_player.dart';
import '../player/now_playing_screen.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
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
    final api = MusicApiService();
    Map<String, dynamic> data;

    if (widget.playlist.type == 'album') {
      data = await api.fetchAlbumDetails(widget.playlist.id);
    } else {
      data = await api.fetchPlaylistDetails(widget.playlist.id);
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
    final playerProvider = Provider.of<AudioPlayerProvider>(context, listen: false);
    final downloadProvider = Provider.of<DownloadProvider>(context);

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
        top: false,
        child: Stack(
          children: [
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.midnightAccent))
                : CustomScrollView(
                    slivers: [
                  // App Bar with Back Button
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
                              _title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: context.themeTextColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ),

                  // Header Artwork, Title & Play All / Shuffle / Download Buttons
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Large Artwork Card
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: context.themeInvertedTextColor.withValues(alpha: 0.4),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: _coverArt.isNotEmpty
                                  ? CustomImageWidget(
                                      imageUrl: _coverArt,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(color: context.themeCardColor),
                            ),
                          ),
                          const SizedBox(height: 16),

                          Text(
                            _title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: context.themeTextColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${_songs.length} Tracks",
                            style: GoogleFonts.inter(
                              color: context.themeMutedTextColor,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Play All, Shuffle & Download Buttons Row
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: context.themeAccentColor,
                                  foregroundColor: context.themeInvertedTextColor,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                                label: Text(
                                  "Play All",
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                                ),
                                onPressed: () {
                                  if (_songs.isNotEmpty) {
                                    playerProvider.playSong(_songs[0], queue: _songs, index: 0);
                                  }
                                },
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.midnightPill,
                                  foregroundColor: context.themeTextColor,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                icon: const Icon(Icons.shuffle_rounded, size: 20),
                                label: Text(
                                  "Shuffle",
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                                ),
                                onPressed: () {
                                  if (_songs.isNotEmpty) {
                                    final shuffled = List<Song>.from(_songs)..shuffle();
                                    playerProvider.playSong(shuffled[0], queue: shuffled, index: 0);
                                  }
                                },
                              ),
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.midnightPill,
                                  padding: const EdgeInsets.all(12),
                                ),
                                icon: Icon(Icons.file_download_outlined, color: context.themeTextColor),
                                tooltip: "Download All",
                                onPressed: () async {
                                  if (_songs.isEmpty) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Downloading ${_songs.length} songs...")),
                                  );
                                  await downloadProvider.downloadBatch(_songs);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Batch download completed!")),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Songs List
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = _songs[index];
                        final isDown = downloadProvider.isDownloaded(song.id);

                        return Consumer<AudioPlayerProvider>(
                          builder: (context, playerProvider, child) {
                            final isCurrentSong = playerProvider.currentSong?.id == song.id;

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          child: Material(
                            color: context.themeCardColor.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            clipBehavior: Clip.antiAlias,
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
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      song.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: isCurrentSong ? context.themeAccentColor : context.themeTextColor,
                                        fontWeight: isCurrentSong ? FontWeight.w800 : FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (isDown) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.download_done_rounded, color: context.themeAccentColor, size: 16),
                                  ],
                                ],
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
                              trailing: isCurrentSong && playerProvider.isPlaying
                                  ? Padding(
                                      padding: EdgeInsets.only(right: 12.0),
                                      child: AnimatedEqualizer(color: context.themeAccentColor),
                                    )
                                  : IconButton(
                                      icon: Icon(Icons.more_vert, color: context.themeMutedTextColor),
                                      onPressed: () {
                                        SongOptionsSheet.show(context, song, playlistContext: _songs);
                                      },
                                    ),
                              onTap: () {
                                playerProvider.playSong(song, queue: _songs, index: index);
                              },
                              onLongPress: () {
                                SongOptionsSheet.show(context, song, playlistContext: _songs);
                              },
                            ),
                          ),
                        );
                          },
                        );
                      },
                      childCount: _songs.length,
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
