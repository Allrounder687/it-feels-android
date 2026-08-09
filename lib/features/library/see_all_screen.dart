import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/widgets/song_options_sheet.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

class SeeAllSongsScreen extends ConsumerStatefulWidget {
  final String title;
  final List<Song> songs;

  const SeeAllSongsScreen({
    super.key,
    required this.title,
    required this.songs,
  });

  @override
  ConsumerState<SeeAllSongsScreen> createState() => _SeeAllSongsScreenState();
}

class _SeeAllSongsScreenState extends ConsumerState<SeeAllSongsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterText = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = ref.watch(audioPlayerProvider);

    final filteredSongs = widget.songs.where((s) {
      if (_filterText.isEmpty) return true;
      final q = _filterText.toLowerCase();
      return s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q) ||
          s.album.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: context.themeBackgroundColor,
      appBar: AppBar(
        flexibleSpace: kIsWeb ? null : (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux ? null : const DragToMoveArea(child: SizedBox.expand())),
        backgroundColor: context.themeBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.themeTextColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.outfit(
            color: context.themeTextColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.play_circle_fill_rounded, color: context.themeAccentColor, size: 32),
            onPressed: () {
              if (filteredSongs.isNotEmpty) {
                ref.read(audioPlayerProvider.notifier).playSong(filteredSongs[0], queue: filteredSongs, index: 0);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input inside See All screen
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(color: context.themeTextColor, fontSize: 14),
                onChanged: (val) {
                  setState(() {
                    _filterText = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: "Filter ${widget.title}...",
                  hintStyle: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: context.themeMutedTextColor, size: 20),
                  suffixIcon: _filterText.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded, color: context.themeMutedTextColor, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _filterText = "";
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: context.themeSurfaceColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Track Count Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${filteredSongs.length} Tracks",
                  style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Full List of Songs
            Expanded(
              child: filteredSongs.isEmpty
                  ? Center(
                      child: Text(
                        "No songs found",
                        style: GoogleFonts.inter(color: context.themeMutedTextColor),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      itemCount: filteredSongs.length,
                      itemBuilder: (context, index) {
                        final song = filteredSongs[index];
                        final isCurrentlyPlaying = playerProvider.currentSong?.id == song.id;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: isCurrentlyPlaying
                                ? context.themeCardColor.withValues(alpha: 0.9)
                                : context.themeCardColor.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(14),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: song.coverArt.isNotEmpty
                                      ? CustomImageWidget(imageUrl: song.coverArt, fit: BoxFit.cover)
                                      : Icon(Icons.music_note, color: context.themeTextColor),
                                ),
                              ),
                              title: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: context.themeTextColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                "${song.artist} Ã¢â‚¬Â¢ ${song.album.isNotEmpty ? song.album : 'Single'}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: context.themeMutedTextColor,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.more_vert_rounded, color: context.themeMutedTextColor),
                                onPressed: () {
                                  SongOptionsSheet.show(context, song, playlistContext: filteredSongs);
                                },
                              ),
                              onTap: () {
                                ref.read(audioPlayerProvider.notifier).playSong(song, queue: filteredSongs, index: index);
                              },
                              onLongPress: () {
                                SongOptionsSheet.show(context, song, playlistContext: filteredSongs);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

