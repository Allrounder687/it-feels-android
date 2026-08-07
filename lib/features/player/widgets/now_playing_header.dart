import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/features/player/video_player_provider.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

class NowPlayingHeader extends ConsumerWidget {
  final bool isVideoMode;
  final bool hasViewedVideoForCurrentSong;
  final Color surfaceColor;
  final Color accentColor;
  final void Function(bool) onToggleMode;
  final VoidCallback onOptionsTap;

  const NowPlayingHeader({
    super.key,
    required this.isVideoMode,
    required this.hasViewedVideoForCurrentSong,
    required this.surfaceColor,
    required this.accentColor,
    required this.onToggleMode,
    required this.onOptionsTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoProvider = ref.watch(videoPlayerProvider);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.themeTextColor, size: 30),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Close Player',
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: surfaceColor.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => onToggleMode(false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: !isVideoMode ? accentColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Song',
                    style: GoogleFonts.inter(
                      color: !isVideoMode ? context.themeInvertedTextColor : context.themeMutedTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => onToggleMode(true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isVideoMode ? accentColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: (!isVideoMode && !hasViewedVideoForCurrentSong && videoProvider.videoController != null)
                        ? [BoxShadow(color: accentColor.withValues(alpha: 0.8), blurRadius: 10, spreadRadius: 2)]
                        : null,
                  ),
                  child: Text(
                    'Video',
                    style: GoogleFonts.inter(
                      color: isVideoMode || (videoProvider.videoController != null) 
                          ? context.themeInvertedTextColor : context.themeMutedTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.more_vert_rounded, color: context.themeTextColor, size: 26),
          onPressed: onOptionsTap,
          tooltip: 'Options',
        ),
      ],
    );
  }
}
