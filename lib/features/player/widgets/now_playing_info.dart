import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/data/models/song_model.dart';

class NowPlayingInfo extends StatelessWidget {
  final Song currentSong;
  final bool isWide;

  const NowPlayingInfo({
    super.key,
    required this.currentSong,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          currentSong.title,
          maxLines: 1,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontSize: isWide ? 46 : 24,
            fontWeight: FontWeight.w900,
            color: context.themeTextColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          currentSong.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: isWide ? 20 : 16,
            fontWeight: FontWeight.w500,
            color: context.themeMutedTextColor,
          ),
        ),
      ],
    );
  }
}
