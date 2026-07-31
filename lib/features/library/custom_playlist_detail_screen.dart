import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/data/models/custom_playlist.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/features/library/custom_playlist_provider.dart';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:it_feels_music/core/widgets/song_options_sheet.dart';
import 'package:it_feels_music/core/widgets/mini_player.dart';
import 'package:it_feels_music/features/player/now_playing_screen.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

class CustomPlaylistDetailScreen extends ConsumerWidget {
  final CustomPlaylist playlist;

  const CustomPlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, child) {
        final playlistProvider = ref.watch(customPlaylistProvider);
        final playerProvider = ref.watch(audioPlayerProvider);
        // Find updated playlist
        final currentPlaylist = playlistProvider.playlists.firstWhere(
          (p) => p.id == playlist.id,
          orElse: () => playlist,
        );
        final songs = currentPlaylist.songs;

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
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: context.themeTextColor),
            actions: [
              IconButton(
                icon: Icon(Icons.edit_outlined, color: context.themeTextColor),
                onPressed: () async {
                  final controller = TextEditingController(text: currentPlaylist.title);
                  final newName = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: context.themeSurfaceColor,
                      title: Text("Rename Playlist", style: GoogleFonts.outfit(color: context.themeTextColor)),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        style: GoogleFonts.inter(color: context.themeTextColor),
                        decoration: InputDecoration(
                          hintText: "Enter new name",
                          hintStyle: GoogleFonts.inter(color: context.themeMutedTextColor),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: context.themeTextColor24)),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.midnightAccent)),
                        ),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                        TextButton(
                          onPressed: () {
                            if (controller.text.trim().isNotEmpty) {
                              Navigator.pop(ctx, controller.text.trim());
                            }
                          },
                          child: const Text("Rename", style: TextStyle(color: AppColors.midnightAccent)),
                        ),
                      ],
                    ),
                  );
                  if (newName != null && newName != currentPlaylist.title) {
                    ref.read(customPlaylistProvider.notifier).renamePlaylist(currentPlaylist.id, newName);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: context.themeSurfaceColor,
                      title: Text("Delete Playlist", style: GoogleFonts.outfit(color: context.themeTextColor)),
                      content: Text("Are you sure you want to delete '${currentPlaylist.title}'?", style: GoogleFonts.inter(color: context.themeMutedTextColor)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.redAccent))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    ref.read(customPlaylistProvider.notifier).deletePlaylist(currentPlaylist.id);
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
                        color: context.themeCardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: context.themeInvertedTextColor.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: songs.isNotEmpty && songs.first.coverArt.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: CustomImageWidget(imageUrl: songs.first.coverArt, fit: BoxFit.cover),
                            )
                          : Icon(Icons.queue_music, size: 80, color: context.themeTextColor24),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      currentPlaylist.title,
                      style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: context.themeTextColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${songs.length} tracks",
                      style: GoogleFonts.inter(fontSize: 14, color: context.themeMutedTextColor),
                    ),
                    const SizedBox(height: 20),
                    if (songs.isNotEmpty)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.midnightAccent,
                          foregroundColor: context.themeInvertedTextColor,
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
                          style: GoogleFonts.inter(color: context.themeMutedTextColor),
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
                              color: context.themeCardColor.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                              child: ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: song.coverArt.isNotEmpty
                                        ? CustomImageWidget(imageUrl: song.coverArt, fit: BoxFit.cover)
                                        : Icon(Icons.music_note, color: context.themeTextColor),
                                  ),
                                ),
                                title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: context.themeTextColor, fontWeight: FontWeight.w600, fontSize: 14)),
                                subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.remove_circle_outline, color: context.themeMutedTextColor),
                                      onPressed: () {
                                        ref.read(customPlaylistProvider.notifier).removeSongFromPlaylist(currentPlaylist.id, song.id);
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.more_vert, color: context.themeMutedTextColor),
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
