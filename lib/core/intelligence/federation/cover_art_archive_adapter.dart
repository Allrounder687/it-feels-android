import 'dart:async';
import '../orchestration/enterprise_api_orchestrator.dart';
import '../orchestration/tiered_cache_manager.dart';

class CoverArtUrls {
  final String original;
  final String? small; // 250px
  final String? medium; // 500px
  final String? large; // 1200px

  CoverArtUrls({
    required this.original,
    this.small,
    this.medium,
    this.large,
  });

  /// Best resolution for UI cards and headers
  String get displayUrl => medium ?? original;
}

/// Archive-backed high-resolution album cover art adapter via Cover Art Archive (MetaBrainz).
class CoverArtArchiveAdapter {
  final EnterpriseApiOrchestrator _orchestrator;

  CoverArtArchiveAdapter({EnterpriseApiOrchestrator? orchestrator})
      : _orchestrator = orchestrator ?? EnterpriseApiOrchestrator();

  /// Resolves cover art URLs for a verified MusicBrainz release MBID.
  Future<CoverArtUrls?> fetchCoverArt(String releaseMbid) async {
    final url = 'https://coverartarchive.org/release/$releaseMbid';

    final json = await _orchestrator.getJson(
      provider: 'coverartarchive',
      url: url,
      cacheType: CacheContentType.album,
      customTtl: const Duration(days: 30),
    );

    if (json == null || json['images'] == null) return null;
    final images = json['images'] as List;
    if (images.isEmpty) return null;

    // Look for front cover
    Map<String, dynamic>? frontImage;
    for (final img in images) {
      if (img is Map<String, dynamic> && img['front'] == true) {
        frontImage = img;
        break;
      }
    }
    frontImage ??= images.first as Map<String, dynamic>;

    final original = frontImage['image']?.toString();
    if (original == null || original.isEmpty) return null;

    final thumbnails = frontImage['thumbnails'] as Map<String, dynamic>?;

    return CoverArtUrls(
      original: original,
      small: thumbnails?['250']?.toString(),
      medium: thumbnails?['500']?.toString(),
      large: thumbnails?['1200']?.toString(),
    );
  }
}
