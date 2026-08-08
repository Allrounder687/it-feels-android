import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:it_feels_music/data/models/cache_models.dart';
import 'package:it_feels_music/services/database_service.dart';
import 'package:palette_generator/palette_generator.dart';

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
        // Send to isolate or run on main thread for Desktop
        PaletteResult? isolateResult = await _isolateEntryPoint(imageUrl);

        if (isolateResult == null || currentToken != _generationToken) {
          _memoryCache[imageUrl] = PaletteResult(0, 0, 0, isFailed: true);
          if (!completerToComplete.isCompleted) completerToComplete.complete(null);
          return;
        }
        
        final res = PaletteResult(isolateResult.background, isolateResult.surface, isolateResult.accent);
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

  static Future<PaletteResult?> _isolateEntryPoint(String imageUrl) async {
    try {
      final ByteData data = await NetworkAssetBundle(Uri.parse(imageUrl)).load(imageUrl);
      final Uint8List bytes = data.buffer.asUint8List();
      
      // Decode and downsample inside the isolate
      final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetWidth: 100, targetHeight: 100);
      final ui.FrameInfo frame = await codec.getNextFrame();
      
      // Use official PaletteGenerator inside isolate
      final palette = await PaletteGenerator.fromImage(frame.image);
      frame.image.dispose();
      
      int background = palette.dominantColor?.color.toARGB32() ?? 0xff0f0f0f;
      int surface = palette.lightMutedColor?.color.toARGB32() ?? palette.mutedColor?.color.toARGB32() ?? background;
      int accent = palette.vibrantColor?.color.toARGB32() ?? palette.dominantColor?.color.toARGB32() ?? background;
      
      return PaletteResult(background, surface, accent);
    } catch (e) {
      debugPrint('[PaletteExtractor] Isolate error: $e');
      return null;
    }
  }
}
