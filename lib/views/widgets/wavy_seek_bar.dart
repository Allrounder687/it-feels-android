import 'dart:math' as math;
import 'package:flutter/material.dart';

class WavySeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration>? onSeek;
  final Color activeColor;
  final Color inactiveColor;

  const WavySeekBar({
    super.key,
    required this.position,
    required this.duration,
    this.onSeek,
    this.activeColor = Colors.pinkAccent,
    this.inactiveColor = Colors.white24,
  });

  @override
  State<WavySeekBar> createState() => _WavySeekBarState();
}

class _WavySeekBarState extends State<WavySeekBar> with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _handleSeek(Offset localPosition, double width) {
    if (widget.duration.inMilliseconds == 0 || widget.onSeek == null) return;
    double dx = localPosition.dx.clamp(0.0, width);
    double fraction = dx / width;
    final newPos = Duration(milliseconds: (widget.duration.inMilliseconds * fraction).round());
    widget.onSeek!(newPos);
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = math.max(1, widget.duration.inMilliseconds);
    final posMs = widget.position.inMilliseconds.clamp(0, maxMs);
    final fraction = posMs / maxMs;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) => _handleSeek(details.localPosition, width),
          onTapDown: (details) => _handleSeek(details.localPosition, width),
          child: AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return CustomPaint(
                size: Size(width, 36),
                painter: _WavySeekBarPainter(
                  fraction: fraction,
                  wavePhase: _waveController.value * 2 * math.pi,
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

class _WavySeekBarPainter extends CustomPainter {
  final double fraction;
  final double wavePhase;
  final Color activeColor;
  final Color inactiveColor;

  _WavySeekBarPainter({
    required this.fraction,
    required this.wavePhase,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final activeWidth = size.width * fraction;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;


    final inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // 1. Draw Active Wavy Path
    if (activeWidth > 0) {
      final wavePath = Path();
      const amplitude = 3.5;
      const wavelength = 18.0;

      wavePath.moveTo(0, midY);
      for (double x = 0; x <= activeWidth; x += 1.0) {
        final y = midY + amplitude * math.sin((x / wavelength) * 2 * math.pi - wavePhase);
        wavePath.lineTo(x, y);
      }
      canvas.drawPath(wavePath, activePaint);
    }

    // 2. Draw Inactive Straight Path
    if (activeWidth < size.width) {
      final inactivePath = Path();
      inactivePath.moveTo(activeWidth, midY);
      inactivePath.lineTo(size.width, midY);
      canvas.drawPath(inactivePath, inactivePaint);
    }

    // 3. Draw Thumb Indicator
    final thumbPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(activeWidth, midY), 7.0, thumbPaint);
  }

  @override
  bool shouldRepaint(covariant _WavySeekBarPainter oldDelegate) => true;
}
