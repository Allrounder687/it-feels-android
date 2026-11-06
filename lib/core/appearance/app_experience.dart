import 'package:flutter/material.dart';

/// Supported independent application visual experiences.
enum AppExperience {
  /// The battle-tested, classic IT Feels Music interface.
  /// Preserves the original desktop and mobile layouts with 100% fidelity.
  classic,

  /// The next-generation 2026 music experience.
  /// Features an adaptive 3-pane desktop layout, dynamic cover art ambient canvas,
  /// fluid mobile navigation, and deep discovery.
  newExperience;

  String get displayName {
    switch (this) {
      case AppExperience.classic:
        return 'Classic Experience';
      case AppExperience.newExperience:
        return 'New Experience (2026)';
    }
  }

  String get shortLabel {
    switch (this) {
      case AppExperience.classic:
        return 'Classic';
      case AppExperience.newExperience:
        return 'Next-Gen 2026';
    }
  }

  String get description {
    switch (this) {
      case AppExperience.classic:
        return 'Original IT Feels Music interface with familiar navigation, floating mini-player, and rock-solid stability.';
      case AppExperience.newExperience:
        return 'Luxury 2026 music experience with adaptive desktop 3-pane layout, dynamic ambient art mesh, and immersive discovery.';
    }
  }

  IconData get icon {
    switch (this) {
      case AppExperience.classic:
        return Icons.dashboard_customize_rounded;
      case AppExperience.newExperience:
        return Icons.auto_awesome_rounded;
    }
  }

  bool get isClassic => this == AppExperience.classic;
  bool get isNewExperience => this == AppExperience.newExperience;
}
