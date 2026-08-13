import 'package:flutter/material.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

class AnimatedPlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onPressed;
  final double size;
  final Color? color;

  const AnimatedPlayPauseButton({
    super.key,
    required this.isPlaying,
    required this.onPressed,
    this.size = 38.0,
    this.color,
  });

  @override
  State<AnimatedPlayPauseButton> createState() => _AnimatedPlayPauseButtonState();
}

class _AnimatedPlayPauseButtonState extends State<AnimatedPlayPauseButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    if (widget.isPlaying) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedPlayPauseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: widget.onPressed,
      iconSize: widget.size,
      color: widget.color ?? context.themeInvertedTextColor,
      icon: ExcludeSemantics(
        child: AnimatedIcon(
          icon: AnimatedIcons.play_pause,
          progress: _controller,
        ),
      ),
    );
  }
}
