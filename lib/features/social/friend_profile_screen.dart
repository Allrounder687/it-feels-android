import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/features/social/social_service.dart';
import 'package:it_feels_music/data/models/custom_playlist.dart';
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
  final List<CustomPlaylist> _publicPlaylists = [];
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

  @override
  Widget build(BuildContext context) {
    ref.watch(audioPlayerProvider); // Watch for theme changes
    return Scaffold(
      backgroundColor: context.themeBackgroundColor,
      appBar: AppBar(
        flexibleSpace: kIsWeb ? null : (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux ? null : const DragToMoveArea(child: SizedBox.expand())),
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
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
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

