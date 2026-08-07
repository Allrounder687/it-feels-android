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
    this.size = 500, // Default to standard 500px resolution
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (imageUrl.isEmpty) return const SizedBox();
    
    int targetSize = size;
    String finalUrl = imageUrl;
    try {
      final settings = ref.read(settingsProvider);
      if (settings.isDataSaverEnabled) {
        targetSize = 150;
      }
      finalUrl = ImageUtils.getSizedCoverArt(finalUrl, size: targetSize);
    } catch (_) {}

    if (finalUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: finalUrl,
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: targetSize,
        errorWidget: errorWidget ?? (context, url, error) => const Icon(Icons.music_note, color: Colors.grey),
      );
    } else {
      return Image.file(
        File(imageUrl),
        fit: fit,
        width: width,
        height: height,
        cacheWidth: targetSize,
        errorBuilder: (context, error, stackTrace) => errorWidget != null ? errorWidget!(context, imageUrl, error) : const Icon(Icons.music_note, color: Colors.grey),
      );
    }
  }
}
