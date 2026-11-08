import 'package:flutter/material.dart';
import 'package:it_feels_music/core/intelligence/catalogue/content_health_service.dart';
import '../theme/new_experience_tokens.dart';
import '../widgets/new_glass_container.dart';

class ContentHealthSheet extends StatefulWidget {
  const ContentHealthSheet({super.key});

  @override
  State<ContentHealthSheet> createState() => _ContentHealthSheetState();
}

class _ContentHealthSheetState extends State<ContentHealthSheet> {
  late CatalogueHealthSummary _summary;

  @override
  void initState() {
    super.initState();
    _refreshHealth();
  }

  void _refreshHealth() {
    setState(() {
      _summary = ContentHealthService.instance.getOverallHealth();
    });
  }

  Color _getStatusColor(ContentHealthStatus status) {
    switch (status) {
      case ContentHealthStatus.healthy:
        return const Color(0xFF10B981);
      case ContentHealthStatus.needsEnrichment:
        return const Color(0xFFF59E0B);
      case ContentHealthStatus.incomplete:
        return const Color(0xFF6B7280);
      case ContentHealthStatus.degraded:
        return const Color(0xFFEF4444);
      case ContentHealthStatus.failed:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: NewExperienceTokens.midnightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: NewExperienceTokens.specularBorder),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title & Refresh
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIVING MUSIC CATALOGUE',
                      style: NewExperienceTokens.eyebrowLabel(
                        color: NewExperienceTokens.accentCyan,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Content Health Monitor',
                      style: NewExperienceTokens.sectionTitle(fontSize: 20),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                  onPressed: _refreshHealth,
                  tooltip: 'Re-audit Sections',
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12),

          // Top Metrics Overview Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: NewGlassContainer(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _metricTile(
                    'STATUS',
                    _summary.overallStatus.label,
                    _getStatusColor(_summary.overallStatus),
                  ),
                  _metricTile(
                    'HEALTH SCORE',
                    '${(_summary.overallHealthScore * 100).toInt()}%',
                    NewExperienceTokens.accentCyan,
                  ),
                  _metricTile(
                    'SECTIONS',
                    '${_summary.healthySectionsCount}/${_summary.totalAuditedSections}',
                    Colors.white,
                  ),
                  _metricTile(
                    'DUPLICATES 0',
                    '${_summary.totalDuplicatesDetected} cleaned',
                    const Color(0xFF10B981),
                  ),
                ],
              ),
            ),
          ),

          // Section Breakdown
          Expanded(
            child: _summary.sectionReports.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, size: 48, color: Color(0xFF10B981)),
                          const SizedBox(height: 12),
                          Text(
                            'Catalogue is Audited & Verified',
                            style: NewExperienceTokens.sectionTitle(fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'All active sections, Daily Mixes, and chart feeds pass strict music-first quality criteria.',
                            textAlign: TextAlign.center,
                            style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: _summary.sectionReports.length,
                    itemBuilder: (context, index) {
                      final section = _summary.sectionReports[index];
                      final statusColor = _getStatusColor(section.status);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: NewGlassContainer(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      section.sectionName,
                                      style: NewExperienceTokens.sectionTitle(fontSize: 15),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      section.status.label.toUpperCase(),
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    '${section.validItems} Valid Tracks',
                                    style: NewExperienceTokens.captionMuted(),
                                  ),
                                  const Text(' • ', style: TextStyle(color: Colors.white24)),
                                  Text(
                                    '${section.playableItems} Playable',
                                    style: NewExperienceTokens.captionMuted(color: NewExperienceTokens.accentCyan),
                                  ),
                                  if (section.missingArtworkCount > 0) ...[
                                    const Text(' • ', style: TextStyle(color: Colors.white24)),
                                    Text(
                                      '${section.missingArtworkCount} Missing Art',
                                      style: NewExperienceTokens.captionMuted(color: Colors.amberAccent),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _metricTile(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: NewExperienceTokens.captionMuted().copyWith(fontSize: 10),
        ),
      ],
    );
  }
}
