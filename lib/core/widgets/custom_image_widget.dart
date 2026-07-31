import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/settings/settings_provider.dart';

class CustomImageWidget extends ConsumerWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;

  const CustomImageWidget({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (imageUrl.isEmpty) return const SizedBox();
    
    String finalUrl = imageUrl;
    try {
      final settings = ref.read(settingsProvider);
      if (settings.isDataSaverEnabled) {
        finalUrl = finalUrl.replaceAll('500x500', '150x150');
      }
    } catch (_) {}

    if (finalUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: finalUrl,
        fit: fit,
        width: width,
        height: height,
        errorWidget: errorWidget ?? (context, url, error) => const Icon(Icons.music_note, color: Colors.grey),
      );
    } else {
      return Image.file(
        File(imageUrl),
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => errorWidget != null ? errorWidget!(context, imageUrl, error) : const Icon(Icons.music_note, color: Colors.grey),
      );
    }
  }
}
