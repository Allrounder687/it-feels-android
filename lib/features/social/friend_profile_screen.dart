import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/features/social/social_service.dart';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:it_feels_music/data/models/custom_playlist.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

class FriendProfileScreen extends ConsumerStatefulWidget {
  final String friendUid;
  final String friendName;

  const FriendProfileScreen({
    super.key,
    required this.friendUid,
    required this.friendName,
  });

  @override
  ConsumerState<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends ConsumerState<FriendProfileScreen> {
  final SocialService _socialService = locator<SocialService>();
  bool _isLoading = true;
  List<CustomPlaylist> _publicPlaylists = [];
  Map<String, dynamic>? _friendData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final details = await _socialService.getFriendDetails(widget.friendUid);
    
    // Note: Since playlists are currently stored locally in Hive, cross-device playlist sharing 
    // requires a backend implementation. We will just show a placeholder for now.
    
    if (mounted) {
      setState(() {
        _friendData = details;
        _isLoading = false;
      });
    }
  }

  void _importPlaylist(CustomPlaylist playlist) {
    ref.read(customPlaylistProvider.notifier).createPlaylistWithSongs(
      "${playlist.title} (from ${widget.friendName})",
      playlist.songs,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Imported ${playlist.title}!")),
    );
  }

  Future<void> _stealQueue() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fetching queue...")));
    final queue = await _socialService.getFriendQueue(widget.friendUid);
    if (queue.isNotEmpty) {
      ref.read(audioPlayerProvider.notifier).playSong(queue.first, queue: queue);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Listening along with ${widget.friendName}!")));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Queue is empty or unavailable.")));
      }
    }
  }

  Future<void> _saveQueueAsPlaylist() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fetching queue...")));
    final queue = await _socialService.getFriendQueue(widget.friendUid);
    if (queue.isNotEmpty) {
      ref.read(customPlaylistProvider.notifier).createPlaylistWithSongs(
        "${widget.friendName}'s Queue",
        queue,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved queue as a playlist!")));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Queue is empty or unavailable.")));
      }
    }
  }

  Widget _buildPresenceCard() {
    return StreamBuilder<DatabaseEvent>(
      stream: _socialService.getPresenceStream(widget.friendUid),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) return const SizedBox.shrink();
        
        try {
          final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
          if (data['is_playing'] == true && data['song_data'] != null) {
            final song = Song.fromJson(Map<String, dynamic>.from(data['song_data']));
            
            return Container(
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.themeSurfaceColor, context.themeAccentColor.withValues(alpha: 0.2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.themeAccentColor, width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        const Icon(Icons.music_note_rounded, color: Colors.greenAccent, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          "NOW LISTENING",
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.greenAccent, letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CustomImageWidget(imageUrl: song.coverArt, width: 56, height: 56),
                    ),
                    title: Text(song.title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.themeTextColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(song.artist, style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: Icon(Icons.play_circle_fill_rounded, color: context.themeAccentColor, size: 42),
                      onPressed: () {
                        ref.read(audioPlayerProvider.notifier).playSong(song);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.themeAccentColor,
                              foregroundColor: context.themeInvertedTextColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _stealQueue,
                            icon: const Icon(Icons.headphones_rounded, size: 18),
                            label: const Text("Listen Along", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.themeTextColor,
                              side: BorderSide(color: context.themeAccentColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _saveQueueAsPlaylist,
                            icon: const Icon(Icons.queue_music_rounded, size: 18),
                            label: const Text("Save Queue", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            );
          }
        } catch (e) {
          debugPrint("Error parsing presence data: $e");
        }
        return const SizedBox.shrink();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(audioPlayerProvider); // Watch for theme changes
    return Scaffold(
      backgroundColor: context.themeBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.themeTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.friendName, style: GoogleFonts.outfit(color: context.themeTextColor, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: context.themeAccentColor,
                  child: Text(
                    widget.friendName.isNotEmpty ? widget.friendName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.friendName,
                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: context.themeTextColor),
                ),
                if (_friendData?['username'] != null)
                  Text(
                    "@${_friendData!['username']}",
                    style: GoogleFonts.inter(fontSize: 16, color: context.themeMutedTextColor),
                  ),
                const SizedBox(height: 32),
                
                _buildPresenceCard(),
                
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Public Playlists",
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: context.themeTextColor),
                  ),
                ),
                const SizedBox(height: 16),
                
                _publicPlaylists.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            "${widget.friendName} hasn't shared any playlists publicly yet.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(color: context.themeMutedTextColor),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _publicPlaylists.length,
                        itemBuilder: (context, index) {
                          final p = _publicPlaylists[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: context.themeSurfaceColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.queue_music_rounded, color: context.themeAccentColor),
                            ),
                            title: Text(p.title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.themeTextColor)),
                            subtitle: Text("${p.songs.length} songs", style: GoogleFonts.inter(color: context.themeMutedTextColor)),
                            trailing: IconButton(
                              icon: Icon(Icons.download_rounded, color: context.themeAccentColor),
                              onPressed: () => _importPlaylist(p),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
    );
  }
}
