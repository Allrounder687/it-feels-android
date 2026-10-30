import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Decoupled, RepaintBoundary-isolated Ambient Mesh Gradient Background
class NeoAmbientMesh extends StatefulWidget {
  final Color primaryColor;
  final Color accentColor;
  final Color darkMutedColor;
  final Widget? child;

  const NeoAmbientMesh({
    super.key,
    required this.primaryColor,
    required this.accentColor,
    required this.darkMutedColor,
    this.child,
  });

  @override
  State<NeoAmbientMesh> createState() => _NeoAmbientMeshState();
}

class _NeoAmbientMeshState extends State<NeoAmbientMesh>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base dark backdrop
        Container(color: const Color(0xFF090D16)),

        // Isolated Animated Canvas repainting without rebuilding the widget tree
        RepaintBoundary(
          child: CustomPaint(
            painter: _MeshPainter(
              animation: _controller,
              primaryColor: widget.primaryColor,
              accentColor: widget.accentColor,
              darkMutedColor: widget.darkMutedColor,
            ),
          ),
        ),

        // Deep vignette overlay for text contrast and readability
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.35),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.75),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),

        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _MeshPainter extends CustomPainter {
  final Animation<double> animation;
  final Color primaryColor;
  final Color accentColor;
  final Color darkMutedColor;

  _MeshPainter({
    required this.animation,
    required this.primaryColor,
    required this.accentColor,
    required this.darkMutedColor,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final t = animation.value * 2 * math.pi;

    // Node 1: Primary color orbital drift
    final cx1 = size.width * (0.35 + 0.20 * math.sin(t));
    final cy1 = size.height * (0.28 + 0.15 * math.cos(t));
    final r1 = size.width * 0.75;

    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: 0.45),
          primaryColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx1, cy1), radius: r1));

    canvas.drawCircle(Offset(cx1, cy1), r1, paint1);

    // Node 2: Accent color counter-orbital drift
    final cx2 = size.width * (0.65 + 0.22 * math.cos(t * 0.8));
    final cy2 = size.height * (0.62 + 0.18 * math.sin(t * 0.8));
    final r2 = size.width * 0.85;

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withValues(alpha: 0.35),
          accentColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx2, cy2), radius: r2));

    canvas.drawCircle(Offset(cx2, cy2), r2, paint2);

    // Node 3: Dark Muted grounding anchor
    final cx3 = size.width * (0.50 + 0.15 * math.sin(t * 0.5));
    final cy3 = size.height * (0.85 + 0.10 * math.cos(t * 0.5));
    final r3 = size.width * 0.90;

    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [
          darkMutedColor.withValues(alpha: 0.40),
          darkMutedColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx3, cy3), radius: r3));

    canvas.drawCircle(Offset(cx3, cy3), r3, paint3);
  }

  @override
  bool shouldRepaint(covariant _MeshPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.darkMutedColor != darkMutedColor;
  }
}
