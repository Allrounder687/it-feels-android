import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

class SleepTimerSheet extends ConsumerWidget {
  const SleepTimerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioProvider = ref.watch(audioPlayerProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: audioProvider.themeSurfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bedtime_rounded, color: audioProvider.themeAccentColor, size: 28),
              const SizedBox(width: 12),
              Text(
                'Sleep Timer',
                style: TextStyle(
                  color: context.themeTextColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (audioProvider.isSleepTimerActive || audioProvider.sleepAfterCurrentTrack) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: audioProvider.themeAccentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    audioProvider.sleepAfterCurrentTrack
                        ? 'Stopping after this track'
                        : 'Stopping in ${audioProvider.sleepTimerRemaining?.inMinutes ?? 0}m',
                    style: TextStyle(
                      color: audioProvider.themeAccentColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      audioProvider.cancelSleepTimer();
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          _buildTimerOption(context, audioProvider, '15 Minutes', const Duration(minutes: 15)),
          _buildTimerOption(context, audioProvider, '30 Minutes', const Duration(minutes: 30)),
          _buildTimerOption(context, audioProvider, '45 Minutes', const Duration(minutes: 45)),
          _buildTimerOption(context, audioProvider, '60 Minutes', const Duration(minutes: 60)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'End of Track',
              style: TextStyle(color: context.themeTextColor, fontSize: 18),
            ),
            trailing: audioProvider.sleepAfterCurrentTrack 
                ? Icon(Icons.check_circle, color: audioProvider.themeAccentColor)
                : Icon(Icons.circle_outlined, color: context.themeMutedTextColor),
            onTap: () {
              audioProvider.setSleepAfterCurrentTrack();
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTimerOption(BuildContext context, AudioPlayerProvider provider, String title, Duration duration) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(color: context.themeTextColor, fontSize: 18),
      ),
      onTap: () {
        provider.startSleepTimer(duration);
        Navigator.pop(context);
      },
    );
  }
}
