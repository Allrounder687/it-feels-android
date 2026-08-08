import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/services/database_service.dart';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:it_feels_music/core/widgets/song_options_sheet.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

class SmartRecommendationsRow extends ConsumerStatefulWidget {
  const SmartRecommendationsRow({super.key});

  @override
  ConsumerState<SmartRecommendationsRow> createState() => _SmartRecommendationsRowState();
}

class _SmartRecommendationsRowState extends ConsumerState<SmartRecommendationsRow> {
  List<Song> _recommendations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    try {
      final db = DatabaseService();
      // Fetching songs on repeat (highly played locally)
      final songs = await db.getOnRepeat();
      if (mounted) {
        setState(() {
          _recommendations = songs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink(); // Don't show anything while loading to avoid layout jump
    }

    if (_recommendations.isEmpty) {
      return const SizedBox.shrink(); // Gracefully collapse if no history
    }

    final playerProvider = ref.read(audioPlayerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.midnightAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                "Because You Listened",
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.themeTextColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 170, // Increased slightly to give text room
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _recommendations.length,
            itemBuilder: (context, index) {
              final song = _recommendations[index];
              return GestureDetector(
                onTap: () {
                  ref.read(audioPlayerProvider.notifier).playSong(song, queue: _recommendations, index: index);
                },
                onLongPress: () {
                  SongOptionsSheet.show(context, song, playlistContext: _recommendations);
                },
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: song.coverArt.isNotEmpty
                              ? CustomImageWidget(
                                  imageUrl: song.coverArt,
                                  fit: BoxFit.cover,
                                )
                              : Container(color: context.themeCardColor),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: context.themeTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: context.themeMutedTextColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
