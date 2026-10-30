import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/settings/settings_provider.dart';

class NeoTokens {
  static const double dockMiniPlayerHeight = 58.0;
  static const double dockNavBarHeight = 56.0;
  static const double squircleRadius = 24.0;
  static const double islandRadius = 20.0;
  static const double cardRadius = 18.0;
  static const double specularBorderWidth = 1.0;

  static const Color specularBorderColor = Color(0x1FFFFFFF); // #FFFFFF 12%
  static const Color frostedSurface = Color(0xCC0E1320);     // 80% dark obsidian
  static const Color frostedSurfaceLight = Color(0xB3151D30);// 70% dark indigo
}

/// High-Performance Frosted Glass Container isolated in a RepaintBoundary
class NeoGlassContainer extends ConsumerWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;

  const NeoGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = NeoTokens.islandRadius,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = NeoTokens.specularBorderWidth,
    this.shadows,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final graphicsQuality = settings.graphicsQuality;

    double blurSigma = 6.0;
    if (graphicsQuality == GraphicsQuality.medium) blurSigma = 3.5;
    if (graphicsQuality == GraphicsQuality.low || kDebugMode) blurSigma = 0.0;

    final defaultBg = backgroundColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? NeoTokens.frostedSurface
            : Colors.white.withValues(alpha: 0.85));

    final effectiveBorderColor = borderColor ?? NeoTokens.specularBorderColor;

    final containerDecoration = BoxDecoration(
      color: blurSigma == 0.0 ? defaultBg.withValues(alpha: 0.95) : defaultBg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: effectiveBorderColor,
        width: borderWidth,
      ),
      boxShadow: shadows ??
          [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
    );

    Widget content = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: containerDecoration,
      child: child,
    );

    if (onTap != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: content,
      );
    }

    if (blurSigma <= 0.0) {
      return RepaintBoundary(child: content);
    }

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: content,
        ),
      ),
    );
  }
}
