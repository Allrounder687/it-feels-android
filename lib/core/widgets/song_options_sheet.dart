import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/library/custom_playlist_provider.dart';
import 'package:it_feels_music/features/library/artist_detail_screen.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/main.dart';
import 'package:it_feels_music/core/providers/bottom_ui_provider.dart';
import 'package:it_feels_music/features/social/social_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:shimmer/shimmer.dart';

class SongOptionsSheet extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final playerProv = ref.watch(audioPlayerProvider);
    final downloadProv = ref.watch(downloadProvider);
    final hiddenProv = ref.read(hiddenSongsProvider);
    final customPlaylistProv = ref.read(customPlaylistProvider);

    final isFav = playerProv.isFavorite(song.id);
    final isDown = downloadProv.isDownloaded(song.id);
    final isDownloading = downloadProv.isDownloading(song.id);

    final bottomUiHeight = ref.watch(bottomUiProvider);
    final bottomPadding = bottomUiHeight > 0 ? bottomUiHeight + 12.0 : 28.0;

    return Container(
      padding: EdgeInsets.only(top: 16, bottom: bottomPadding, left: 20, right: 20),
      decoration: BoxDecoration(
        color: context.themeSurfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: context.themeInvertedTextColor.withValues(alpha: 0.5),
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
              color: context.themeTextColor24,
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
                          color: context.themeCardColor,
                          child: Icon(Icons.music_note, color: context.themeTextColor),
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
                        color: context.themeTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: context.themeMutedTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: context.themeTextColor10),
          const SizedBox(height: 8),

          // Action 1: Play Now
          _buildOptionTile(context, 
            icon: Icons.play_circle_fill_rounded,
            iconColor: context.themeAccentColor,
            title: "Play Now",
            onTap: () {
              Navigator.pop(context);
              ref.read(audioPlayerProvider.notifier).playSong(song, queue: playlistContext ?? [song]);
            },
          ),

          // Action 2: Play Next
          _buildOptionTile(context, 
            icon: Icons.playlist_play_rounded,
            iconColor: Colors.amberAccent,
            title: "Play Next",
            onTap: () {
              Navigator.pop(context);
              ref.read(audioPlayerProvider.notifier).playNext(song);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Playing next: ${song.title}"),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          
          // Action: Send to Friend
          _buildOptionTile(context,
            icon: Icons.send_rounded,
            iconColor: Colors.blueAccent,
            title: "Send to Friend",
            onTap: () {
              Navigator.pop(context);
              _showSendToFriendDialog(context);
            },
          ),

          // Action 3: Add to Queue
          _buildOptionTile(context, 
            icon: Icons.queue_music_rounded,
            iconColor: Colors.blueAccent,
            title: "Add to Queue",
            onTap: () {
              Navigator.pop(context);
              ref.read(audioPlayerProvider.notifier).addToQueue(song);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Added to queue: ${song.title}"),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),

          // Action 4: Add to Playlist
          _buildOptionTile(context, 
            icon: Icons.playlist_add_rounded,
            iconColor: Colors.tealAccent,
            title: "Add to Playlist",
            onTap: () {
              Navigator.pop(context);
              _showAddToPlaylistDialog(context, customPlaylistProv);
            },
          ),

          // Action 5: Download / Remove Download
          _buildOptionTile(context, 
            icon: isDownloading
                ? Icons.hourglass_top_rounded
                : isDown
                    ? Icons.download_done_rounded
                    : Icons.file_download_outlined,
            iconColor: isDown ? context.themeAccentColor : context.themeMutedTextColor,
            title: isDownloading
                ? "Downloading... (${(downloadProv.getProgress(song.id) * 100).toInt()}%)"
                : isDown
                    ? "Downloaded (Tap to delete)"
                    : "Download Track",
            onTap: () async {
              Navigator.pop(context);
              if (isDown) {
                await ref.read(downloadProvider.notifier).removeDownload(song);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Removed ${song.title} from downloads")),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Downloading ${song.title}...")),
                );
                final ok = await ref.read(downloadProvider.notifier).downloadSong(song);
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
          _buildOptionTile(context, 
            icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            iconColor: isFav ? Colors.pinkAccent : context.themeMutedTextColor,
            title: isFav ? "Remove from Favorites" : "Add to Favorites",
            onTap: () {
              Navigator.pop(context);
              ref.read(audioPlayerProvider.notifier).toggleFavorite(song);
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
            _buildOptionTile(context, 
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
          _buildOptionTile(context, 
            icon: Icons.visibility_off_outlined,
            iconColor: Colors.redAccent,
            title: "Hide Song",
            onTap: () {
              Navigator.pop(context);
              ref.read(hiddenSongsProvider.notifier).hideSong(song);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Hidden: ${song.title}"),
                  action: SnackBarAction(
                    label: "UNDO",
                    onPressed: () => ref.read(hiddenSongsProvider.notifier).unhideSong(song.id),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(BuildContext context, {
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
            color: context.themeTextColor,
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

  void _showAddToPlaylistDialog(BuildContext context, CustomPlaylistState provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.themeSurfaceColor,
        title: Text("Add to Playlist", style: GoogleFonts.outfit(color: context.themeTextColor)),
        content: provider.playlists.isEmpty
            ? Text("You haven't created any playlists yet.", style: GoogleFonts.inter(color: context.themeMutedTextColor))
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: provider.playlists.length,
                  itemBuilder: (context, index) {
                    final pl = provider.playlists[index];
                    return ListTile(
                      title: Text(pl.title, style: GoogleFonts.inter(color: context.themeTextColor)),
                      subtitle: Text("${pl.songs.length} tracks", style: GoogleFonts.inter(color: context.themeMutedTextColor)),
                      onTap: () {
                        appProviderContainer.read(customPlaylistProvider.notifier).addSongToPlaylist(pl.id, song);
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
            child: Text("Cancel", style: TextStyle(color: context.themeMutedTextColor)),
          ),
        ],
      ),
    );
  }

  void _showSendToFriendDialog(BuildContext context) {
    final socialService = locator<SocialService>();
    final friendsStream = socialService.getFriendsStream();
    
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.themeSurfaceColor,
          title: Text("Send to Friend", style: GoogleFonts.outfit(color: context.themeTextColor)),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: StreamBuilder<DocumentSnapshot>(
              stream: friendsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error loading friends.", style: GoogleFonts.inter(color: Colors.redAccent)));
                }
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: 5,
                    itemBuilder: (context, index) => ExcludeSemantics(
                                child: Shimmer.fromColors(
                                  baseColor: context.themeCardColor,
                                  highlightColor: context.themeSurfaceColor,
                                  child: ListTile(
                                    title: Container(height: 16, width: 120, color: context.themeCardColor, margin: const EdgeInsets.only(right: 150)),
                                    subtitle: Container(height: 12, width: 80, color: context.themeCardColor, margin: const EdgeInsets.only(right: 200, top: 4)),
                                  ),
                                ),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data?.data() == null) {
                  return Center(child: Text("No friends added yet.", style: GoogleFonts.inter(color: context.themeMutedTextColor)));
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final friends = List<String>.from(data['friends'] ?? []);

                if (friends.isEmpty) {
                  return Center(child: Text("No friends added yet.", style: GoogleFonts.inter(color: context.themeMutedTextColor)));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friendUid = friends[index];
                    return FutureBuilder<Map<String, dynamic>?>(
                      future: socialService.getFriendDetails(friendUid),
                      builder: (context, friendSnapshot) {
                        if (!friendSnapshot.hasData) {
                          return ExcludeSemantics(
                            child: Shimmer.fromColors(
                              baseColor: context.themeCardColor,
                              highlightColor: context.themeSurfaceColor,
                              child: ListTile(
                                title: Container(height: 16, width: 120, color: context.themeCardColor, margin: const EdgeInsets.only(right: 150)),
                                subtitle: Container(height: 12, width: 80, color: context.themeCardColor, margin: const EdgeInsets.only(right: 200, top: 4)),
                              ),
                            ),
                          );
                        }
                        final friendData = friendSnapshot.data!;
                        return ListTile(
                          title: Text(friendData['name'] ?? 'Unknown', style: GoogleFonts.inter(color: context.themeTextColor)),
                          subtitle: Text(friendData['username'] ?? '', style: GoogleFonts.inter(color: context.themeMutedTextColor)),
                          onTap: () {
                            socialService.sendSong(friendUid, song);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Sent to ${friendData['name']}")),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancel", style: TextStyle(color: context.themeMutedTextColor)),
            ),
          ],
        );
      },
    );
  }
}
