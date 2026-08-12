import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

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

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: shieldColor,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
