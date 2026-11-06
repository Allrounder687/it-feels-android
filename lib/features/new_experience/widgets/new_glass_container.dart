import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/new_experience_tokens.dart';

class NewGlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Border? border;
  final VoidCallback? onTap;

  const NewGlassContainer({
    super.key,
    required this.child,
    this.blur = NewExperienceTokens.blurStandard,
    this.borderRadius = NewExperienceTokens.radiusMedium,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor ?? NewExperienceTokens.elevatedGlass.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ?? Border.all(color: NewExperienceTokens.specularBorder, width: 1),
            ),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      );
    }
    return content;
  }
}
