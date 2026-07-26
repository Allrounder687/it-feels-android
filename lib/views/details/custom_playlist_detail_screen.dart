import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/custom_playlist.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/custom_playlist_provider.dart';
import '../widgets/custom_image_widget.dart';
import '../widgets/song_options_sheet.dart';
import '../widgets/mini_player.dart';
import '../player/now_playing_screen.dart';

class CustomPlaylistDetailScreen extends StatelessWidget {
  final CustomPlaylist playlist;

  const CustomPlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    return Consumer2<CustomPlaylistProvider, AudioPlayerProvider>(
      builder: (context, playlistProvider, playerProvider, child) {
        // Find updated playlist
        final currentPlaylist = playlistProvider.playlists.firstWhere(
          (p) => p.id == playlist.id,
          orElse: () => playlist,
        );
        final songs = currentPlaylist.songs;

        return Scaffold(
          backgroundColor: AppColors.midnightBackground,
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
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.midnightSurface,
                      title: Text("Delete Playlist", style: GoogleFonts.outfit(color: Colors.white)),
                      content: Text("Are you sure you want to delete '${currentPlaylist.title}'?", style: GoogleFonts.inter(color: Colors.white70)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.redAccent))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    playlistProvider.deletePlaylist(currentPlaylist.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppColors.midnightCard,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: songs.isNotEmpty && songs.first.coverArt.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: CustomImageWidget(imageUrl: songs.first.coverArt, fit: BoxFit.cover),
                            )
                          : const Icon(Icons.queue_music, size: 80, color: Colors.white24),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      currentPlaylist.title,
                      style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${songs.length} tracks",
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.midnightTextMuted),
                    ),
                    const SizedBox(height: 20),
                    if (songs.isNotEmpty)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.midnightAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 28),
                        label: Text("Play All", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                        onPressed: () {
                          playerProvider.playSong(songs.first, queue: songs, index: 0);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: songs.isEmpty
                    ? Center(
                        child: Text("No songs added yet.\nAdd songs from the player or search.", 
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: AppColors.midnightTextMuted),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: songs.length,
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
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
                                        ? CustomImageWidget(imageUrl: song.coverArt, fit: BoxFit.cover)
                                        : const Icon(Icons.music_note, color: Colors.white),
                                  ),
                                ),
                                title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                                subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: AppColors.midnightTextMuted, fontSize: 12)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.white38),
                                      onPressed: () {
                                        playlistProvider.removeSongFromPlaylist(currentPlaylist.id, song.id);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.more_vert, color: Colors.white54),
                                      onPressed: () {
                                        SongOptionsSheet.show(context, song, playlistContext: songs);
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  playerProvider.playSong(song, queue: songs, index: index);
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
