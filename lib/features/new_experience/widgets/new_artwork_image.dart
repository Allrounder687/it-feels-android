import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/new_experience_tokens.dart';

/// Resilient artwork widget for NewExperience UI that automatically handles:
/// 1. Memory-bounded image decoding (memCacheWidth / memCacheHeight)
/// 2. Disk cache bounds (maxWidthDiskCache / maxHeightDiskCache)
/// 3. In-memory local file existence caching to eliminate UI thread disk I/O
/// 4. Local filesystem cover art (downloaded offline files, e.g. cover.jpg)
/// 5. Remote CDN images with CachedNetworkImage
/// 6. Graceful stylized placeholder gradients and error fallbacks
class NewArtworkImage extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final double iconSize;
  final String? fallbackTitle;

  // In-memory file existence cache to avoid repeated synchronous disk I/O on UI thread
  static final Map<String, bool> _localFileCache = <String, bool>{};
  static const int _maxCacheSize = 500;

  const NewArtworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.iconSize = 20,
    this.fallbackTitle,
  });

  bool _isLocalFile(String url) {
    if (url.startsWith('file://')) return true;
    if (url.startsWith('http://') || url.startsWith('https://')) return false;
    // Android/Linux absolute paths or Windows drive letters
    if (url.startsWith('/') || RegExp(r'^[a-zA-Z]:[/\\]').hasMatch(url)) {
      return true;
    }
    return false;
  }

  String _cleanLocalPath(String url) {
    if (url.startsWith('file://')) {
      return url.replaceFirst('file://', '');
    }
    return url;
  }

  bool _checkFileExists(String path) {
    if (_localFileCache.containsKey(path)) {
      return _localFileCache[path]!;
    }
    try {
      final exists = File(path).existsSync();
      if (_localFileCache.length >= _maxCacheSize) {
        _localFileCache.clear();
      }
      _localFileCache[path] = exists;
      return exists;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.zero;
    final url = imageUrl?.trim() ?? '';

    if (url.isEmpty) {
      return _buildFallback(effectiveRadius);
    }

    // High-performance decode bounding: scale to 2x display points for Retina/HiDPI,
    // clamping to prevent massive decoded RGBA bitmaps in RAM (guard against infinity/NaN)
    final memWidth = (width != null && width!.isFinite) ? (width! * 2).toInt().clamp(64, 800) : null;
    final memHeight = (height != null && height!.isFinite) ? (height! * 2).toInt().clamp(64, 800) : null;

    // 1. Local File handling (Offline Downloads)
    if (_isLocalFile(url)) {
      try {
        final filePath = _cleanLocalPath(url);
        if (_checkFileExists(filePath)) {
          return ClipRRect(
            borderRadius: effectiveRadius,
            child: Image.file(
              File(filePath),
              fit: fit,
              width: width,
              height: height,
              cacheWidth: memWidth,
              cacheHeight: memHeight,
              errorBuilder: (_, _, _) => _buildFallback(effectiveRadius),
            ),
          );
        }
      } catch (_) {}
      return _buildFallback(effectiveRadius);
    }

    // 2. Network URL handling (with bounded decode & disk cache)
    return ClipRRect(
      borderRadius: effectiveRadius,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: memWidth,
        memCacheHeight: memHeight,
        maxWidthDiskCache: 1200,
        maxHeightDiskCache: 1200,
        placeholder: (_, _) => _buildPlaceholder(effectiveRadius),
        errorWidget: (_, _, _) => _buildFallback(effectiveRadius),
      ),
    );
  }

  Widget _buildPlaceholder(BorderRadius radius) {
    final isSmallThumbnail = (width != null && width! <= 64) || iconSize <= 22;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: NewExperienceTokens.midnightSurface,
        borderRadius: radius,
      ),
      child: Center(
        child: isSmallThumbnail
            ? Icon(
                Icons.music_note_rounded,
                color: NewExperienceTokens.textMuted.withValues(alpha: 0.3),
                size: iconSize * 0.9,
              )
            : SizedBox(
                width: iconSize * 0.8,
                height: iconSize * 0.8,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: NewExperienceTokens.accentViolet.withValues(alpha: 0.6),
                ),
              ),
      ),
    );
  }

  static const List<List<Color>> _fallbackPalettes = [
    [Color(0xFF2E1065), Color(0xFF0F0728)], // Deep Violet
    [Color(0xFF1E3A8A), Color(0xFF0B1944)], // Midnight Blue
    [Color(0xFF064E3B), Color(0xFF022018)], // Deep Emerald
    [Color(0xFF701A75), Color(0xFF2E0830)], // Deep Fuchsia
    [Color(0xFF831843), Color(0xFF33081A)], // Deep Rose
    [Color(0xFF7C2D12), Color(0xFF2C0F05)], // Deep Amber
    [Color(0xFF134E4A), Color(0xFF051F1D)], // Deep Teal
    [Color(0xFF312E81), Color(0xFF110E3B)], // Deep Indigo
  ];

  Widget _buildFallback(BorderRadius radius) {
    final title = fallbackTitle?.trim() ?? '';
    final hasTitle = title.isNotEmpty;
    final palette = hasTitle
        ? _fallbackPalettes[title.hashCode.abs() % _fallbackPalettes.length]
        : const [NewExperienceTokens.midnightSurface, NewExperienceTokens.cardSurface];

    final isLarge = (width == null || width! >= 80) && iconSize >= 28;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
        borderRadius: radius,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ambient subtle radial shimmer
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),

          // Central icon or monogram
          if (isLarge && hasTitle && _getInitials(title).isNotEmpty)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getInitials(title),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: (iconSize * 0.9).clamp(16.0, 36.0),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.graphic_eq_rounded,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 14,
                ),
              ],
            )
          else
            Icon(
              Icons.music_note_rounded,
              color: Colors.white.withValues(alpha: hasTitle ? 0.6 : 0.4),
              size: iconSize,
            ),
        ],
      ),
    );
  }

  String _getInitials(String text) {
    final clean = text.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim();
    if (clean.isEmpty) return '';
    final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
  }
}
