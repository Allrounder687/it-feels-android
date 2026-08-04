import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:it_feels_music/data/models/cache_models.dart';
import 'package:it_feels_music/services/database_service.dart';

class PaletteResult {
  final int background;
  final int surface;
  final int accent;
  final bool isFailed;
  PaletteResult(this.background, this.surface, this.accent, {this.isFailed = false});
}

class PaletteExtractor {
  static final Map<String, PaletteResult> _memoryCache = {};
  static Timer? _debounceTimer;
  static int _generationToken = 0;
  static Completer<PaletteResult?>? _pendingCompleter;

  static Future<PaletteResult?> extractPalette(String imageUrl) async {
    if (imageUrl.isEmpty) return null;

    // 1. Check Memory
    if (_memoryCache.containsKey(imageUrl)) {
      final res = _memoryCache[imageUrl]!;
      return res.isFailed ? null : res;
    }

    // 2. Check Disk Cache
    try {
      final db = DatabaseService();
      await DatabaseService.ensureInitialized();
      if (db.isar != null && db.isar!.isOpen) {
        final cached = await db.isar!.cachedPalettes.filter().artworkUrlEqualTo(imageUrl).findFirst();
        if (cached != null) {
          final res = PaletteResult(cached.backgroundColorValue, cached.surfaceColorValue, cached.accentColorValue);
          _memoryCache[imageUrl] = res;
          return res;
        }
      }
    } catch (e) {
      debugPrint('[PaletteExtractor] Disk cache read error: $e');
    }

    // 3. Debounce and Isolate Extract
    final currentToken = ++_generationToken;

    _debounceTimer?.cancel();
    if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
      _pendingCompleter!.complete(null); // Cancel previous
    }

    _pendingCompleter = Completer<PaletteResult?>();

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final completerToComplete = _pendingCompleter;
      if (completerToComplete == null) return;

      try {
        final bytes = await _fetchAndDecode(imageUrl);
        if (bytes == null || currentToken != _generationToken) {
          _memoryCache[imageUrl] = PaletteResult(0, 0, 0, isFailed: true); // Negative caching
          if (!completerToComplete.isCompleted) completerToComplete.complete(null);
          return;
        }

        // Send to isolate
        final isolateResult = await compute(_extractDominantColors, bytes);
        if (currentToken != _generationToken) return;
        
        final res = PaletteResult(isolateResult[0], isolateResult[1], isolateResult[2]);
        _memoryCache[imageUrl] = res;

        // Save to disk cache
        try {
          final db = DatabaseService();
          await DatabaseService.ensureInitialized();
          if (db.isar != null && db.isar!.isOpen) {
            final cachedPalette = CachedPalette()
              ..artworkUrl = imageUrl
              ..backgroundColorValue = res.background
              ..surfaceColorValue = res.surface
              ..accentColorValue = res.accent
              ..cachedAt = DateTime.now();
            await db.isar!.writeTxn(() async {
              await db.isar!.cachedPalettes.put(cachedPalette);
            });
          }
        } catch (e) {
          debugPrint('[PaletteExtractor] Disk cache write error: $e');
        }

        if (!completerToComplete.isCompleted) completerToComplete.complete(res);
      } catch (e) {
        debugPrint('[PaletteExtractor] Extraction error: $e');
        _memoryCache[imageUrl] = PaletteResult(0, 0, 0, isFailed: true); // Negative caching
        if (!completerToComplete.isCompleted) completerToComplete.complete(null);
      }
    });

    return _pendingCompleter!.future;
  }

  static Future<Uint8List?> _fetchAndDecode(String url) async {
    try {
      final ByteData data = await NetworkAssetBundle(Uri.parse(url)).load(url);
      final Uint8List bytes = data.buffer.asUint8List();
      
      // Decode image and downsample on main thread (safe with Flutter UI APIs)
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ByteData? rawData = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      frame.image.dispose();
      
      if (rawData != null) {
        return rawData.buffer.asUint8List(); // Transferable raw RGBA bytes
      }
    } catch (e) {
      debugPrint('[PaletteExtractor] Fetch/Decode error: $e');
    }
    return null;
  }
}

// Top-level function for the background isolate
List<int> _extractDominantColors(Uint8List rgbaBytes) {
  // Simple algorithm to find the dominant colors from RGBA bytes
  // We divide the RGB space into buckets (e.g. 5x5x5 = 125 buckets)
  final Map<int, int> colorCounts = {};
  int maxCount = 0;
  int dominantColor = 0xff0f0f0f; // Default dark
  
  // Skip transparent pixels and sample every Nth pixel for speed
  for (int i = 0; i < rgbaBytes.length; i += 16) {
    int r = rgbaBytes[i];
    int g = rgbaBytes[i+1];
    int b = rgbaBytes[i+2];
    int a = rgbaBytes[i+3];
    
    if (a < 128) continue; // Skip mostly transparent
    
    // Group into 32x32x32 buckets (shift by 5)
    int rBucket = r >> 5;
    int gBucket = g >> 5;
    int bBucket = b >> 5;
    int bucketKey = (rBucket << 10) | (gBucket << 5) | bBucket;
    
    int count = (colorCounts[bucketKey] ?? 0) + 1;
    colorCounts[bucketKey] = count;
    
    if (count > maxCount) {
      maxCount = count;
      // Reconstruct approximate color
      dominantColor = (0xff << 24) | ((rBucket << 5) << 16) | ((gBucket << 5) << 8) | (bBucket << 5);
    }
  }

  // Generate slightly modified variants for background, surface, accent based on HSL logic
  // Since we are in an isolate, we cannot use Flutter's HSLColor class directly unless we write custom logic.
  // Instead, we will return the dominant color and two variants.
  
  int adjustBrightness(int color, double factor) {
    int r = (color >> 16) & 0xff;
    int g = (color >> 8) & 0xff;
    int b = color & 0xff;
    r = (r * factor).clamp(0, 255).toInt();
    g = (g * factor).clamp(0, 255).toInt();
    b = (b * factor).clamp(0, 255).toInt();
    return (0xff << 24) | (r << 16) | (g << 8) | b;
  }

  int background = adjustBrightness(dominantColor, 0.4); // Darkened
  int surface = adjustBrightness(dominantColor, 0.6); // Slightly lighter than background
  int accent = adjustBrightness(dominantColor, 1.5); // Vibrant
  
  return [background, surface, accent];
}
