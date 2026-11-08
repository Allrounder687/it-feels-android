import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'new_experience_tokens.dart';

/// Centralized layout coordinator that calculates accurate viewport bottom insets,
/// preventing content from being obscured behind floating MiniPlayer, BottomNavDock,
/// and OS system navigation bars across mobile, tablet, and desktop viewports.
class ContentViewportInsets {
  /// Height of the floating Mobile Navigation Dock including margins and padding
  static const double mobileNavDockHeight = 68.0;

  /// Height of the floating MiniPlayer including margins, progress bar, and pill padding
  static const double miniPlayerHeight = 74.0;

  /// Extra breathing room above persistent controls
  static const double comfortPadding = 20.0;

  /// Calculates the dynamic bottom clearance needed for scrollable views
  static double bottom(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < NewExperienceTokens.breakpointMedium;

    if (!isMobile) {
      // On desktop and tablet, player bar sits in a linear Column outside the viewport
      return 28.0;
    }

    bool hasPlayingSong = false;
    try {
      hasPlayingSong = ref.watch(
        audioPlayerProvider.select((s) => s.currentSong != null),
      );
    } catch (_) {}
    final systemBottomInset = MediaQuery.paddingOf(context).bottom;

    double clearance = mobileNavDockHeight + systemBottomInset + comfortPadding;
    if (hasPlayingSong) {
      clearance += miniPlayerHeight;
    }
    return clearance;
  }

  /// Reusable Sliver spacer for CustomScrollView / sliver lists
  static Widget sliverBottomSpacer(BuildContext context, WidgetRef ref) {
    return SliverToBoxAdapter(
      child: SizedBox(height: bottom(context, ref)),
    );
  }

  /// Reusable Box spacer for standard Column / ListView
  static Widget bottomSpacer(BuildContext context, WidgetRef ref) {
    return SizedBox(height: bottom(context, ref));
  }

  /// Helper providing scrollable content padding with dynamic bottom clearance
  static EdgeInsets scrollPadding(
    BuildContext context,
    WidgetRef ref, {
    double horizontal = 20.0,
    double top = 16.0,
  }) {
    return EdgeInsets.only(
      left: horizontal,
      right: horizontal,
      top: top,
      bottom: bottom(context, ref),
    );
  }
}
