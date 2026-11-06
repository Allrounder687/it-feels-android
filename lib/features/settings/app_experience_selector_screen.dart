import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/appearance/app_experience.dart';
import 'package:it_feels_music/core/appearance/app_experience_provider.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/features/settings/settings_provider.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

class AppExperienceSelectorScreen extends ConsumerWidget {
  const AppExperienceSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeExperience = ref.watch(appExperienceProvider);

    return Scaffold(
      backgroundColor: context.themeBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.themeTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'App Experience',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: context.themeTextColor,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            Text(
              'Choose Your Visual Experience',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: context.themeTextColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Switch between the battle-tested Classic interface and the 2026 Next-Gen discovery experience. Audio playback continues seamlessly.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: context.themeMutedTextColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Card 1: Classic Experience
            _buildExperienceCard(
              context: context,
              ref: ref,
              experience: AppExperience.classic,
              isSelected: activeExperience == AppExperience.classic,
              tag: 'STABLE DEFAULT',
              tagColor: Colors.blueAccent,
              title: 'Classic Experience',
              subtitle: 'The original, production-tested IT Feels interface with familiar desktop sidebar, mobile dock, and rock-solid stability.',
              features: const [
                'Familiar desktop navigation & mobile dock',
                'Floating mini-player & lyrics overlay',
                'Original Category tab sliders',
                '100% lightweight & resource-friendly',
              ],
              previewGradient: const [Color(0xFF1E293B), Color(0xFF0F172A)],
              previewIcon: Icons.view_quilt_rounded,
            ),

            const SizedBox(height: 20),

            // Card 2: New Experience (2026 Next-Gen)
            _buildExperienceCard(
              context: context,
              ref: ref,
              experience: AppExperience.newExperience,
              isSelected: activeExperience == AppExperience.newExperience,
              tag: '2026 NEXT-GEN',
              tagColor: AppColors.midnightAccent,
              title: 'New Experience (2026)',
              subtitle: 'Completely redesigned luxury music experience with adaptive 3-pane desktop layout, dynamic artwork ambient mesh, and deep discovery.',
              features: const [
                'Adaptive 3-pane desktop shell with contextual panel',
                'Dynamic cover art ambient mesh & glass refraction',
                'Deep editorial feeds & daily mix clustering',
                'Immersive full-screen Now Playing & synchronized lyrics',
              ],
              previewGradient: const [Color(0xFF2E1065), Color(0xFF09090B)],
              previewIcon: Icons.auto_awesome_rounded,
            ),

            const SizedBox(height: 28),

            // Info note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.themeSurfaceColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: context.themeMutedTextColor.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: context.themeMutedTextColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Live switching preserves active audio playback, queue order, downloaded tracks, and all user playlists. You can change this at any time.',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: context.themeMutedTextColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildExperienceCard({
    required BuildContext context,
    required WidgetRef ref,
    required AppExperience experience,
    required bool isSelected,
    required String tag,
    required Color tagColor,
    required String title,
    required String subtitle,
    required List<String> features,
    required List<Color> previewGradient,
    required IconData previewIcon,
  }) {
    final borderColor = isSelected
        ? tagColor
        : context.themeMutedTextColor.withValues(alpha: 0.15);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: context.themeSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: tagColor.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual Mockup Banner
          Container(
            height: 110,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              gradient: LinearGradient(
                colors: previewGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: tagColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: tagColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Icon(previewIcon, color: Colors.white, size: 28),
                ),
              ],
            ),
          ),

          // Content Section
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: context.themeTextColor.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),

                // Feature Checklist
                ...features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: isSelected ? tagColor : context.themeMutedTextColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: context.themeMutedTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected
                          ? tagColor
                          : context.themeSurfaceColor.withValues(alpha: 0.8),
                      foregroundColor: isSelected ? Colors.black : context.themeTextColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? Colors.transparent
                              : context.themeMutedTextColor.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      ref.read(appExperienceProvider.notifier).setExperience(experience);
                      // Also sync legacy SettingsNotifier if needed
                      final legacyMode = experience == AppExperience.newExperience
                          ? UiExperienceMode.appleNeo
                          : UiExperienceMode.classic;
                      ref.read(settingsProvider.notifier).setUiExperienceMode(legacyMode);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Switched to ${experience.displayName}. Playback continues uninterrupted.',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: tagColor.withValues(alpha: 0.95),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isSelected) ...[
                          const Icon(Icons.check_rounded, size: 18, color: Colors.black),
                          const SizedBox(width: 8),
                          Text(
                            'Currently Active',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ] else ...[
                          Icon(Icons.swap_horiz_rounded, size: 18, color: context.themeTextColor),
                          const SizedBox(width: 8),
                          Text(
                            'Switch to $title',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.themeTextColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
