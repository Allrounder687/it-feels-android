import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:it_feels_music/main.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';

extension ThemeContext on BuildContext {
  Color get themeTextColor => appProviderContainer.read(audioPlayerProvider).themeTextColor;
  Color get themeMutedTextColor => appProviderContainer.read(audioPlayerProvider).themeMutedTextColor;
  Color get themeInvertedTextColor => appProviderContainer.read(audioPlayerProvider).themeInvertedTextColor;
  Color get themeCardColor => appProviderContainer.read(audioPlayerProvider).themeCardColor;
  Color get themeTextColor10 => appProviderContainer.read(audioPlayerProvider).themeTextColor.withValues(alpha: 0.10);
  Color get themeTextColor12 => appProviderContainer.read(audioPlayerProvider).themeTextColor.withValues(alpha: 0.12);
  Color get themeTextColor24 => appProviderContainer.read(audioPlayerProvider).themeTextColor.withValues(alpha: 0.24);
  Color get themeBackgroundColor => appProviderContainer.read(audioPlayerProvider).themeBackgroundColor;
  Color get themeSurfaceColor => appProviderContainer.read(audioPlayerProvider).themeSurfaceColor;
  Color get themeAccentColor => appProviderContainer.read(audioPlayerProvider).themeAccentColor;
  Color get themePillColor => appProviderContainer.read(audioPlayerProvider).themePillColor;
  Color get themeUnselectedPillColor => appProviderContainer.read(audioPlayerProvider).themeUnselectedPillColor;
  Color get themeUnselectedPillTextColor => appProviderContainer.read(audioPlayerProvider).themeUnselectedPillTextColor;
  Color get themeNavPillColor => appProviderContainer.read(audioPlayerProvider).themeNavPillColor;
  Color get themeNavPillTextColor => appProviderContainer.read(audioPlayerProvider).themeNavPillTextColor;

  /// True when Glass theme is selected AND running on a desktop platform.
  bool get isGlassTheme {
    final mode = appProviderContainer.read(audioPlayerProvider).appThemeMode;
    if (mode != AppThemeMode.glass) return false;
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// Returns contrast-guard text shadows when Glass theme is active.
  /// Use with TextStyle: `shadows: context.themeTextShadow`
  List<Shadow> get themeTextShadow => isGlassTheme
      ? const [Shadow(offset: Offset(0, 1), blurRadius: 4.0, color: Color(0xCC000000))]
      : const [];
}
