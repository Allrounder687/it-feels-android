import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/song_model.dart';
import '../../providers/audio_player_provider.dart';
import '../../services/database_service.dart';
import '../widgets/custom_image_widget.dart';
import '../widgets/song_options_sheet.dart';

class SmartRecommendationsRow extends StatefulWidget {
  const SmartRecommendationsRow({Key? key}) : super(key: key);

  @override
  State<SmartRecommendationsRow> createState() => _SmartRecommendationsRowState();
}

class _SmartRecommendationsRowState extends State<SmartRecommendationsRow> {
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

    final playerProvider = Provider.of<AudioPlayerProvider>(context, listen: false);

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
                  color: Colors.white,
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
                  playerProvider.playSong(song, queue: _recommendations, index: index);
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
                              : Container(color: AppColors.midnightCard),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
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
                          color: AppColors.midnightTextMuted,
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
