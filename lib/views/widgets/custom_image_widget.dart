import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CustomImageWidget extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;

  const CustomImageWidget({
    Key? key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return const SizedBox();
    if (imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
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
