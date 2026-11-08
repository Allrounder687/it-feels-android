import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/intelligence/orchestration/enterprise_api_orchestrator.dart';
import 'package:it_feels_music/core/intelligence/events/listening_event_buffer.dart';
import '../theme/new_experience_tokens.dart';
import '../widgets/new_glass_container.dart';

class EnterpriseDiagnosticSheet extends StatefulWidget {
  const EnterpriseDiagnosticSheet({super.key});

  @override
  State<EnterpriseDiagnosticSheet> createState() => _EnterpriseDiagnosticSheetState();
}

class _EnterpriseDiagnosticSheetState extends State<EnterpriseDiagnosticSheet> {
  final EnterpriseApiOrchestrator _orchestrator = EnterpriseApiOrchestrator();
  final ListeningEventBuffer _buffer = ListeningEventBuffer.instance;
  late Map<String, dynamic> _report;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _report = _orchestrator.getDiagnosticReport();
    });
  }

  @override
  Widget build(BuildContext context) {
    final providers = _report['providers'] as Map<String, dynamic>? ?? {};
    final cache = _orchestrator.cache;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.40,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: NewExperienceTokens.midnightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: NewExperienceTokens.specularBorder),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ENTERPRISE OBSERVABILITY',
                        style: NewExperienceTokens.eyebrowLabel(color: NewExperienceTokens.accentCyan),
                      ),
                      Text(
                        'System Diagnostics',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: NewExperienceTokens.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: NewExperienceTokens.textSecondary),
                    onPressed: _refresh,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Cache & Offline Buffer Metrics
              Row(
                children: [
                  Expanded(
                    child: NewGlassContainer(
                      borderRadius: NewExperienceTokens.radiusMedium,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cache Hit Rate', style: TextStyle(color: NewExperienceTokens.textMuted, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            '${(cache.hitRate * 100).toStringAsFixed(1)}%',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: NewExperienceTokens.accentCyan),
                          ),
                          Text('L1: ${cache.l1Hits} | L2: ${cache.l2Hits}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NewGlassContainer(
                      borderRadius: NewExperienceTokens.radiusMedium,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Listening Events', style: TextStyle(color: NewExperienceTokens.textMuted, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            '${_buffer.count}',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: NewExperienceTokens.accentViolet),
                          ),
                          const Text('Offline Buffer Stored', style: TextStyle(color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Text(
                'FEDERATED PROVIDER HEALTH',
                style: NewExperienceTokens.eyebrowLabel(color: NewExperienceTokens.textMuted),
              ),
              const SizedBox(height: 8),

              if (providers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('No external API requests recorded in current session.', style: TextStyle(color: NewExperienceTokens.textMuted)),
                  ),
                )
              else
                ...providers.entries.map((entry) {
                  final pName = entry.key;
                  final stats = entry.value as Map<String, dynamic>;
                  final circuitState = stats['circuitState']?.toString() ?? 'CLOSED';
                  final isHealthy = circuitState == 'CLOSED' && (stats['failedRequests'] as int? ?? 0) == 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: NewGlassContainer(
                      borderRadius: NewExperienceTokens.radiusMedium,
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isHealthy ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      pName.toUpperCase(),
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: NewExperienceTokens.textPrimary),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        circuitState,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: circuitState == 'CLOSED' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Reqs: ${stats['totalRequests']} • Success: ${stats['successRate']} • Avg: ${stats['avgLatencyMs']}ms',
                                  style: const TextStyle(color: NewExperienceTokens.textSecondary, fontSize: 12),
                                ),
                                if (stats['rateLimitEvents'] != null && (stats['rateLimitEvents'] as int) > 0)
                                  Text(
                                    '429 Throttled Events: ${stats['rateLimitEvents']}',
                                    style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
