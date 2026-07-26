import 'package:it_feels_music/views/widgets/custom_image_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/song_model.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/hidden_songs_provider.dart';
import '../../providers/custom_playlist_provider.dart';
import '../details/artist_detail_screen.dart';

class SongOptionsSheet extends StatelessWidget {
  final Song song;
  final List<Song>? playlistContext;

  const SongOptionsSheet({
    super.key,
    required this.song,
    this.playlistContext,
  });

  static void show(BuildContext context, Song song, {List<Song>? playlistContext}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SongOptionsSheet(song: song, playlistContext: playlistContext),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<AudioPlayerProvider>(context);
    final downloadProvider = Provider.of<DownloadProvider>(context);
    final hiddenProvider = Provider.of<HiddenSongsProvider>(context, listen: false);
    final customPlaylistProvider = Provider.of<CustomPlaylistProvider>(context, listen: false);

    final isFav = playerProvider.isFavorite(song.id);
    final isDown = downloadProvider.isDownloaded(song.id);
    final isDownloading = downloadProvider.isDownloading(song.id);

    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 28, left: 20, right: 20),
      decoration: BoxDecoration(
        color: AppColors.midnightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header: Track Thumbnail, Title, Artist
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: song.coverArt.isNotEmpty
                      ? CustomImageWidget(imageUrl: song.coverArt, fit: BoxFit.cover)
                      : Container(
                          color: AppColors.midnightCard,
                          child: const Icon(Icons.music_note, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.midnightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),

          // Action 1: Play Now
          _buildOptionTile(
            icon: Icons.play_circle_fill_rounded,
            iconColor: AppColors.midnightPrimary,
            title: "Play Now",
            onTap: () {
              Navigator.pop(context);
              playerProvider.playSong(song, queue: playlistContext ?? [song]);
            },
          ),

          // Action 2: Play Next
          _buildOptionTile(
            icon: Icons.playlist_play_rounded,
            iconColor: Colors.amberAccent,
            title: "Play Next",
            onTap: () {
              Navigator.pop(context);
              playerProvider.playNext(song);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Playing next: ${song.title}"),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),

          // Action 3: Add to Queue
          _buildOptionTile(
            icon: Icons.queue_music_rounded,
            iconColor: Colors.blueAccent,
            title: "Add to Queue",
            onTap: () {
              Navigator.pop(context);
              playerProvider.addToQueue(song);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Added to queue: ${song.title}"),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),

          // Action 4: Add to Playlist
          _buildOptionTile(
            icon: Icons.playlist_add_rounded,
            iconColor: Colors.tealAccent,
            title: "Add to Playlist",
            onTap: () {
              Navigator.pop(context);
              _showAddToPlaylistDialog(context, customPlaylistProvider);
            },
          ),

          // Action 5: Download / Remove Download
          _buildOptionTile(
            icon: isDownloading
                ? Icons.hourglass_top_rounded
                : isDown
                    ? Icons.download_done_rounded
                    : Icons.file_download_outlined,
            iconColor: isDown ? AppColors.midnightPrimary : Colors.white70,
            title: isDownloading
                ? "Downloading... (${(downloadProvider.getProgress(song.id) * 100).toInt()}%)"
                : isDown
                    ? "Downloaded (Tap to delete)"
                    : "Download Track",
            onTap: () async {
              Navigator.pop(context);
              if (isDown) {
                await downloadProvider.removeDownload(song);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Removed ${song.title} from downloads")),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Downloading ${song.title}...")),
                );
                final ok = await downloadProvider.downloadSong(song);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok
                          ? "Downloaded: ${song.title}"
                          : "Failed to download ${song.title}"),
                    ),
                  );
                }
              }
            },
          ),

          // Action 5: Toggle Favorite
          _buildOptionTile(
            icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            iconColor: isFav ? Colors.pinkAccent : Colors.white70,
            title: isFav ? "Remove from Favorites" : "Add to Favorites",
            onTap: () {
              Navigator.pop(context);
              playerProvider.toggleFavorite(song);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isFav
                      ? "Removed from favorites"
                      : "Added to favorites: ${song.title}"),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),

          // Action 6: View Artist
          if (song.artist.isNotEmpty && song.artist != 'Unknown Artist')
            _buildOptionTile(
              icon: Icons.person_outline_rounded,
              iconColor: Colors.purpleAccent,
              title: "Go to Artist (${song.artist.split(',').first})",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ArtistDetailScreen(
                      artistName: song.artist.split(',').first.trim(),
                    ),
                  ),
                );
              },
            ),

          // Action 7: Hide Song
          _buildOptionTile(
            icon: Icons.visibility_off_outlined,
            iconColor: Colors.redAccent,
            title: "Hide Song",
            onTap: () {
              Navigator.pop(context);
              hiddenProvider.hideSong(song);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Hidden: ${song.title}"),
                  action: SnackBarAction(
                    label: "UNDO",
                    onPressed: () => hiddenProvider.unhideSong(song.id),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: iconColor, size: 24),
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, CustomPlaylistProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.midnightSurface,
        title: Text("Add to Playlist", style: GoogleFonts.outfit(color: Colors.white)),
        content: provider.playlists.isEmpty
            ? Text("You haven't created any playlists yet.", style: GoogleFonts.inter(color: Colors.white70))
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: provider.playlists.length,
                  itemBuilder: (context, index) {
                    final pl = provider.playlists[index];
                    return ListTile(
                      title: Text(pl.title, style: GoogleFonts.inter(color: Colors.white)),
                      subtitle: Text("${pl.songs.length} tracks", style: GoogleFonts.inter(color: Colors.white54)),
                      onTap: () {
                        provider.addSongToPlaylist(pl.id, song);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Added to ${pl.title}")),
                        );
                      },
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }
}
