import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/services/database_service.dart';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/theme/app_dimensions.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  bool _isLoading = true;
  List<Song> _topSongs = [];

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final db = DatabaseService();
    final songs = await db.getTopPlayedSongs(limit: 20);
    if (mounted) {
      setState(() {
        _topSongs = songs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyProvider = ref.watch(listeningHistoryProvider);
    final topArtists = historyProvider.getTopArtists(limit: 5);

    return Scaffold(
      backgroundColor: context.themeBackgroundColor,
      appBar: AppBar(
        flexibleSpace: kIsWeb ? null : (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux ? null : const DragToMoveArea(child: SizedBox.expand())),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.themeTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Your Stats",
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: context.themeTextColor,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("Top Artists", context),
                  const SizedBox(height: 16),
                  if (topArtists.isEmpty)
                    Text("Listen to more music to see your top artists.", style: GoogleFonts.inter(color: context.themeMutedTextColor))
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: topArtists.map((artist) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: context.themeSurfaceColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            artist,
                            style: GoogleFonts.inter(
                              color: context.themeTextColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 32),
                  _buildSectionHeader("Your Top Songs", context),
                  const SizedBox(height: 16),
                  if (_topSongs.isEmpty)
                    Text("Listen to more music to see your top songs.", style: GoogleFonts.inter(color: context.themeMutedTextColor))
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _topSongs.length,
                      itemBuilder: (context, index) {
                        final song = _topSongs[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: song.coverArt.isNotEmpty
                                  ? CustomImageWidget(imageUrl: song.coverArt, fit: BoxFit.cover)
                                  : Container(color: AppColors.midnightPill),
                            ),
                          ),
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(color: context.themeTextColor, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            "${song.artist} â€¢ ${song.playCount} plays",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12),
                          ),
                          onTap: () {
                            ref.read(audioPlayerProvider.notifier).playSong(song, queue: _topSongs, index: index);
                          },
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                  SizedBox(height: AppDimensions.bottomClearance + MediaQuery.of(context).viewPadding.bottom),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: context.themeTextColor,
      ),
    );
  }
}

