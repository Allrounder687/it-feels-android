import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

/// A custom animated seek bar with a wavy progress indicator.
///
/// This widget displays the current audio playback [position] relative to the
/// total [duration]. It features a dynamically animated wave effect for the
/// active portion of the seek bar and allows users to seek to a new position
/// via horizontal drag or tap gestures.
///
/// It uses a [CustomPaint] to render the wavy path and a [AnimationController]
/// to drive the wave animation.
class WavySeekBar extends StatefulWidget {
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
  State<WavySeekBar> createState() => _WavySeekBarState();
}

class _WavySeekBarState extends State<WavySeekBar> with SingleTickerProviderStateMixin {
  /// Controller for the continuous wave animation.
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this, // Provides the ticker for the animation
      duration: const Duration(seconds: 3), // Duration of one full wave cycle
    )..repeat(); // Makes the wave animation loop indefinitely
  }

  @override
  void dispose() {
    _waveController.dispose(); // Release resources when the widget is removed
    super.dispose();
  }

  /// Handles user interaction (tap or horizontal drag) to seek to a new position.
  ///
  /// - [localPosition]: The [Offset] of the touch event relative to the widget.
  /// - [width]: The total width of the seek bar.
  ///
  /// Logic:
  /// 1. Clamps the horizontal position (`dx`) within the widget's bounds.
  /// 2. Calculates the `fraction` of the total width corresponding to the seek position.
  /// 3. Computes the `newPos` [Duration] based on the `fraction` and total `duration`.
  /// 4. Invokes the `onSeek` callback if provided.
  void _handleSeek(Offset localPosition, double width) {
    // Prevent seeking if duration is zero or no onSeek callback is provided
    if (widget.duration.inMilliseconds == 0 || widget.onSeek == null) return;
    double dx = localPosition.dx.clamp(0.0, width); // Clamp position to bounds
    double fraction = dx / width; // Calculate the fractional position
    final newPos = Duration(milliseconds: (widget.duration.inMilliseconds * fraction).round());
    widget.onSeek!(newPos);
  }

  @override
  Widget build(BuildContext context) {
    // Ensure duration is not zero to prevent division by zero
    final maxMs = math.max(1, widget.duration.inMilliseconds);
    // Clamp current position to be within valid range [0, duration]
    final posMs = widget.position.inMilliseconds.clamp(0, maxMs);
    final fraction = posMs / maxMs; // Calculate the played fraction

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth; // Get the available width for the seek bar
        return GestureDetector(
          behavior: HitTestBehavior.opaque, // Ensures the entire area is tappable
          onHorizontalDragUpdate: (details) => _handleSeek(details.localPosition, width),
          onTapDown: (details) => _handleSeek(details.localPosition, width),
          child: AnimatedBuilder(
            animation: _waveController, // Rebuilds when _waveController updates
            builder: (context, child) {
              return CustomPaint(
                size: Size(width, 36), // Fixed height for the seek bar
                painter: _WavySeekBarPainter(
                  fraction: fraction, // Progress of the seek bar
                  wavePhase: _waveController.value * 2 * math.pi, // Current phase of the wave animation
                  activeColor: widget.activeColor,
                  inactiveColor: widget.inactiveColor,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// A [CustomPainter] responsible for drawing the wavy seek bar.
/// It renders an active (played) wavy path, an inactive (unplayed) straight path,
/// and a circular thumb indicator.
class _WavySeekBarPainter extends CustomPainter {
  /// The fraction of the seek bar that is active (played).
  final double fraction;

  /// The current phase offset for the wave animation, driven by an [AnimationController].
  final double wavePhase;

  /// The color for the active part of the seek bar and the thumb.
  final Color activeColor;

  /// The color for the inactive part of the seek bar.
  final Color inactiveColor;

  /// Creates a `_WavySeekBarPainter`.
  _WavySeekBarPainter({
    required this.fraction,
    required this.wavePhase,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2; // Vertical center of the seek bar
    final activeWidth = size.width * fraction; // Width of the active (played) portion

    // Paint for the active wavy path
    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5 // Thickness of the line
      ..strokeCap = StrokeCap.round; // Rounded ends for line segments

    // Paint for the inactive straight path
    final inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // 1. Draw Active Wavy Path
    if (activeWidth > 0) {
      final wavePath = Path();
      const amplitude = 3.5; // Height of the wave from the centerline
      const wavelength = 18.0; // Horizontal length of one full wave cycle

      wavePath.moveTo(0, midY); // Start drawing from the left center
      // Generate points for the sine wave up to the active width
      for (double x = 0; x <= activeWidth; x += 1.0) {
        // Calculate y-coordinate using a sine function, offset by wavePhase for animation
        final y = midY + amplitude * math.sin((x / wavelength) * 2 * math.pi - wavePhase);
        wavePath.lineTo(x, y);
      }
      canvas.drawPath(wavePath, activePaint); // Draw the generated wavy path
    }

    // 2. Draw Inactive Straight Path
    if (activeWidth < size.width) {
      final inactivePath = Path();
      inactivePath.moveTo(activeWidth, midY); // Start where the active path ends
      inactivePath.lineTo(size.width, midY); // Draw a straight line to the right end
      canvas.drawPath(inactivePath, inactivePaint);
    }

    // 3. Draw Thumb Indicator
    final thumbPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill; // Solid circle

    // Draw a circle at the end of the active path
    canvas.drawCircle(Offset(activeWidth, midY), 7.0, thumbPaint);
  }

  @override
  /// Specifies that the painter should always repaint when its delegate changes.
  /// This is necessary because the `wavePhase` changes constantly due to the animation,
  /// and `fraction` can change with playback progress.
  bool shouldRepaint(covariant _WavySeekBarPainter oldDelegate) => true;
}
