import 'package:flutter/material.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

/// A reusable container that renders as a glassmorphic card when the Glass
/// theme is active on desktop, and falls back to the standard [themeCardColor]
/// on all other themes and platforms.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? overrideColor;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 12.0,
    this.padding,
    this.margin,
    this.overrideColor,
  });

  @override
  Widget build(BuildContext context) {
    final isGlass = context.isGlassTheme;
    return Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: overrideColor ?? (isGlass
            ? const Color(0x0DFFFFFF) // 5% white
            : context.themeCardColor),
        borderRadius: BorderRadius.circular(borderRadius),
        border: isGlass
            ? Border.all(color: const Color(0x1FFFFFFF), width: 1.0) // 12% white border
            : null,
      ),
      child: child,
    );
  }
}
