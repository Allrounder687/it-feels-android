import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/player/palette_extractor_service.dart';
import 'new_experience_tokens.dart';

class NewAmbientCanvas extends ConsumerWidget {
  final Widget child;
  final double intensity;

  const NewAmbientCanvas({
    super.key,
    required this.child,
    this.intensity = 0.35,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(audioPlayerProvider.select((s) => s.currentSong));
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return FutureBuilder<PaletteExtractorResult?>(
      future: currentSong != null
          ? PaletteExtractorService().extract(currentSong.image)
          : Future.value(null),
      builder: (context, snapshot) {
        final res = snapshot.data;
        final primaryColor = res?.accentColor ?? const Color(0xFF3B0764);
        final secondaryColor = res?.surfaceColor ?? const Color(0xFF0F172A);

        return Stack(
          children: [
            // Deep base background
            Container(color: NewExperienceTokens.obsidianBackground),

            // Animated Radial Ambient Lighting
            if (!disableAnimations)
              Positioned.fill(
                child: TweenAnimationBuilder<Color?>(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOutCubic,
                  tween: ColorTween(
                    begin: NewExperienceTokens.obsidianBackground,
                    end: primaryColor.withValues(alpha: intensity),
                  ),
                  builder: (context, color, _) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.6, -0.7),
                          radius: 1.3,
                          colors: [
                            color ?? Colors.transparent,
                            secondaryColor.withValues(alpha: intensity * 0.4),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Active Child Viewport
            child,
          ],
        );
      },
    );
  }
}
