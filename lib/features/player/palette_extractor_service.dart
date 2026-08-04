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
  Future<PaletteExtractorResult?> extract(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    
    try {
      if (await DeviceUtils.isLowRamDevice()) {
        return null; // Return null so the caller can fallback to default/midnight
      }

      if (imageUrl.startsWith('http')) {
        final res = await PaletteExtractor.extractPalette(imageUrl);
        if (res != null) {
          return PaletteExtractorResult(
            backgroundColor: Color(res.background),
            surfaceColor: Color(res.surface),
            accentColor: Color(res.accent),
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
        
        int adjustBrightness(Color color, double factor) {
          int r = (color.r * 255 * factor).clamp(0, 255).toInt();
          int g = (color.g * 255 * factor).clamp(0, 255).toInt();
          int b = (color.b * 255 * factor).clamp(0, 255).toInt();
          return (0xff << 24) | (r << 16) | (g << 8) | b;
        }
        
        return PaletteExtractorResult(
          backgroundColor: Color(adjustBrightness(dominantColor, 0.4)),
          surfaceColor: Color(adjustBrightness(dominantColor, 0.6)),
          accentColor: Color(adjustBrightness(dominantColor, 1.5)),
        );
      }
    } catch (e) {
      debugPrint('[PaletteExtractorService] Palette extraction error: $e');
    }
    return null;
  }
}
