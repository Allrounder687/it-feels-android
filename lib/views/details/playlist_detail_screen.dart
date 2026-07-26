import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/song_model.dart';
import '../../data/services/jiosaavn_api_service.dart';
import '../../providers/audio_player_provider.dart';

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
    final api = JioSaavnApiService();
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

    return Scaffold(
      backgroundColor: AppColors.midnightBackground,
      body: SafeArea(
        child: _isLoading
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
                              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
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
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ),

                  // Header Artwork, Title & Play All / Shuffle Buttons
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
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: _coverArt.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: _coverArt,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(color: AppColors.midnightCard),
                            ),
                          ),
                          const SizedBox(height: 16),

                          Text(
                            _title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${_songs.length} Tracks",
                            style: GoogleFonts.inter(
                              color: AppColors.midnightTextMuted,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Play All & Shuffle Buttons Row
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
                                  "Play All",
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                                ),
                                onPressed: () {
                                  if (_songs.isNotEmpty) {
                                    playerProvider.playSong(_songs[0], queue: _songs, index: 0);
                                  }
                                },
                              ),
                              const SizedBox(width: 14),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.midnightPill,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          child: Material(
                            color: AppColors.midnightCard.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: song.coverArt.isNotEmpty
                                      ? CachedNetworkImage(
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
                              trailing: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                              onTap: () {
                                playerProvider.playSong(song, queue: _songs, index: index);
                              },
                            ),
                          ),
                        );
                      },
                      childCount: _songs.length,
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
      ),
    );
  }
}
