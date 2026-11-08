import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/intelligence/feed/home_feed_models.dart';
import 'artwork_repair_service.dart';
import 'catalogue_deduplication_engine.dart';

/// Health status classification for a content tab or collection.
enum ContentHealthStatus {
  healthy,
  needsEnrichment,
  incomplete,
  degraded,
  failed,
}

extension ContentHealthStatusExtension on ContentHealthStatus {
  String get label {
    switch (this) {
      case ContentHealthStatus.healthy:
        return 'Healthy';
      case ContentHealthStatus.needsEnrichment:
        return 'Needs Enrichment';
      case ContentHealthStatus.incomplete:
        return 'Incomplete';
      case ContentHealthStatus.degraded:
        return 'Degraded';
      case ContentHealthStatus.failed:
        return 'Failed';
    }
  }
}

/// Audit report for a single content section.
class SectionHealthReport {
  final String sectionId;
  final String sectionName;
  final ContentHealthStatus status;
  final int totalItems;
  final int validItems;
  final int playableItems;
  final int missingArtworkCount;
  final int duplicateCount;
  final bool isStale;
  final DateTime lastRefreshedAt;
  final double healthScore; // 0.0 to 1.0
  final List<String> identifiedDeficits;

  const SectionHealthReport({
    required this.sectionId,
    required this.sectionName,
    required this.status,
    required this.totalItems,
    required this.validItems,
    required this.playableItems,
    required this.missingArtworkCount,
    required this.duplicateCount,
    required this.isStale,
    required this.lastRefreshedAt,
    required this.healthScore,
    this.identifiedDeficits = const [],
  });

  Map<String, dynamic> toJson() => {
    'sectionId': sectionId,
    'sectionName': sectionName,
    'status': status.label,
    'totalItems': totalItems,
    'validItems': validItems,
    'playableItems': playableItems,
    'missingArtworkCount': missingArtworkCount,
    'duplicateCount': duplicateCount,
    'isStale': isStale,
    'lastRefreshedAt': lastRefreshedAt.toIso8601String(),
    'healthScore': healthScore,
    'deficits': identifiedDeficits,
  };
}

/// Aggregated application-wide content health report.
class CatalogueHealthSummary {
  final ContentHealthStatus overallStatus;
  final double overallHealthScore;
  final int totalAuditedSections;
  final int healthySectionsCount;
  final int totalAuditedItems;
  final int totalMissingArtwork;
  final int totalDuplicatesDetected;
  final DateTime auditedAt;
  final List<SectionHealthReport> sectionReports;

  const CatalogueHealthSummary({
    required this.overallStatus,
    required this.overallHealthScore,
    required this.totalAuditedSections,
    required this.healthySectionsCount,
    required this.totalAuditedItems,
    required this.totalMissingArtwork,
    required this.totalDuplicatesDetected,
    required this.auditedAt,
    required this.sectionReports,
  });
}

/// Central Content Health Monitor.
/// Tracks quality, completeness, playable availability, artwork validity,
/// and freshness across every music section in the application.
class ContentHealthService {
  static final ContentHealthService _instance = ContentHealthService._internal();
  factory ContentHealthService() => _instance;
  static ContentHealthService get instance => _instance;
  ContentHealthService._internal();

  final Map<String, SectionHealthReport> _latestReports = {};

