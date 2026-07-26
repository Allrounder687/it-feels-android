import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/audio_player_provider.dart';

class SleepTimerSheet extends StatelessWidget {
  const SleepTimerSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final audioProvider = Provider.of<AudioPlayerProvider>(context);

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
              const Text(
                'Sleep Timer',
                style: TextStyle(
                  color: Colors.white,
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
                color: audioProvider.themeAccentColor.withOpacity(0.1),
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
            title: const Text(
              'End of Track',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            trailing: audioProvider.sleepAfterCurrentTrack 
                ? Icon(Icons.check_circle, color: audioProvider.themeAccentColor)
                : const Icon(Icons.circle_outlined, color: Colors.white54),
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
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
      onTap: () {
        provider.startSleepTimer(duration);
        Navigator.pop(context);
      },
    );
  }
}
