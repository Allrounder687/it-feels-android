import 'package:flutter/material.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

class HoverableLink extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final TextStyle? style;

  const HoverableLink({
    super.key,
    required this.text,
    required this.onTap,
    this.style,
  });

  @override
  State<HoverableLink> createState() => _HoverableLinkState();
}

class _HoverableLinkState extends State<HoverableLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (widget.style ?? const TextStyle()).copyWith(
            color: _isHovered ? context.themeTextColor : context.themeMutedTextColor,
            decoration: _isHovered ? TextDecoration.underline : TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