  /// Audits a track collection (e.g. Chart Feed, Daily Mix, Liked Songs).
  SectionHealthReport auditTrackCollection({
    required String sectionId,
    required String sectionName,
    required List<Song> songs,
    int minimumExpectedItems = 10,
    DateTime? lastRefresh,
  }) {
    final deficits = <String>[];
    final artworkRepair = ArtworkRepairService();
    final dedup = CatalogueDeduplicationEngine();

    if (songs.isEmpty) {
      final report = SectionHealthReport(
        sectionId: sectionId,
        sectionName: sectionName,
        status: ContentHealthStatus.incomplete,
        totalItems: 0,
        validItems: 0,
        playableItems: 0,
        missingArtworkCount: 0,
        duplicateCount: 0,
        isStale: true,
        lastRefreshedAt: lastRefresh ?? DateTime.now().subtract(const Duration(days: 7)),
        healthScore: 0.0,
        identifiedDeficits: ['Section contains zero tracks'],
      );
      _latestReports[sectionId] = report;
      return report;
    }

    int validItems = 0;
    int playableItems = 0;
    int missingArtwork = 0;

    for (final song in songs) {
      // Validity check: non-empty title and artist
      final hasTitle = song.title.trim().isNotEmpty && song.title != 'Unknown';
      final hasArtist = song.artist.trim().isNotEmpty && song.artist != 'Unknown';
      if (hasTitle && hasArtist) {
        validItems++;
      } else {
        deficits.add('Invalid metadata on song ID: ${song.id}');
      }

      // Playable check: has stream URL or local path or Saavn ID
      if (song.streamUrl != null || song.localFilePath != null || song.saavnId.isNotEmpty || song.encryptedMediaUrl != null) {
        playableItems++;
      } else {
        deficits.add('Song "${song.title}" missing audio stream source');
      }

      // Artwork check
      if (!artworkRepair.isValidArtworkUrl(song.image)) {
        missingArtwork++;
      }
    }

    // Check duplicate count
    final dedupReport = dedup.deduplicateTracks(songs);
    final duplicateCount = dedupReport.duplicatesRemoved;
    if (duplicateCount > 0) {
      deficits.add('Detected $duplicateCount duplicate tracks in section');
    }

    // Staleness check (> 24 hours)
    final refreshTime = lastRefresh ?? DateTime.now();
    final isStale = DateTime.now().difference(refreshTime).inHours > 24;
    if (isStale) {
      deficits.add('Content is older than 24 hours');
    }

    // Score calculation
    final validityRatio = validItems / songs.length;
    final playabilityRatio = playableItems / songs.length;
    final artworkRatio = (songs.length - missingArtwork) / songs.length;
    final duplicatePenalty = (duplicateCount / songs.length).clamp(0.0, 0.4);

    double healthScore = ((validityRatio * 0.3) +
            (playabilityRatio * 0.4) +
            (artworkRatio * 0.3)) -
        duplicatePenalty;
    healthScore = healthScore.clamp(0.0, 1.0);

    ContentHealthStatus status;
    if (healthScore >= 0.88 && songs.length >= minimumExpectedItems) {
      status = ContentHealthStatus.healthy;
    } else if (healthScore >= 0.70) {
      status = ContentHealthStatus.needsEnrichment;
    } else if (songs.length < minimumExpectedItems) {
      status = ContentHealthStatus.incomplete;
    } else if (healthScore >= 0.40) {
      status = ContentHealthStatus.degraded;
    } else {
      status = ContentHealthStatus.failed;
    }

    final report = SectionHealthReport(
      sectionId: sectionId,
      sectionName: sectionName,
      status: status,
      totalItems: songs.length,
      validItems: validItems,
      playableItems: playableItems,
      missingArtworkCount: missingArtwork,
      duplicateCount: duplicateCount,
      isStale: isStale,
      lastRefreshedAt: refreshTime,
      healthScore: healthScore,
      identifiedDeficits: deficits,
    );

    _latestReports[sectionId] = report;
    return report;
  }

  /// Audits a full HomeFeed snapshot.
  List<SectionHealthReport> auditHomeFeed(HomeFeed feed) {
    final reports = <SectionHealthReport>[];
    for (final section in feed.sections) {
      final songs = section.items
          .where((it) => it.song != null)
          .map((it) => it.song!)
          .toList();

      final report = auditTrackCollection(
        sectionId: section.id,
        sectionName: section.title,
        songs: songs,
        minimumExpectedItems: 4,
        lastRefresh: feed.generatedAt,
      );
      reports.add(report);
    }
    return reports;
  }

  /// Computes overall catalogue health across all audited sections.
  CatalogueHealthSummary getOverallHealth() {
    if (_latestReports.isEmpty) {
      return CatalogueHealthSummary(
        overallStatus: ContentHealthStatus.incomplete,
        overallHealthScore: 0.0,
        totalAuditedSections: 0,
        healthySectionsCount: 0,
        totalAuditedItems: 0,
        totalMissingArtwork: 0,
        totalDuplicatesDetected: 0,
        auditedAt: DateTime.now(),
        sectionReports: const [],
      );
    }

    int healthyCount = 0;
    int totalItems = 0;
    int totalMissingArt = 0;
    int totalDuplicates = 0;
    double scoreSum = 0.0;

    final reports = _latestReports.values.toList();
    for (final r in reports) {
      if (r.status == ContentHealthStatus.healthy) healthyCount++;
      totalItems += r.totalItems;
      totalMissingArt += r.missingArtworkCount;
      totalDuplicates += r.duplicateCount;
      scoreSum += r.healthScore;
    }

    final avgScore = scoreSum / reports.length;
    ContentHealthStatus overall;
    if (avgScore >= 0.85) {
      overall = ContentHealthStatus.healthy;
    } else if (avgScore >= 0.65) {
      overall = ContentHealthStatus.needsEnrichment;
    } else {
      overall = ContentHealthStatus.degraded;
    }

    return CatalogueHealthSummary(
      overallStatus: overall,
      overallHealthScore: avgScore,
      totalAuditedSections: reports.length,
      healthySectionsCount: healthyCount,
      totalAuditedItems: totalItems,
      totalMissingArtwork: totalMissingArt,
      totalDuplicatesDetected: totalDuplicates,
      auditedAt: DateTime.now(),
      sectionReports: reports,
    );
  }
}
