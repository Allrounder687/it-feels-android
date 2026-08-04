import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';

class TVFocusableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool autofocus;
  final double focusedScale;

  const TVFocusableCard({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.autofocus = false,
    this.focusedScale = 1.05,
  });

  @override
  State<TVFocusableCard> createState() => _TVFocusableCardState();
}

class _TVFocusableCardState extends State<TVFocusableCard> {
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Only apply TV/Desktop scaling if the screen is wide enough
    final isWide = MediaQuery.of(context).size.width > 600;

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (hasFocus) {
        setState(() {
          _isFocused = hasFocus;
        });
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
                          event.logicalKey == LogicalKeyboardKey.select ||
                          event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                          event.logicalKey == LogicalKeyboardKey.gameButtonA ||
                          event.logicalKey == LogicalKeyboardKey.space;
          
          if (isEnter) {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: AnimatedScale(
            scale: (isWide && (_isFocused || _isHovered)) ? widget.focusedScale : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: isWide && _isFocused
                    ? Border.all(color: AppColors.midnightAccent, width: 3)
                    : Border.all(color: Colors.transparent, width: 3),
                boxShadow: isWide && (_isFocused || _isHovered)
                    ? [
                        BoxShadow(
                          color: AppColors.midnightAccent.withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        )
                      ]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9), // slightly less than 12 to fit inside border
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
