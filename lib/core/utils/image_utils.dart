/// Utility class for image URL manipulation.
class ImageUtils {
  static final RegExp _sizeRegExp = RegExp(r'\d+x\d+');

  /// Transforms a Music API image URL to the requested size.
  /// Supported sizes: 50, 150, 500
  static String getSizedCoverArt(String url, {int size = 500}) {
    if (url.isEmpty) return '';

    // Handle YouTube Thumbnails (i.ytimg.com)
    if (url.contains('i.ytimg.com')) {
      if (size <= 200) {
        // Return 320x180 for grids/lists
        return url.replaceAll('maxresdefault.jpg', 'mqdefault.jpg').replaceAll('hqdefault.jpg', 'mqdefault.jpg');
      } else if (size <= 500) {
        // Return 480x360
        return url.replaceAll('maxresdefault.jpg', 'hqdefault.jpg').replaceAll('mqdefault.jpg', 'hqdefault.jpg');
      } else {
        // Return max resolution
        return url;
      }
    }

    // Default Music API URLs often have resolution patterns like '150x150' or '50x50'.
    // We attempt to replace these with the requested size.
    // NOTE: JioSaavn CDN (saavncdn.com) maxes out at 500x500. 1000x1000 returns 404.
    int safeSize = size;
    if (url.contains('saavncdn.com')) {
      if (safeSize <= 50) {
        safeSize = 50;
      } else if (safeSize <= 150) {
        safeSize = 150;
      } else {
        safeSize = 500;
      }
    }
    String transformedUrl = url.replaceAll(_sizeRegExp, '${safeSize}x$safeSize');

    return transformedUrl;
  }
}
