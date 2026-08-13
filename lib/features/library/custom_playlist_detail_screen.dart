import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/data/models/custom_playlist.dart';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:it_feels_music/core/widgets/song_options_sheet.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/features/social/social_service.dart' as it_feels_music_social_service;
import 'package:it_feels_music/core/theme/app_dimensions.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as it_feels_music_firestore;
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:shimmer/shimmer.dart';

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
          body: SafeArea(
            top: false,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 340,
                  pinned: true,
                  backgroundColor: context.themeBackgroundColor,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: IconButton(
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
                  ),
                  actions: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.themeBackgroundColor.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.edit_outlined, color: context.themeTextColor, size: 20),
                      ),
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
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.themeBackgroundColor.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.blueAccent, size: 20),
                      ),
                      onPressed: () {
                        _showSendToFriendDialog(context, currentPlaylist);
                      },
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.themeBackgroundColor.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      ),
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
                    const SizedBox(width: 8),
                  ],
                  flexibleSpace: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      final top = constraints.biggest.height;
                      final minHeight = MediaQuery.of(context).padding.top + kToolbarHeight;
                      final scrollPercent = ((top - minHeight) / (340 - minHeight)).clamp(0.0, 1.0);
                      final isCollapsed = top <= minHeight + 20;

                      final coverArtUrl = (songs.isNotEmpty && songs.first.coverArt.isNotEmpty) ? songs.first.coverArt : "";

                      return FlexibleSpaceBar(
                        titlePadding: const EdgeInsets.only(left: 64, right: 64, bottom: 16),
                        title: isCollapsed
                            ? Text(
                                currentPlaylist.title,
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
                            // Blurred Artwork Background
                            if (coverArtUrl.isNotEmpty)
                              CustomImageWidget(
                                imageUrl: coverArtUrl,
                                fit: BoxFit.cover,
                              ),
                            Positioned.fill(
                              child: Container(color: context.themeBackgroundColor.withValues(alpha: 0.6)),
                            ),
                            // Foreground Artwork and Text (Fades out when scrolling up)
                            Opacity(
                              opacity: scrollPercent,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    width: 180,
                                    height: 180,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.3),
                                          blurRadius: 30,
                                          offset: const Offset(0, 15),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: coverArtUrl.isNotEmpty
                                          ? CustomImageWidget(imageUrl: coverArtUrl, fit: BoxFit.cover)
                                          : Container(color: context.themeCardColor, child: Icon(Icons.queue_music, size: 80, color: context.themeTextColor24)),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: Text(
                                      currentPlaylist.title,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: context.themeTextColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${songs.length} Tracks",
                                    style: GoogleFonts.inter(
                                      color: context.themeMutedTextColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Play and Shuffle Buttons Apple Music Style
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
                            label: Text("Play All", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                            onPressed: () {
                              if (songs.isNotEmpty) ref.read(audioPlayerProvider.notifier).playSong(songs.first, queue: songs, index: 0);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.themeCardColor.withValues(alpha: 0.8),
                              foregroundColor: context.themeTextColor,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: Icon(Icons.shuffle_rounded, size: 20, color: context.themeAccentColor),
                            label: Text("Shuffle", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                            onPressed: () {
                              if (songs.isNotEmpty) {
                                final shuffled = List<Song>.from(songs)..shuffle();
                                ref.read(audioPlayerProvider.notifier).playSong(shuffled[0], queue: shuffled, index: 0);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Songs List
                songs.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            "No songs added yet.\nAdd songs from the player or search.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(color: context.themeMutedTextColor),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final song = songs[index];
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
                                    ref.read(audioPlayerProvider.notifier).playSong(song, queue: songs, index: index);
                                  },
                                ),
                              ),
                            );
                          },
                          childCount: songs.length,
                        ),
                      ),
                  SliverToBoxAdapter(child: SizedBox(height: AppDimensions.bottomClearance + MediaQuery.of(context).viewPadding.bottom)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSendToFriendDialog(BuildContext context, CustomPlaylist playlist) {
    final socialService = locator<it_feels_music_social_service.SocialService>();
    final friendsStream = socialService.getFriendsStream();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.themeSurfaceColor,
          title: Text("Send Playlist", style: GoogleFonts.outfit(color: context.themeTextColor)),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: StreamBuilder<it_feels_music_firestore.DocumentSnapshot>(
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
                        
                        final friendNames = Map<String, String>.from(data['friend_names'] ?? {});
                        final nickname = friendNames[friendUid];
                        final displayName = nickname ?? friendData['name'] ?? 'Unknown';

                        return ListTile(
                          title: Text(displayName, style: GoogleFonts.inter(color: context.themeTextColor)),
                          subtitle: Text(friendData['username'] ?? '', style: GoogleFonts.inter(color: context.themeMutedTextColor)),
                          onTap: () {
                            socialService.sendPlaylist(friendUid, playlist.toJson());
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Sent to $displayName")),
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
