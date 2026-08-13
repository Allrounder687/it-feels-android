import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A custom animated seek bar with a wavy progress indicator.
///
/// This widget displays the current audio playback [position] relative to the
/// total [duration]. It features a dynamically animated wave effect for the
/// active portion of the seek bar and allows users to seek to a new position
/// via horizontal drag or tap gestures.
///
/// It uses a [CustomPaint] to render the wavy path and a [AnimationController]
/// to drive the wave animation.
class WavySeekBar extends ConsumerStatefulWidget {
  /// The current playback position of the audio.
  final Duration position;

  /// The total duration of the audio track.
  final Duration duration;

  /// Callback function invoked when the user seeks to a new position.
  final ValueChanged<Duration>? onSeek;

  /// The color of the active (played) portion of the seek bar and the thumb.
  final Color activeColor;

  /// The color of the inactive (unplayed) portion of the seek bar.
  final Color inactiveColor;

  /// Creates a [WavySeekBar] widget.
  ///
  /// - [position]: The current playback position.
  /// - [duration]: The total duration of the track.
  /// - [onSeek]: Optional callback for when the user interacts with the seek bar.
  /// - [activeColor]: Color for the played portion and thumb (defaults to `Colors.pinkAccent`).
  /// - [inactiveColor]: Color for the unplayed portion (defaults to `context.themeTextColor24`).
  /// - [inactiveColor]: Color for the unplayed portion (defaults to `Colors.grey`).
  const WavySeekBar({
    super.key,
    required this.position,
    required this.duration,
    this.onSeek,
    this.activeColor = Colors.pinkAccent,
    this.inactiveColor = Colors.grey,
  });

  @override
  ConsumerState<WavySeekBar> createState() => _WavySeekBarState();
}

class _WavySeekBarState extends ConsumerState<WavySeekBar> {
  bool _isDragging = false;
  double _dragFraction = 0.0;

  @override
  Widget build(BuildContext context) {
    final maxMs = math.max(1, widget.duration.inMilliseconds);
    final posMs = widget.position.inMilliseconds.clamp(0, maxMs);
    final fraction = _isDragging ? _dragFraction : posMs / maxMs;

    return ExcludeSemantics(
      child: SizedBox(
        height: 36,
        child: SliderTheme(
          data: SliderThemeData(
            trackHeight: 3.5,
            activeTrackColor: widget.activeColor,
            inactiveTrackColor: widget.inactiveColor,
            thumbColor: widget.activeColor,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: Slider(
            value: _isDragging ? _dragFraction : fraction,
            onChangeStart: (val) {
              setState(() {
                _isDragging = true;
                _dragFraction = val;
              });
            },
            onChanged: (val) {
              setState(() {
                _dragFraction = val;
              });
            },
            onChangeEnd: (val) {
              setState(() {
                _isDragging = false;
              });
              if (widget.onSeek != null) {
                final newPos = Duration(milliseconds: (maxMs * val).round());
                widget.onSeek!(newPos);
              }
            },
          ),
        ),
      ),
    );
  }
}
