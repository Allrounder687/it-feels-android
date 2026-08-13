import 'dart:io';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/core/utils/device_utils.dart';
import 'package:it_feels_music/core/utils/palette_extractor_isolate.dart';

class PaletteExtractorResult {
  final Color backgroundColor;
  final Color surfaceColor;
  final Color accentColor;

  PaletteExtractorResult({
    required this.backgroundColor,
    required this.surfaceColor,
    required this.accentColor,
  });
}

class PaletteExtractorService {
  Color _adjustBackgroundColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness(hsl.lightness.clamp(0.01, 0.08)).toColor();
  }

  Color _adjustSurfaceColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness(hsl.lightness.clamp(0.03, 0.12)).toColor();
  }

  Color _adjustAccentColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness(hsl.lightness.clamp(0.4, 0.8)).toColor();
  }

  @visibleForTesting
  static Future<PaletteResult?> Function(String imageUrl)? customExtractor;

  Future<PaletteExtractorResult?> extract(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    
    try {
      if (await DeviceUtils.isLowRamDevice()) {
        return null; // Return null so the caller can fallback to default/midnight
      }

      if (imageUrl.startsWith('http')) {
        final res = customExtractor != null
            ? await customExtractor!(imageUrl)
            : await PaletteExtractor.extractPalette(imageUrl);
        if (res != null) {
          return PaletteExtractorResult(
            backgroundColor: _adjustBackgroundColor(Color(res.background)),
            surfaceColor: _adjustSurfaceColor(Color(res.surface)),
            accentColor: _adjustAccentColor(Color(res.accent)),
          );
        }
      } else {
        // Fallback for local files
        final ImageProvider imageProvider = FileImage(File(imageUrl));
        final palette = await PaletteGenerator.fromImageProvider(
          imageProvider,
          size: const Size(100, 100),
          maximumColorCount: 10,
        );
        final dominantColor = palette.dominantColor?.color ?? AppColors.midnightBackground;
        
        return PaletteExtractorResult(
          backgroundColor: _adjustBackgroundColor(dominantColor),
          surfaceColor: _adjustSurfaceColor(dominantColor),
          accentColor: _adjustAccentColor(dominantColor),
        );
      }
    } catch (e) {
      debugPrint('[PaletteExtractorService] Palette extraction error: $e');
    }
    return null;
  }
}
