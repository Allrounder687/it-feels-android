import 'package:it_feels_music/views/widgets/custom_image_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/song_model.dart';
import '../../providers/audio_player_provider.dart';
import '../widgets/song_options_sheet.dart';

class SeeAllSongsScreen extends StatefulWidget {
  final String title;
  final List<Song> songs;

  const SeeAllSongsScreen({
    super.key,
    required this.title,
    required this.songs,
  });

  @override
  State<SeeAllSongsScreen> createState() => _SeeAllSongsScreenState();
}

class _SeeAllSongsScreenState extends State<SeeAllSongsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterText = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<AudioPlayerProvider>(context);

    final filteredSongs = widget.songs.where((s) {
      if (_filterText.isEmpty) return true;
      final q = _filterText.toLowerCase();
      return s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q) ||
          s.album.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.midnightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.midnightBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.midnightPrimary, size: 32),
            onPressed: () {
              if (filteredSongs.isNotEmpty) {
                playerProvider.playSong(filteredSongs[0], queue: filteredSongs, index: 0);
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
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                onChanged: (val) {
                  setState(() {
                    _filterText = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: "Filter ${widget.title}...",
                  hintStyle: GoogleFonts.inter(color: AppColors.midnightTextMuted, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.midnightTextMuted, size: 20),
                  suffixIcon: _filterText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _filterText = "";
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.midnightSurface,
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
                  style: GoogleFonts.inter(color: AppColors.midnightTextMuted, fontSize: 13),
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
                        style: GoogleFonts.inter(color: Colors.white60),
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
                                ? AppColors.midnightCard.withValues(alpha: 0.9)
                                : AppColors.midnightCard.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(14),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: song.coverArt.isNotEmpty
                                      ? CustomImageWidget(imageUrl: song.coverArt, fit: BoxFit.cover)
                                      : const Icon(Icons.music_note, color: Colors.white),
                                ),
                              ),
                              title: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                "${song.artist} â€¢ ${song.album.isNotEmpty ? song.album : 'Single'}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: AppColors.midnightTextMuted,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                                onPressed: () {
                                  SongOptionsSheet.show(context, song, playlistContext: filteredSongs);
                                },
                              ),
                              onTap: () {
                                playerProvider.playSong(song, queue: filteredSongs, index: index);
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
