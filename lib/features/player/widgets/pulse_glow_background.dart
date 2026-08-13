import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

class PulseGlowBackground extends ConsumerStatefulWidget {
  final Color color;
  final bool isPlaying;

  const PulseGlowBackground({super.key, required this.color, required this.isPlaying});

  @override
  ConsumerState<PulseGlowBackground> createState() => _PulseGlowBackgroundState();
}

class _PulseGlowBackgroundState extends ConsumerState<PulseGlowBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    if (widget.isPlaying) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PulseGlowBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(settingsProvider).enablePerformanceMode) {
      return const SizedBox.shrink();
    }
    
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 1.25).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  widget.color.withValues(alpha: 0.3),
                  widget.color.withValues(alpha: 0.0),
                ],
                stops: const [0.5, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
