import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/settings/settings_provider.dart';

/// Layer 2: Adaptive Dark Shield — only active on desktop + Glass theme
/// This intercepts the raw OS background with a heavy blur and dark tint.
class GlassShieldWrapper extends ConsumerWidget {
  final Widget child;
  final bool isGlassMode;

  const GlassShieldWrapper({
    super.key,
    required this.child,
    required this.isGlassMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isGlassMode) return child;
    
    final settings = ref.watch(settingsProvider);
    final audioProvider = ref.watch(audioPlayerProvider);
    
    final Color shieldColor = settings.adaptiveGlassTint 
        ? audioProvider.extractedBackgroundColor.withOpacity(0.65)
        : const Color(0xA60C0F16); // 65% dark midnight tint

    double blurAmount = 30.0;
    if (settings.graphicsQuality == GraphicsQuality.medium) {
      blurAmount = 15.0; // Reduced blur iterations for medium devices
    } else if (settings.graphicsQuality == GraphicsQuality.low) {
      blurAmount = 0.0; // Completely disable Skia blur on low devices
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            // Increase opacity heavily if blur is disabled to maintain readability against the native OS acrylic background
            color: blurAmount == 0.0 ? shieldColor.withOpacity(0.95) : shieldColor,
            child: blurAmount > 0.0
                ? BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
                    child: const SizedBox.expand(),
                  )
                : const SizedBox.expand(),
          ),
        ),
        child,
      ],
    );
  }
}
