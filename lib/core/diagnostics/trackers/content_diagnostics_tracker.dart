import '../models/diagnostic_subsystem.dart';
import '../observability_service.dart';

/// Diagnostics tracker for the Living Music Catalogue and artwork repair engine.
class ContentDiagnosticsTracker {
  static final ContentDiagnosticsTracker instance = ContentDiagnosticsTracker._internal();
  factory ContentDiagnosticsTracker() => instance;

  final ObservabilityService _obs = ObservabilityService.instance;

  ContentDiagnosticsTracker._internal();

  /// Records an artwork resolution or repair event.
  void trackArtworkRepair({
    required String trackId,
    required String originalUrl,
    required String resolvedUrl,
    required String repairMethod, // "cdn_escalation", "quad_composite", "palette_glass"
    required bool isSuccess,
    String? failureReason,
    String? correlationId,
  }) {
    final meta = <String, dynamic>{
      'trackId': trackId,
      'repairMethod': repairMethod,
      'isSuccess': isSuccess,
      'originalHost': _extractHost(originalUrl),
      'resolvedHost': _extractHost(resolvedUrl),
      'failureReason': ?failureReason,
    };

    if (isSuccess) {
      _obs.info(
        subsystem: DiagnosticSubsystem.content,
        component: 'ArtworkRepairService',
        eventName: 'artwork_repair_completed',
        correlationId: correlationId,
        metadata: meta,
      );
    } else {
      _obs.warn(
        subsystem: DiagnosticSubsystem.content,
        component: 'ArtworkRepairService',
        eventName: 'artwork_repair_failed',
        correlationId: correlationId,
        errorCode: 'WARN-ARTWORK-REPAIR',
        errorMessage: 'Failed to repair artwork for $trackId: ${failureReason ?? "unknown"}',
        metadata: meta,
      );
    }
  }

  /// Records a duplicate track detection and consolidation event.
  void trackDuplicateElimination({
    required String canonicalSongId,
    required String duplicateSongId,
    required String title,
    required String artist,
    required double similarityScore,
    String? correlationId,
  }) {
    _obs.info(
      subsystem: DiagnosticSubsystem.content,
      component: 'CatalogueDeduplicationEngine',
      eventName: 'duplicate_track_eliminated',
      correlationId: correlationId,
      metadata: {
        'canonicalSongId': canonicalSongId,
        'duplicateSongId': duplicateSongId,
        'title': title,
        'artist': artist,
        'similarityScore': similarityScore,
      },
    );
  }

  /// Records detection of an unplayable track or missing audio source.
  void trackUnplayableItem({
    required String itemId,
    required String itemType, // "song", "album", "playlist"
    required String reason,
    String? correlationId,
  }) {
    _obs.warn(
      subsystem: DiagnosticSubsystem.content,
      component: 'ContentHealthService',
      eventName: 'unplayable_item_detected',
      correlationId: correlationId,
      errorCode: 'WARN-CONTENT-UNPLAYABLE',
      errorMessage: 'Unplayable $itemType ($itemId): $reason',
      metadata: {'itemId': itemId, 'itemType': itemType, 'reason': reason},
    );
  }

  static String _extractHost(String url) {
    try {
      if (url.isEmpty) return 'empty';
      final uri = Uri.parse(url);
      return uri.host.isNotEmpty ? uri.host : 'local_or_relative';
    } catch (_) {
      return 'invalid_uri';
    }
  }
}
