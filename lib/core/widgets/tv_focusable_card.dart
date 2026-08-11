import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';

final ValueNotifier<bool> isKeyboardNavigating = ValueNotifier(false);

class TVFocusableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool autofocus;
  final double focusedScale;
  final double borderRadius;

  const TVFocusableCard({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.autofocus = false,
    this.focusedScale = 1.05,
    this.borderRadius = 12.0,
  });

  @override
  State<TVFocusableCard> createState() => _TVFocusableCardState();
}

class _TVFocusableCardState extends State<TVFocusableCard> {
  bool _isFocused = false;
  bool _isHovered = false;

  bool get _shouldShowOutline {
    if (Platform.isMacOS || Platform.isIOS) {
      return false;
    }
    if (Platform.isAndroid) {
      if (FocusManager.instance.highlightMode == FocusHighlightMode.traditional) {
        return true;
      }
      return false;
    }
    if (Platform.isWindows || Platform.isLinux) {
      return isKeyboardNavigating.value;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Only apply TV/Desktop scaling if the screen is wide enough
    final isWide = MediaQuery.of(context).size.width > 600;
    
    return ValueListenableBuilder<bool>(
      valueListenable: isKeyboardNavigating,
      builder: (context, isKeyboardMode, child) {
        final showOutline = _shouldShowOutline && _isFocused;

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
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    border: showOutline
                        ? Border.all(color: AppColors.midnightAccent, width: 3)
                        : Border.all(color: Colors.transparent, width: 3),
                    boxShadow: isWide && (_isFocused || _isHovered) && 
                               !(Theme.of(context).platform == TargetPlatform.windows || 
                                 Theme.of(context).platform == TargetPlatform.macOS || 
                                 Theme.of(context).platform == TargetPlatform.linux)
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
                    borderRadius: BorderRadius.circular(widget.borderRadius > 3 ? widget.borderRadius - 3 : widget.borderRadius),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
