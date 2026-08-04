import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.15 + (_controller.value * 0.15)),
                blurRadius: 80 + (_controller.value * 60),
                spreadRadius: 20 + (_controller.value * 30),
              ),
            ],
          ),
        );
      },
    );
  }
}
