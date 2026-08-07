import 'dart:math' as math;
import 'package:flutter/material.dart';

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
  
  // Reusable paint and path objects to prevent GC churn at 60fps
  late final Paint _activePaint;
  late final Paint _inactivePaint;
  late final Paint _thumbPaint;
  final Path _wavePath = Path();
  final Path _inactivePath = Path();

  @override
  void initState() {
    super.initState();
    _activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
      
    _inactivePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
      
    _thumbPaint = Paint()..style = PaintingStyle.fill;
    
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
  void _handleSeek(Offset localPosition, double width) {
    if (widget.duration.inMilliseconds == 0 || widget.onSeek == null) return;
    double dx = localPosition.dx.clamp(0.0, width); 
    double fraction = dx / width; 
    final newPos = Duration(milliseconds: (widget.duration.inMilliseconds * fraction).round());
    widget.onSeek!(newPos);
  }

  @override
  Widget build(BuildContext context) {
    // Update paint colors dynamically
    _activePaint.color = widget.activeColor;
    _inactivePaint.color = widget.inactiveColor;
    _thumbPaint.color = widget.activeColor;

    final maxMs = math.max(1, widget.duration.inMilliseconds);
    final posMs = widget.position.inMilliseconds.clamp(0, maxMs);
    final fraction = posMs / maxMs; 

    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth; 
          return GestureDetector(
            behavior: HitTestBehavior.opaque, 
            onHorizontalDragUpdate: (details) => _handleSeek(details.localPosition, width),
            onTapDown: (details) => _handleSeek(details.localPosition, width),
            child: AnimatedBuilder(
              animation: _waveController, 
              builder: (context, child) {
                return RepaintBoundary(
                  child: CustomPaint(
                    size: Size(width, 36), 
                    painter: _WavySeekBarPainter(
                      fraction: fraction, 
                      wavePhase: _waveController.value * 2 * math.pi, 
                      activePaint: _activePaint,
                      inactivePaint: _inactivePaint,
                      thumbPaint: _thumbPaint,
                      wavePath: _wavePath,
                      inactivePath: _inactivePath,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// A [CustomPainter] responsible for drawing the wavy seek bar.
class _WavySeekBarPainter extends CustomPainter {
  final double fraction;
  final double wavePhase;
  
  // Passed-in cached objects
  final Paint activePaint;
  final Paint inactivePaint;
  final Paint thumbPaint;
  final Path wavePath;
  final Path inactivePath;

  _WavySeekBarPainter({
    required this.fraction,
    required this.wavePhase,
    required this.activePaint,
    required this.inactivePaint,
    required this.thumbPaint,
    required this.wavePath,
    required this.inactivePath,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2; 
    final activeWidth = size.width * fraction; 

    // 1. Draw Active Wavy Path
    if (activeWidth > 0) {
      wavePath.reset();
      const amplitude = 3.5; 
      const wavelength = 18.0; 

      wavePath.moveTo(0, midY); 
      for (double x = 0; x <= activeWidth; x += 4.0) {
        final y = midY + amplitude * math.sin((x / wavelength) * 2 * math.pi - wavePhase);
        wavePath.lineTo(x, y);
      }
      canvas.drawPath(wavePath, activePaint); 
    }

    // 2. Draw Inactive Straight Path
    if (activeWidth < size.width) {
      inactivePath.reset();
      inactivePath.moveTo(activeWidth, midY); 
      inactivePath.lineTo(size.width, midY); 
      canvas.drawPath(inactivePath, inactivePaint);
    }

    // 3. Draw Thumb Indicator
    canvas.drawCircle(Offset(activeWidth, midY), 7.0, thumbPaint);
  }

  @override
  bool shouldRepaint(covariant _WavySeekBarPainter oldDelegate) => true;
}
