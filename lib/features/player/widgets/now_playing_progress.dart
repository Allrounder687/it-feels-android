import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/features/player/video_player_provider.dart';
import 'package:it_feels_music/features/settings/settings_provider.dart';
import 'package:it_feels_music/core/widgets/wavy_seek_bar.dart';
import 'package:it_feels_music/features/player/queue_bottom_sheet.dart';
import 'package:it_feels_music/data/models/song_model.dart';

class NowPlayingProgress extends ConsumerWidget {
  final bool isVideoMode;
  final Color accentColor;

  const NowPlayingProgress({
    super.key,
    required this.isVideoMode,
    required this.accentColor,
  });

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoProvider = ref.watch(videoPlayerProvider);
    final playerProvider = ref.watch(audioPlayerProvider);

    if (isVideoMode && videoProvider.videoController != null) {
      return StreamBuilder<Duration>(
        stream: videoProvider.player!.stream.position,
        builder: (context, snapshot) {
          final position = snapshot.data ?? videoProvider.player!.state.position;
          final duration = videoProvider.player!.state.duration;
          return Column(
            children: [
              WavySeekBar(
                position: position,
                duration: duration,
                activeColor: accentColor,
                inactiveColor: context.themeTextColor24,
                onSeek: (newPos) {
                  videoProvider.player?.seek(newPos);
                  final settingsProv = ref.read(settingsProvider);
                  if (!settingsProv.useVideoAudioSource) {
                    ref.read(audioPlayerProvider.notifier).seek(newPos);
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(position),
                      style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12),
                    ),
                    Text(
                      _formatDuration(duration),
                      style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
      );
    }

    return StreamBuilder<Duration>(
      stream: ref.read(audioPlayerProvider.notifier).audioHandler.player.positionStream,
      initialData: playerProvider.position,
      builder: (context, snapshot) {
        final currentPos = snapshot.data ?? playerProvider.position;
        return Column(
          children: [
            WavySeekBar(
              position: currentPos,
              duration: playerProvider.duration,
              activeColor: accentColor,
              inactiveColor: context.themeTextColor24,
              onSeek: (newPos) => ref.read(audioPlayerProvider.notifier).seek(newPos),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(currentPos),
                    style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12),
                  ),
                  Text(
                    _formatDuration(playerProvider.duration),
                    style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class QueueDragHandle extends StatelessWidget {
  final Song? nextSong;
  final Color surfaceColor;

  const QueueDragHandle({
    super.key,
    required this.nextSong,
    required this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const QueueBottomSheet(),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: surfaceColor.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: context.themeMutedTextColor.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.keyboard_arrow_up_rounded, color: context.themeMutedTextColor, size: 16),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    nextSong != null
                        ? "UP NEXT • ${nextSong!.title}"
                        : "YOUR QUEUE",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: context.themeTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
