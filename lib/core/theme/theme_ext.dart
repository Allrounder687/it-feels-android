import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/audio_player_provider.dart';

extension ThemeContext on BuildContext {
  Color get themeTextColor => Provider.of<AudioPlayerProvider>(this).themeTextColor;
  Color get themeMutedTextColor => Provider.of<AudioPlayerProvider>(this).themeMutedTextColor;
  Color get themeInvertedTextColor => Provider.of<AudioPlayerProvider>(this).themeInvertedTextColor;
  Color get themeCardColor => Provider.of<AudioPlayerProvider>(this).themeCardColor;
  Color get themeTextColor10 => Provider.of<AudioPlayerProvider>(this).themeTextColor.withOpacity(0.10);
  Color get themeTextColor12 => Provider.of<AudioPlayerProvider>(this).themeTextColor.withOpacity(0.12);
  Color get themeTextColor24 => Provider.of<AudioPlayerProvider>(this).themeTextColor.withOpacity(0.24);
  Color get themeBackgroundColor => Provider.of<AudioPlayerProvider>(this).themeBackgroundColor;
  Color get themeSurfaceColor => Provider.of<AudioPlayerProvider>(this).themeSurfaceColor;
  Color get themeAccentColor => Provider.of<AudioPlayerProvider>(this).themeAccentColor;
}
