import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/diagnostics/models/diagnostic_subsystem.dart';
import 'package:it_feels_music/core/diagnostics/models/log_entry.dart';
import 'package:it_feels_music/core/diagnostics/models/log_level.dart';
import 'package:it_feels_music/core/diagnostics/observability_service.dart';
import 'package:it_feels_music/core/diagnostics/export/diagnostic_export_service.dart';
import 'package:it_feels_music/core/diagnostics/trackers/performance_telemetry_tracker.dart';
import 'package:it_feels_music/core/diagnostics/trackers/network_diagnostics_tracker.dart';
import 'package:it_feels_music/core/diagnostics/storage/rotating_log_file_sink.dart';
import '../theme/new_experience_tokens.dart';
import '../widgets/new_glass_container.dart';

/// Production-grade Diagnostics Dashboard & Observatory for IT Feels Music.
class DiagnosticsDashboardScreen extends StatefulWidget {
  const DiagnosticsDashboardScreen({super.key});

  @override
  State<DiagnosticsDashboardScreen> createState() => _DiagnosticsDashboardScreenState();
}

class _DiagnosticsDashboardScreenState extends State<DiagnosticsDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ObservabilityService _obs = ObservabilityService.instance;

  String _searchQuery = '';
  DiagnosticSubsystem? _selectedSubsystem;
  LogLevel? _selectedMinLevel = LogLevel.info;
  int _diskStorageBytes = 0;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _refreshDiskFootprint();
  }

  Future<void> _refreshDiskFootprint() async {
    final bytes = await RotatingLogFileSink.instance.computeTotalStorageBytes();
    if (mounted) {
      setState(() => _diskStorageBytes = bytes);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NewExperienceTokens.obsidianBackground,
      appBar: AppBar(
        backgroundColor: NewExperienceTokens.midnightSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: NewExperienceTokens.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OBSIDIAN OBSERVATORY',
              style: NewExperienceTokens.eyebrowLabel(color: NewExperienceTokens.accentCyan),
            ),
            Text(
              'Diagnostics & Telemetry',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: NewExperienceTokens.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Export Diagnostics',
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: NewExperienceTokens.accentCyan),
                  )
                : const Icon(Icons.ios_share_rounded, color: NewExperienceTokens.accentCyan),
            onPressed: _isExporting ? null : _handleExport,
          ),
          IconButton(
            tooltip: 'Clear In-Memory Logs',
            icon: const Icon(Icons.delete_sweep_rounded, color: NewExperienceTokens.textSecondary),
            onPressed: () {
              _obs.clearLogs();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('In-memory diagnostic logs cleared')),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: NewExperienceTokens.accentCyan,
          labelColor: NewExperienceTokens.accentCyan,
          unselectedLabelColor: NewExperienceTokens.textMuted,
          labelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'System Overview'),
            Tab(text: 'Playback'),
            Tab(text: 'Network & API'),
            Tab(text: 'Performance & DB'),
            Tab(text: 'Error Explorer'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSystemOverviewTab(),
          _buildPlaybackTab(),
          _buildNetworkTab(),
          _buildPerformanceTab(),
          _buildErrorExplorerTab(),
        ],
      ),
    );
  }

  // ── Tab 1: System Overview ──

  Widget _buildSystemOverviewTab() {
    final summary = _obs.getSubsystemSummary();
    final subsystemCounts = summary['subsystemCounts'] as Map<String, dynamic>? ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'System Version',
                value: 'v${_obs.appVersion}',
                subtitle: 'Build ${_obs.buildNumber}',
                icon: Icons.info_outline_rounded,
                accentColor: NewExperienceTokens.accentViolet,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Host Platform',
                value: _obs.platformName.toUpperCase(),
                subtitle: 'Session: ${summary['sessionId'] ?? 'unknown'}',
                icon: Icons.computer_rounded,
                accentColor: NewExperienceTokens.accentCyan,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Log Disk Storage',
                value: '${(_diskStorageBytes / 1024).toStringAsFixed(1)} KB',
                subtitle: 'Max Bounded: 10 MB',
                icon: Icons.storage_rounded,
                accentColor: NewExperienceTokens.accentEmerald,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'In-Memory Buffer',
                value: '${summary['totalInMemory'] ?? 0} events',
                subtitle: 'Max Capacity: 200',
                icon: Icons.memory_rounded,
                accentColor: NewExperienceTokens.accentRose,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        Text('TELEMETRY VOLUME BY SUBSYSTEM', style: NewExperienceTokens.eyebrowLabel(color: NewExperienceTokens.textMuted)),
        const SizedBox(height: 10),

        NewGlassContainer(
          borderRadius: NewExperienceTokens.radiusMedium,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: DiagnosticSubsystem.values.map((s) {
              final count = subsystemCounts[s.name] ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(_getSubsystemIcon(s), size: 16, color: NewExperienceTokens.textSecondary),
                    const SizedBox(width: 10),
                    Text(s.name.toUpperCase(), style: GoogleFonts.outfit(color: NewExperienceTokens.textPrimary, fontSize: 13)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('$count', style: const TextStyle(color: NewExperienceTokens.accentCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Tab 2: Playback Diagnostics ──

  Widget _buildPlaybackTab() {
    final playbackLogs = _obs.getRecentLogs(subsystem: DiagnosticSubsystem.playback, limit: 30);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        NewGlassContainer(
          borderRadius: NewExperienceTokens.radiusMedium,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NewExperienceTokens.accentViolet.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.music_note_rounded, color: NewExperienceTokens.accentViolet, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Audio Engine Lifecycle', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: NewExperienceTokens.textPrimary)),
                    const SizedBox(height: 2),
                    const Text('Instrumented: Source resolution, buffering, latency, track transitions', style: TextStyle(fontSize: 12, color: NewExperienceTokens.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('RECENT PLAYBACK EVENTS', style: NewExperienceTokens.eyebrowLabel(color: NewExperienceTokens.textMuted)),
        const SizedBox(height: 8),

        if (playbackLogs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('No playback events recorded in current session.', style: TextStyle(color: NewExperienceTokens.textMuted))),
          )
        else
          ...playbackLogs.map((log) => _buildLogCard(log)),
      ],
    );
  }

  // ── Tab 3: Network & API Diagnostics ──

  Widget _buildNetworkTab() {
    final networkCounts = NetworkDiagnosticsTracker.instance.endpointRequestCounts;
    final networkLogs = _obs.getRecentLogs(subsystem: DiagnosticSubsystem.network, limit: 30);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('TRACKED ENDPOINTS & CALL FREQUENCY', style: NewExperienceTokens.eyebrowLabel(color: NewExperienceTokens.textMuted)),
        const SizedBox(height: 8),

        if (networkCounts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('No remote network queries executed in session.', style: TextStyle(color: NewExperienceTokens.textMuted))),
          )
        else
          NewGlassContainer(
            borderRadius: NewExperienceTokens.radiusMedium,
            padding: const EdgeInsets.all(14),
            child: Column(
              children: networkCounts.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.http_rounded, color: NewExperienceTokens.accentCyan, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(entry.key, style: const TextStyle(color: NewExperienceTokens.textPrimary, fontSize: 12, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                        child: Text('${entry.value} calls', style: const TextStyle(color: NewExperienceTokens.accentEmerald, fontSize: 10)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 20),
        Text('RECENT NETWORK ACTIVITY', style: NewExperienceTokens.eyebrowLabel(color: NewExperienceTokens.textMuted)),
        const SizedBox(height: 8),

        ...networkLogs.map((log) => _buildLogCard(log)),
      ],
    );
  }

  // ── Tab 4: Performance & Database Diagnostics ──

  Widget _buildPerformanceTab() {
    final metrics = PerformanceTelemetryTracker.instance.getAllMetricSummaries();
    final dbLogs = _obs.getRecentLogs(subsystem: DiagnosticSubsystem.database, limit: 20);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('LATENCY PERCENTILE BENCHMARKS (p50 / p95 / p99)', style: NewExperienceTokens.eyebrowLabel(color: NewExperienceTokens.textMuted)),
        const SizedBox(height: 8),

        if (metrics.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('No performance benchmarks recorded yet.', style: TextStyle(color: NewExperienceTokens.textMuted))),
          )
        else
          ...metrics.entries.map((entry) {
            final m = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NewGlassContainer(
                borderRadius: NewExperienceTokens.radiusMedium,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: NewExperienceTokens.textPrimary, fontSize: 14)),
                        Text('Sample size: ${m['count']}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                    const Spacer(),
                    _buildPercentilePill('p50', '${m['p50']}ms', NewExperienceTokens.accentEmerald),
                    const SizedBox(width: 6),
                    _buildPercentilePill('p95', '${m['p95']}ms', NewExperienceTokens.accentAmber),
                    const SizedBox(width: 6),
                    _buildPercentilePill('p99', '${m['p99']}ms', NewExperienceTokens.accentRose),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 20),
        Text('RECENT DATABASE & STORAGE EVENTS', style: NewExperienceTokens.eyebrowLabel(color: NewExperienceTokens.textMuted)),
        const SizedBox(height: 8),

        ...dbLogs.map((log) => _buildLogCard(log)),
      ],
    );
  }

  // ── Tab 5: Error Explorer ──

  Widget _buildErrorExplorerTab() {
    final errorLogs = _obs.getRecentLogs(
      minLevel: _selectedMinLevel,
      subsystem: _selectedSubsystem,
      searchQuery: _searchQuery,
      limit: 100,
    );

    return Column(
      children: [
        // Filter toolbar
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search errors, codes, components...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<LogLevel>(
                value: _selectedMinLevel,
                dropdownColor: NewExperienceTokens.midnightSurface,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                underline: const SizedBox(),
                items: [
                  const DropdownMenuItem(value: LogLevel.trace, child: Text('All Levels')),
                  const DropdownMenuItem(value: LogLevel.info, child: Text('Info+')),
                  const DropdownMenuItem(value: LogLevel.warn, child: Text('Warn+')),
                  const DropdownMenuItem(value: LogLevel.error, child: Text('Errors Only')),
                ],
                onChanged: (val) => setState(() => _selectedMinLevel = val),
              ),
            ],
          ),
        ),

        Expanded(
          child: errorLogs.isEmpty
              ? const Center(child: Text('Zero matching events found.', style: TextStyle(color: NewExperienceTokens.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  itemCount: errorLogs.length,
                  itemBuilder: (context, index) => _buildLogCard(errorLogs[index]),
                ),
        ),
      ],
    );
  }

  // ── UI Helpers ──

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return NewGlassContainer(
      borderRadius: NewExperienceTokens.radiusMedium,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 18),
              const Spacer(),
              Text(title, style: const TextStyle(color: NewExperienceTokens.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: NewExperienceTokens.textPrimary)),
          Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildPercentilePill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
      child: Text('$label: $value', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildLogCard(LogEntry entry) {
    final isError = entry.level.isAtLeast(LogLevel.error);
    final isWarn = entry.level == LogLevel.warn;
    final color = isError ? const Color(0xFFEF4444) : (isWarn ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: NewGlassContainer(
        borderRadius: 10.0,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                  child: Text(entry.level.label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text('${entry.module.name.toUpperCase()}:${entry.component}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (entry.operationDurationMs != null)
                  Text('${entry.operationDurationMs}ms  ', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                Text(
                  '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(entry.eventName, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            if (entry.errorMessage != null) ...[
              const SizedBox(height: 2),
              Text(entry.errorMessage!, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11)),
            ],
            if (entry.stackTrace != null) ...[
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(4)),
                child: Text(entry.stackTrace!, style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getSubsystemIcon(DiagnosticSubsystem s) {
    return switch (s) {
      DiagnosticSubsystem.playback => Icons.play_circle_outline_rounded,
      DiagnosticSubsystem.network => Icons.wifi_rounded,
      DiagnosticSubsystem.database => Icons.storage_rounded,
      DiagnosticSubsystem.content => Icons.art_track_rounded,
      DiagnosticSubsystem.performance => Icons.speed_rounded,
      DiagnosticSubsystem.framework => Icons.layers_rounded,
      DiagnosticSubsystem.platform => Icons.devices_rounded,
      DiagnosticSubsystem.lifecycle => Icons.sync_rounded,
      DiagnosticSubsystem.security => Icons.lock_outline_rounded,
    };
  }

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);
    try {
      final path = await DiagnosticExportService.instance.writeExportPackageToDisk();
      if (mounted) {
        if (path != null) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: NewExperienceTokens.midnightSurface,
              title: Text('Diagnostics Exported', style: GoogleFonts.outfit(color: Colors.white)),
              content: Text(
                'Archive exported with full privacy scrubbing:\n\n$path',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: path));
                    Navigator.pop(context);
                  },
                  child: const Text('Copy Path', style: TextStyle(color: NewExperienceTokens.accentCyan)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Diagnostic export generated in memory (web mode).')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}
