/// Utility class for image URL manipulation.
class ImageUtils {
  /// Transforms a JioSaavn image URL to the requested size.
  /// Supported sizes: 50, 150, 500
  static String getSizedCoverArt(String url, {int size = 500}) {
    if (url.isEmpty) return '';

    // Default JioSaavn URLs often have resolution patterns like '150x150' or '50x50'.
    // We attempt to replace these with the requested size.
    String transformedUrl = url.replaceAll(RegExp(r'\d+x\d+'), '${size}x${size}');

    return transformedUrl;
  }
}
