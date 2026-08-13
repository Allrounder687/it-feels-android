import 'package:flutter/material.dart';

class AnimatedEqualizer extends StatefulWidget {
  final Color color;
  const AnimatedEqualizer({super.key, required this.color});

  @override
  State<AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<AnimatedEqualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 24,
        height: 24,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildBar(0.3, 0.9),
            _buildBar(0.6, 1.0),
            _buildBar(0.2, 0.7),
            _buildBar(0.7, 0.9),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(double begin, double end) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Pseudo-random offset based on begin value
        final progress = (_controller.value + begin) % 1.0;
        final val = 0.2 + (0.8 * (progress > 0.5 ? 1.0 - progress : progress) * 2);
        
        return SizedBox(
          width: 3,
          height: 24,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Transform.scale(
              scaleY: val,
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 3,
                height: 24,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
