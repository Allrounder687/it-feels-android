import 'package:it_feels_music/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
}
