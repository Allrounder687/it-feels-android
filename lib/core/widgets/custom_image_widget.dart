import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/settings/settings_provider.dart';
import 'package:it_feels_music/core/utils/image_utils.dart';

class CustomImageWidget extends ConsumerWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int size;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;

  const CustomImageWidget({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.size = 1000, // Default to high resolution 1000px for sharp desktop/mobile screens
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (imageUrl.isEmpty) return const SizedBox();
    
    int targetSize = size;
    String finalUrl = imageUrl;
    FilterQuality imageFilterQuality = FilterQuality.high;
    
    try {
      final settings = ref.read(settingsProvider);
      if (settings.graphicsQuality == GraphicsQuality.low || settings.isDataSaverEnabled) {
        // Drop size by half for low quality to save memory, but don't hardcode to 150
        targetSize = (size * 0.25).toInt().clamp(150, 500);
        imageFilterQuality = FilterQuality.low;
      } else if (settings.graphicsQuality == GraphicsQuality.medium) {
        // For medium, scale down slightly but allow decent resolution
        targetSize = (size * 0.5).toInt().clamp(250, 500);
        imageFilterQuality = FilterQuality.low;
      }
      finalUrl = ImageUtils.getSizedCoverArt(finalUrl, size: targetSize);
    } catch (_) {}

    if (finalUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: finalUrl,
        fit: fit,
        width: width,
        height: height,
        filterQuality: imageFilterQuality,
        errorWidget: errorWidget ?? (context, url, error) {
          return Image.asset(
            'assets/images/placeholder.jpg',
            fit: fit,
            width: width,
            height: height,
          );
        },
      );
    } else {
      return Image.file(
        File(imageUrl),
        fit: fit,
        width: width,
        height: height,
        cacheWidth: targetSize,
        filterQuality: imageFilterQuality,
        errorBuilder: (context, error, stackTrace) => errorWidget != null ? errorWidget!(context, imageUrl, error) : const Icon(Icons.music_note, color: Colors.grey),
      );
    }
  }
}
