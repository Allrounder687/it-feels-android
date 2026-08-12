import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/widgets/bouncy_icon_button.dart';
import 'package:it_feels_music/core/widgets/animated_play_pause_button.dart';
import 'package:it_feels_music/features/social/room_bottom_sheet.dart';
import 'package:it_feels_music/features/player/queue_bottom_sheet.dart';

class NowPlayingPrimaryControls extends ConsumerWidget {
  final bool isWide;
  final bool isVideoMode;
  final Color surfaceColor;
  final Color accentColor;

  const NowPlayingPrimaryControls({
    super.key,
    required this.isWide,
    required this.isVideoMode,
    required this.surfaceColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoProvider = ref.watch(videoPlayerProvider);
    final playerProvider = ref.watch(audioPlayerProvider);

    return Container(
      height: isWide ? 86 : 74,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          BouncyIconButton(
            child: Icon(Icons.replay_10_rounded, color: context.themeMutedTextColor, size: isWide ? 28 : 24),
            onPressed: () {
              if (isVideoMode) {
                final settingsProv = ref.read(settingsProvider);
                final pos = videoProvider.player?.state.position ?? Duration.zero;
                final newPos = pos - const Duration(seconds: 15);
                videoProvider.player?.seek(newPos);
                if (!settingsProv.useVideoAudioSource) {
                  ref.read(audioPlayerProvider.notifier).seek(newPos);
                }
              } else {
                final pos = ref.read(audioPlayerProvider.notifier).engine.position;
                final newPos = pos - const Duration(seconds: 15);
                ref.read(audioPlayerProvider.notifier).seek(newPos);
              }
            },
          ),
          BouncyIconButton(
            child: Icon(Icons.skip_previous_rounded, color: context.themeTextColor, size: isWide ? 40 : 34),
            onPressed: () {
              ref.read(audioPlayerProvider.notifier).skipToPrevious();
            },
          ),
          BouncyIconButton(
            onPressed: () {
              final settingsProv = ref.read(settingsProvider);
              if (isVideoMode) {
                final player = videoProvider.player;
                if (player != null) {
                  if (player.state.playing) {
                    player.pause();
                    if (!settingsProv.useVideoAudioSource) {
                      ref.read(audioPlayerProvider.notifier).pause();
                    }
                  } else {
                    player.play();
                    if (!settingsProv.useVideoAudioSource) {
                      ref.read(audioPlayerProvider.notifier).seek(player.state.position);
                      ref.read(audioPlayerProvider.notifier).play();
                    }
                  }
                }
              } else {
                ref.read(audioPlayerProvider.notifier).togglePlayPause();
              }
            },
            padding: EdgeInsets.zero,
            child: Container(
              width: isWide ? 68 : 56,
              height: isWide ? 68 : 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: isVideoMode && videoProvider.player != null
                ? StreamBuilder<bool>(
                    stream: videoProvider.player!.stream.playing,
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data ?? videoProvider.player!.state.playing;
                      return IgnorePointer(
                        child: AnimatedPlayPauseButton(
                          isPlaying: isPlaying,
                          onPressed: () {},
                          color: context.themeInvertedTextColor,
                          size: isWide ? 40 : 32,
                        ),
                      );
                    }
                  )
                : IgnorePointer(
                    child: AnimatedPlayPauseButton(
                      isPlaying: playerProvider.isPlaying,
                      onPressed: () {},
                      color: context.themeInvertedTextColor,
                      size: isWide ? 40 : 32,
                    ),
                  ),
            ),
          ),
          BouncyIconButton(
            child: Icon(Icons.skip_next_rounded, color: context.themeTextColor, size: isWide ? 40 : 34),
            onPressed: () {
              ref.read(audioPlayerProvider.notifier).skipToNext();
            },
          ),
          BouncyIconButton(
            child: Icon(Icons.forward_10_rounded, color: context.themeMutedTextColor, size: isWide ? 28 : 24),
            onPressed: () {
              if (isVideoMode) {
                final settingsProv = ref.read(settingsProvider);
                final pos = videoProvider.player?.state.position ?? Duration.zero;
                final newPos = pos + const Duration(seconds: 15);
                videoProvider.player?.seek(newPos);
                if (!settingsProv.useVideoAudioSource) {
                  ref.read(audioPlayerProvider.notifier).seek(newPos);
                }
              } else {
                final pos = ref.read(audioPlayerProvider.notifier).engine.position;
                final newPos = pos + const Duration(seconds: 15);
                ref.read(audioPlayerProvider.notifier).seek(newPos);
              }
            },
          ),
        ],
      ),
    );
  }
}

class NowPlayingSecondaryControls extends ConsumerWidget {
  final bool isWide;
  final Color accentColor;

  const NowPlayingSecondaryControls({
    super.key,
    required this.isWide,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerProvider = ref.watch(audioPlayerProvider);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 20 : 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          BouncyIconButton(
            child: Icon(
              Icons.shuffle_rounded, 
              color: playerProvider.isShuffle ? accentColor : context.themeMutedTextColor, 
              size: 24,
            ),
            onPressed: () {
              ref.read(audioPlayerProvider.notifier).toggleShuffle();
            },
          ),
          BouncyIconButton(
            child: Icon(
              Icons.cell_tower_rounded, 
              color: playerProvider.isInRoom ? Colors.greenAccent : context.themeMutedTextColor, 
              size: 24,
            ),
            onPressed: () {
              if (playerProvider.isInRoom && playerProvider.isHost) {
                RoomBottomSheet.show(context, isHost: true);
              } else if (!playerProvider.isInRoom) {
                RoomBottomSheet.show(context, isHost: true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('You are already listening to a broadcast.'))
                );
              }
            },
          ),
          PopupMenuButton<double>(
            icon: Icon(Icons.speed_rounded, color: context.themeMutedTextColor, size: 24),
            initialValue: playerProvider.playbackSpeed,
            onSelected: (speed) => ref.read(audioPlayerProvider.notifier).setPlaybackSpeed(speed),
            itemBuilder: (context) {
              return [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((s) {
                return PopupMenuItem<double>(
                  value: s,
                  child: Text('${s}x', style: TextStyle(fontWeight: s == playerProvider.playbackSpeed ? FontWeight.bold : FontWeight.w500, fontSize: 14)),
                );
              }).toList();
            },
          ),
          BouncyIconButton(
            child: Icon(Icons.queue_music_rounded, color: context.themeMutedTextColor, size: 24),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const QueueBottomSheet(),
              );
            },
          ),
          BouncyIconButton(
            child: Icon(
              playerProvider.isRepeat ? Icons.repeat_one_rounded : Icons.repeat_rounded, 
              color: playerProvider.isRepeat ? accentColor : context.themeMutedTextColor, 
              size: 24,
            ),
            onPressed: () {
              ref.read(audioPlayerProvider.notifier).toggleRepeat();
            },
          ),
        ],
      ),
    );
  }
}
