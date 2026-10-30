import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

class NeoPlaybackControls extends ConsumerStatefulWidget {
  final Color accentColor;

  const NeoPlaybackControls({
    super.key,
    required this.accentColor,
  });

  @override
  ConsumerState<NeoPlaybackControls> createState() => _NeoPlaybackControlsState();
}

class _NeoPlaybackControlsState extends ConsumerState<NeoPlaybackControls> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);
    final isPlaying = playerState.isPlaying;
    final isShuffle = playerState.isShuffle;
    final isRepeat = playerState.isRepeat;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Shuffle Toggle
        IconButton(
          iconSize: 22,
          icon: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.shuffle_rounded,
                color: isShuffle ? widget.accentColor : Colors.white38,
              ),
              if (isShuffle)
                Positioned(
                  bottom: 0,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: widget.accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            notifier.toggleShuffle();
          },
          tooltip: 'Shuffle',
        ),

        // Skip Previous
        IconButton(
          iconSize: 34,
          icon: const Icon(
            Icons.skip_previous_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            notifier.skipToPrevious();
          },
          tooltip: 'Previous',
        ),

        // Prominent Play/Pause Button (64dp with spring scale and glow aura)
        GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: () {
            HapticFeedback.mediumImpact();
            notifier.togglePlayPause();
          },
          child: AnimatedScale(
            scale: _isPressed ? 0.88 : 1.0,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.40),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                  const BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 36,
                  color: const Color(0xFF0D111A),
                ),
              ),
            ),
          ),
        ),

        // Skip Next
        IconButton(
          iconSize: 34,
          icon: const Icon(
            Icons.skip_next_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            notifier.skipToNext();
          },
          tooltip: 'Next',
        ),

        // Repeat Mode Toggle
        IconButton(
          iconSize: 22,
          icon: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                isRepeat ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                color: isRepeat ? widget.accentColor : Colors.white38,
              ),
              if (isRepeat)
                Positioned(
                  bottom: 0,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: widget.accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            notifier.toggleRepeat();
          },
          tooltip: 'Repeat',
        ),
      ],
    );
  }
}
