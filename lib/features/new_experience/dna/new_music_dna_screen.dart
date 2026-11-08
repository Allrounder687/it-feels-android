import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/intelligence/analytics/music_dna_service.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/new_ambient_canvas.dart';
import '../widgets/new_glass_container.dart';
import '../widgets/new_section_header.dart';
import '../theme/content_viewport_insets.dart';

class NewMusicDnaScreen extends ConsumerStatefulWidget {
  const NewMusicDnaScreen({super.key});

  @override
  ConsumerState<NewMusicDnaScreen> createState() => _NewMusicDnaScreenState();
}

class _NewMusicDnaScreenState extends ConsumerState<NewMusicDnaScreen> {
  final MusicDnaService _dnaService = MusicDnaService();
  bool _isLoading = true;
  MusicDnaOverview? _overview;

  @override
  void initState() {
    super.initState();
    _loadDna();
  }

  Future<void> _loadDna() async {
    final overview = await _dnaService.computeDnaOverview();
    if (mounted) {
      setState(() {
        _overview = overview;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return NewAmbientCanvas(
      intensity: 0.45,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Your Music DNA',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: NewExperienceTokens.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: NewExperienceTokens.textSecondary),
              tooltip: 'Refresh analytics',
              onPressed: () {
                setState(() => _isLoading = true);
                _loadDna();
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: NewExperienceTokens.accentCyan),
              )
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PERSONAL LISTENING INTELLIGENCE',
                            style: NewExperienceTokens.eyebrowLabel(
                              color: NewExperienceTokens.accentCyan,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your Musical Identity',
                            style: NewExperienceTokens.displayHero(fontSize: 28),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Generated locally from on-device listening telemetry. Private, authenticated, and never shared externally.',
                            style: NewExperienceTokens.bodyMedium(
                              color: NewExperienceTokens.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 4 High-Level Metric Tiles
                          _buildMetricGrid(_overview!),
                          const SizedBox(height: 28),

                          // Temporal Heatmap & Listening Rhythm
                          const NewSectionHeader(
                            title: 'Temporal Rhythm',
                            actionLabel: 'Time of Day',
                          ),
                          const SizedBox(height: 12),
                          _buildTimeOfDayHeatmap(_overview!),
                          const SizedBox(height: 28),

                          // Top Artists
                          const NewSectionHeader(
                            title: 'Most Played Artists',
                            actionLabel: 'All Time',
                          ),
                          const SizedBox(height: 12),
                          _buildTopArtistsList(_overview!),
                          const SizedBox(height: 28),

                          // Top Songs
                          const NewSectionHeader(
                            title: 'Favorite Tracks',
                            actionLabel: 'Top Replays',
                          ),
                          const SizedBox(height: 12),
                          _buildTopTracksList(_overview!),
                          const SizedBox(height: 28),

                          // Genre Distribution
                          if (_overview!.genreBreakdown.isNotEmpty) ...[
                            const NewSectionHeader(
                              title: 'Genre Fingerprint',
                              actionLabel: 'Affinities',
                            ),
                            const SizedBox(height: 12),
                            _buildGenreBreakdown(_overview!),
                            const SizedBox(height: 28),
                          ],

                          // Activity Timeline
                          const NewSectionHeader(
                            title: 'Recent Activity Timeline',
                            actionLabel: 'Events',
                          ),
                          const SizedBox(height: 12),
                          _buildActivityTimeline(_overview!),
                        ],
                      ),
                    ),
                  ),
                  ContentViewportInsets.sliverBottomSpacer(context, ref),
                ],
              ),
      ),
    );
  }

  Widget _buildMetricGrid(MusicDnaOverview data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard(
              width: cardWidth,
              icon: Icons.timer_outlined,
              value: '${data.totalListeningMinutes}m',
              label: 'Listening Time',
              color: NewExperienceTokens.accentCyan,
            ),
            _buildStatCard(
              width: cardWidth,
              icon: Icons.play_arrow_rounded,
              value: '${data.totalPlays}',
              label: 'Tracks Played',
              color: NewExperienceTokens.accentViolet,
            ),
            _buildStatCard(
              width: cardWidth,
              icon: Icons.people_outline_rounded,
              value: '${data.uniqueArtistsCount}',
              label: 'Unique Artists',
              color: const Color(0xFF10B981),
            ),
            _buildStatCard(
              width: cardWidth,
              icon: Icons.explore_outlined,
              value: '${data.newlyDiscoveredArtistsCount}',
              label: 'Discoveries',
              color: const Color(0xFFF59E0B),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required double width,
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      width: width,
      child: NewGlassContainer(
        borderRadius: NewExperienceTokens.radiusMedium,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: NewExperienceTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: NewExperienceTokens.eyebrowLabel(
                color: NewExperienceTokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeOfDayHeatmap(MusicDnaOverview data) {
    final entries = data.timeOfDayDistribution.entries.toList();
    final maxVal = entries.map((e) => e.value).fold<int>(0, (max, v) => v > max ? v : max);

    return NewGlassContainer(
      borderRadius: NewExperienceTokens.radiusMedium,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: entries.map((entry) {
          final ratio = maxVal == 0 ? 0.0 : entry.value / maxVal;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 75,
                  child: Text(
                    entry.key,
                    style: NewExperienceTokens.bodyMedium(
                      color: NewExperienceTokens.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: ratio.clamp(0.02, 1.0),
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                NewExperienceTokens.accentViolet,
                                NewExperienceTokens.accentCyan,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${entry.value}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: NewExperienceTokens.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopArtistsList(MusicDnaOverview data) {
    if (data.topArtists.isEmpty) {
      return _buildEmptyNotice('Play more songs to build your artist ranking.');
    }

    return NewGlassContainer(
      borderRadius: NewExperienceTokens.radiusMedium,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: data.topArtists.take(5).toList().asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final item = entry.value;

          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: rank == 1
                  ? const Color(0xFFFFD700).withValues(alpha: 0.2)
                  : rank == 2
                      ? const Color(0xFFC0C0C0).withValues(alpha: 0.2)
                      : rank == 3
                          ? const Color(0xFFCD7F32).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.06),
              child: Text(
                '#$rank',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: rank == 1
                      ? const Color(0xFFFFD700)
                      : rank == 2
                          ? const Color(0xFFE2E8F0)
                          : rank == 3
                              ? const Color(0xFFCD7F32)
                              : NewExperienceTokens.textMuted,
                ),
              ),
            ),
            title: Text(
              item.key,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: NewExperienceTokens.textPrimary,
              ),
            ),
            trailing: Text(
              '${item.value} plays',
              style: NewExperienceTokens.bodyMedium(color: NewExperienceTokens.accentCyan),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopTracksList(MusicDnaOverview data) {
    if (data.topSongs.isEmpty) {
      return _buildEmptyNotice('Listen to your favorite songs to see top replays.');
    }

    return NewGlassContainer(
      borderRadius: NewExperienceTokens.radiusMedium,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: data.topSongs.take(5).toList().asMap().entries.map((entry) {
          final item = entry.value;

          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.music_note_rounded, color: NewExperienceTokens.accentViolet),
            title: Text(
              item.key,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: NewExperienceTokens.textPrimary,
              ),
            ),
            trailing: Text(
              '${item.value} replays',
              style: NewExperienceTokens.bodyMedium(color: NewExperienceTokens.textSecondary),
            ),
            onTap: () {
              ref.read(searchProvider.notifier).search(item.key);
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGenreBreakdown(MusicDnaOverview data) {
    final sorted = data.genreBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sorted.take(8).map((g) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: NewExperienceTokens.midnightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: NewExperienceTokens.specularBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                g.key,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: NewExperienceTokens.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: NewExperienceTokens.accentViolet.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${g.value}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: NewExperienceTokens.accentViolet,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActivityTimeline(MusicDnaOverview data) {
    if (data.recentActivityTimeline.isEmpty) {
      return _buildEmptyNotice('Start listening to record historical milestones.');
    }

    return NewGlassContainer(
      borderRadius: NewExperienceTokens.radiusMedium,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        children: data.recentActivityTimeline.map((e) {
          final timeStr = '${e.timestamp.hour.toString().padLeft(2, '0')}:${e.timestamp.minute.toString().padLeft(2, '0')}';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text(
                  timeStr,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: NewExperienceTokens.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: NewExperienceTokens.accentCyan,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.trackTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: NewExperienceTokens.textPrimary,
                        ),
                      ),
                      Text(
                        e.artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: NewExperienceTokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyNotice(String message) {
    return NewGlassContainer(
      borderRadius: NewExperienceTokens.radiusMedium,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          message,
          style: NewExperienceTokens.bodyMedium(color: NewExperienceTokens.textMuted),
        ),
      ),
    );
  }
}
