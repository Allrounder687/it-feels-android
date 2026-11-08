import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/settings/settings_provider.dart';
import 'package:it_feels_music/features/settings/app_experience_selector_screen.dart';
import 'package:it_feels_music/features/settings/keyboard_shortcuts_screen.dart';
import 'package:it_feels_music/features/settings/profile_screen.dart';
import 'package:it_feels_music/features/new_experience/settings/taste_profile_screen.dart';
import 'package:it_feels_music/features/new_experience/dna/new_music_dna_screen.dart';
import 'package:it_feels_music/features/new_experience/diagnostics/enterprise_diagnostic_sheet.dart';
import 'package:it_feels_music/features/new_experience/diagnostics/content_health_sheet.dart';
import 'package:it_feels_music/features/new_experience/diagnostics/diagnostics_dashboard_screen.dart';
import 'package:it_feels_music/features/new_experience/player/new_equalizer_sheet.dart';
import 'package:it_feels_music/services/download_scanner_service.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/new_ambient_canvas.dart';
import '../widgets/new_glass_container.dart';
import '../theme/content_viewport_insets.dart';

class NewSettingsScreen extends ConsumerWidget {
  final VoidCallback? onNavigateHome;
  const NewSettingsScreen({super.key, this.onNavigateHome});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final user = ref.watch(authProvider).currentUser;
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    return NewAmbientCanvas(
      intensity: 0.25,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: ContentViewportInsets.bottom(context, ref),
                ),
                children: [
                  // Header
                  Row(
                    children: [
                      if (onNavigateHome != null)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                          onPressed: onNavigateHome,
                          tooltip: 'Return to Home',
                        ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SETTINGS & CONTROLS',
                            style: NewExperienceTokens.eyebrowLabel(
                              color: NewExperienceTokens.accentCyan,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Preferences',
                            style: NewExperienceTokens.displayHero(fontSize: 28),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Group 1: Interface & Experience ──
                  _buildSectionHeader('EXPERIENCE & VISUALS'),
                  NewGlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // App Experience Card
                        InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AppExperienceSelectorScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(NewExperienceTokens.radiusMedium),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  NewExperienceTokens.accentViolet.withValues(alpha: 0.18),
                                  NewExperienceTokens.accentCyan.withValues(alpha: 0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(NewExperienceTokens.radiusMedium),
                              border: Border.all(
                                color: NewExperienceTokens.accentViolet.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: NewExperienceTokens.accentViolet,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.palette_rounded, color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'App Experience Mode',
                                        style: NewExperienceTokens.sectionTitle(fontSize: 15),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '2026 Obsidian Experience Active • Switch or Compare',
                                        style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.accentCyan),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white70),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Graphics Quality
                        Text('Graphics & Blur Fidelity', style: NewExperienceTokens.sectionTitle(fontSize: 14)),
                        const SizedBox(height: 8),
                        Row(
                          children: GraphicsQuality.values.map((g) {
                            final isSel = settings.graphicsQuality == g;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(g.name.toUpperCase()),
                                selected: isSel,
                                onSelected: (_) => settingsNotifier.setGraphicsQuality(g),
                                selectedColor: NewExperienceTokens.accentViolet,
                                backgroundColor: Colors.white.withValues(alpha: 0.06),
                                labelStyle: TextStyle(
                                  color: isSel ? Colors.white : NewExperienceTokens.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Group: Music Taste & Personalization ──
                  _buildSectionHeader('MUSIC INTELLIGENCE & TASTE'),
                  NewGlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Your Music DNA Card
                        InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const NewMusicDnaScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: NewExperienceTokens.accentCyan.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.fingerprint_rounded, color: NewExperienceTokens.accentCyan, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Your Music DNA', style: NewExperienceTokens.sectionTitle(fontSize: 15)),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Personal listening analytics, hourly rhythm & discovery timeline',
                                        style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white70),
                              ],
                            ),
                          ),
                        ),
                        const Divider(color: Colors.white10),

                        InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const TasteProfileScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: NewExperienceTokens.accentViolet.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.auto_awesome_rounded, color: NewExperienceTokens.accentViolet, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Music Taste Profile', style: NewExperienceTokens.sectionTitle(fontSize: 15)),
                                      const SizedBox(height: 2),
                                      Text(
                                        'View learned affinities, tune discovery balance & manage exclusions',
                                        style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white70),
                              ],
                            ),
                          ),
                        ),
                        const Divider(color: Colors.white10),

                        // System Diagnostics Sheet
                        InkWell(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const EnterpriseDiagnosticSheet(),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.monitor_heart_rounded, color: Color(0xFF10B981), size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Enterprise System Diagnostics', style: NewExperienceTokens.sectionTitle(fontSize: 15)),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Federated provider health, circuit breakers, cache hit rates & latency',
                                        style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white70),
                              ],
                            ),
                          ),
                        ),
                        const Divider(color: Colors.white10),

                        // Living Catalogue & Content Health Sheet
                        InkWell(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const ContentHealthSheet(),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: NewExperienceTokens.accentCyan.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.verified_rounded, color: NewExperienceTokens.accentCyan, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Living Catalogue & Content Health', style: NewExperienceTokens.sectionTitle(fontSize: 15)),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Section-by-section health audits, duplicate prevention & artwork repair stats',
                                        style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white70),
                              ],
                            ),
                          ),
                        ),
                        const Divider(color: Colors.white10),

                        // Deep Observability & Diagnostics Dashboard
                        InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const DiagnosticsDashboardScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: NewExperienceTokens.accentViolet.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.analytics_rounded, color: NewExperienceTokens.accentViolet, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Observability & Diagnostics Hub', style: NewExperienceTokens.sectionTitle(fontSize: 15)),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Structured logging, playback tracing, latency telemetry & diagnostic export',
                                        style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white70),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Group 2: Audio & Playback ──
                  _buildSectionHeader('AUDIO & STREAMING'),
                  NewGlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Streaming Audio Quality', style: NewExperienceTokens.sectionTitle(fontSize: 14)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            '160 kbps (High)',
                            '320 kbps (Very High)',
                          ].map((q) {
                            final isSel = settings.wifiQuality.contains(q.split(' ').first);
                            return ChoiceChip(
                              label: Text(q),
                              selected: isSel,
                              onSelected: (_) => settingsNotifier.setWifiQuality(q),
                              selectedColor: NewExperienceTokens.accentViolet,
                              backgroundColor: Colors.white.withValues(alpha: 0.06),
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : NewExperienceTokens.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          }).toList(),
                        ),
                        Divider(height: 28, color: NewExperienceTokens.specularBorder),

                        // 10-Band Graphic Equalizer
                        InkWell(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const NewEqualizerSheet(),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: NewExperienceTokens.accentCyan.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.equalizer_rounded, color: NewExperienceTokens.accentCyan, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('10-Band Graphic Equalizer', style: NewExperienceTokens.sectionTitle(fontSize: 15)),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Studio biquad peaking filters, loudness normalization, bass & treble boosts',
                                        style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white70),
                              ],
                            ),
                          ),
                        ),
                        Divider(height: 20, color: NewExperienceTokens.specularBorder),

                        _buildToggleRow(
                          title: 'Hardware Decoding Acceleration',
                          subtitle: 'Use native GPU/DSP pipeline for MP3, AAC and FLAC decoders',
                          value: settings.enableHardwareDecoding,
                          onChanged: (v) => settingsNotifier.setEnableHardwareDecoding(v),
                        ),
                        Divider(height: 20, color: NewExperienceTokens.specularBorder),

                        _buildToggleRow(
                          title: 'Use Serverless Edge Proxy',
                          subtitle: 'Route catalogue & lyrics through low-latency Cloudflare Edge Workers',
                          value: settings.useProxyBackend,
                          onChanged: (v) => settingsNotifier.setUseProxyBackend(v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Group 3: Controls & Desktop ──
                  if (isDesktop) ...[
                    _buildSectionHeader('CONTROLS & DESKTOP'),
                    NewGlassContainer(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const KeyboardShortcutsScreen()),
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.keyboard_rounded, color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Keyboard Shortcuts', style: NewExperienceTokens.sectionTitle(fontSize: 15)),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Configure player hotkeys & check Windows system overlap',
                                          style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white70),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Group 4: Offline Library ──
                  _buildSectionHeader('OFFLINE & DOWNLOADS'),
                  NewGlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Rescan Local Downloads', style: NewExperienceTokens.sectionTitle(fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Index downloaded tracks into offline library & Isar search vectors',
                                    style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final count = await locator<DownloadScannerService>().scanAllDownloads();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Discovered and verified $count downloaded songs.'),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: NewExperienceTokens.accentViolet,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: NewExperienceTokens.accentViolet,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Rescan'),
                            ),
                          ],
                        ),
                        Divider(height: 20, color: NewExperienceTokens.specularBorder),
                        _buildToggleRow(
                          title: 'Smart Offline Caching',
                          subtitle: 'Pre-cache frequently played songs in memory for instant playback',
                          value: settings.enableSmartDownloads,
                          onChanged: (v) => settingsNotifier.setEnableSmartDownloads(v),
                        ),
                        Divider(height: 20, color: NewExperienceTokens.specularBorder),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Clear In-Memory & Image Cache', style: NewExperienceTokens.sectionTitle(fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Release decode memory buffers and purge thumbnail cache',
                                    style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                PaintingBinding.instance.imageCache.clear();
                                PaintingBinding.instance.imageCache.clearLiveImages();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('In-memory image and artwork cache cleared.'),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: NewExperienceTokens.accentCyan,
                                    ),
                                  );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: NewExperienceTokens.specularBorder),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.cleaning_services_rounded, size: 16, color: NewExperienceTokens.accentCyan),
                              label: const Text('Clear'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Group 5: Account & About ──
                  _buildSectionHeader('ACCOUNT & SYSTEM'),
                  NewGlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ProfileScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: NewExperienceTokens.midnightSurface,
                                  backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                                  child: user?.photoURL == null
                                      ? const Icon(Icons.person_rounded, color: Colors.white, size: 20)
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user?.displayName ?? 'Guest User',
                                        style: NewExperienceTokens.sectionTitle(fontSize: 15),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        user?.email ?? 'Operating in offline/guest mode',
                                        style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white70),
                              ],
                            ),
                          ),
                        ),
                        Divider(height: 24, color: NewExperienceTokens.specularBorder),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'IT Feels Music Version',
                              style: NewExperienceTokens.bodyMedium(color: NewExperienceTokens.textSecondary),
                            ),
                            Text(
                              'v3.9.3 Obsidian',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: NewExperienceTokens.accentCyan,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: NewExperienceTokens.eyebrowLabel(
          color: NewExperienceTokens.textSecondary,
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: NewExperienceTokens.sectionTitle(fontSize: 15)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: NewExperienceTokens.accentViolet,
        ),
      ],
    );
  }
}
