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
            fontSize: isWide ? 32 : 22,
            fontWeight: FontWeight.w800,
            color: context.themeTextColor,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                currentSong.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: isWide ? 16 : 14,
                  fontWeight: FontWeight.w500,
                  color: context.themeMutedTextColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Text(
                (currentSong.streamUrl?.toLowerCase().endsWith('.flac') ?? false) || (currentSong.streamUrl?.toLowerCase().endsWith('.alac') ?? false)
                    ? 'LOSSLESS'
                    : (currentSong.streamUrl?.toLowerCase().endsWith('.wav') ?? false)
                        ? 'HIGH-RES'
                        : '320 KBPS',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.amber,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildSourceBadge(),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceBadge() {
    String sourceName = 'SAAVN';
    Color sourceColor = Colors.tealAccent;
    
    if (currentSong.id.startsWith('youtube:') || currentSong.id.startsWith('search:')) {
      sourceName = 'YOUTUBE';
      sourceColor = Colors.redAccent;
    } else if (currentSong.id.startsWith('spotify:')) {
      sourceName = 'SPOTIFY';
      sourceColor = const Color(0xFF1DB954); // Spotify Green
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: sourceColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: sourceColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        sourceName,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: sourceColor,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
