import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/core/utils/palette_extractor_isolate.dart';
import 'package:it_feels_music/features/player/palette_extractor_service.dart';

void main() {
  late PaletteExtractorService service;

  setUp(() {
    service = PaletteExtractorService();
    PaletteExtractorService.customExtractor = null;
  });

  group('PaletteExtractorService basic checks', () {
    test('extract returns null if url is null or empty', () async {
      expect(await service.extract(null), isNull);
      expect(await service.extract(''), isNull);
    });
  });

  group('PaletteExtractorService color adjustment / clamping', () {
    test('correctly clamps colors with high lightness to premium HSL dark limits', () async {
      // Setup a bright white color (high lightness = 1.0)
      final brightColor = const HSLColor.fromAHSL(1.0, 0.0, 0.0, 1.0).toColor();
      
      PaletteExtractorService.customExtractor = (url) async {
        return PaletteResult(
          brightColor.toARGB32(),
          brightColor.toARGB32(),
          brightColor.toARGB32(),
        );
      };

      final result = await service.extract('https://example.com/art.jpg');
      expect(result, isNotNull);

      final bgHsl = HSLColor.fromColor(result!.backgroundColor);
      final surfaceHsl = HSLColor.fromColor(result.surfaceColor);
      final accentHsl = HSLColor.fromColor(result.accentColor);

      // Background lightness must be capped at 8% (0.08). We use 0.01 tolerance due to 8-bit color quantization.
      expect(bgHsl.lightness, closeTo(0.08, 0.01));

      // Surface lightness must be capped at 12% (0.12)
      expect(surfaceHsl.lightness, closeTo(0.12, 0.01));

      // Accent lightness must be capped at 80% (0.8)
      expect(accentHsl.lightness, closeTo(0.8, 0.01));
    });

    test('correctly clamps colors with low lightness to minimum HSL dark limits', () async {
      // Setup a pitch black color (lightness = 0.0)
      final blackColor = const HSLColor.fromAHSL(1.0, 0.0, 0.0, 0.0).toColor();
      
      PaletteExtractorService.customExtractor = (url) async {
        return PaletteResult(
          blackColor.toARGB32(),
          blackColor.toARGB32(),
          blackColor.toARGB32(),
        );
      };

      final result = await service.extract('https://example.com/art.jpg');
      expect(result, isNotNull);

      final bgHsl = HSLColor.fromColor(result!.backgroundColor);
      final surfaceHsl = HSLColor.fromColor(result.surfaceColor);
      final accentHsl = HSLColor.fromColor(result.accentColor);

      // Background lightness must be clamped up to 1% (0.01). We use 0.01 tolerance due to 8-bit color quantization.
      expect(bgHsl.lightness, closeTo(0.01, 0.01));

      // Surface lightness must be clamped up to 3% (0.03)
      expect(surfaceHsl.lightness, closeTo(0.03, 0.01));

      // Accent lightness must be clamped up to 40% (0.4)
      expect(accentHsl.lightness, closeTo(0.4, 0.01));
    });
  });
}
