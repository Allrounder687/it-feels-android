import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/features/settings/settings_provider.dart';
import 'package:it_feels_music/features/settings/hidden_songs_screen.dart';
import 'package:it_feels_music/features/settings/storage_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:it_feels_music/features/settings/audio_settings_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:it_feels_music/services/config_service.dart';
import 'package:it_feels_music/features/admin/force_update_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:it_feels_music/features/settings/lastfm_settings_screen.dart';
import 'package:it_feels_music/features/ai/ai_settings_screen.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/services/download_service.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/widgets/glass_shield_wrapper.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final downloader = ref.watch(downloadProvider);
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    return GlassShieldWrapper(
      isGlassMode: context.isGlassTheme,
      child: Scaffold(
        backgroundColor: context.themeBackgroundColor,
      appBar: AppBar(
        flexibleSpace: kIsWeb
            ? null
            : (isDesktop ? const DragToMoveArea(child: SizedBox.expand()) : null),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: context.canPop()
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: context.themeTextColor),
                onPressed: () => context.pop(),
              )
            : null,
        title: Text(
          "Settings",
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: context.themeTextColor,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewPadding.bottom + 200,
        ),
        children: [
          // ── Shorebird Update Banner ──
          Consumer(
            builder: (context, ref, child) {
              final updatePending = ref.watch(shorebirdUpdatePendingProvider);
              if (updatePending) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.themeAccentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.system_update_rounded, color: context.themeAccentColor, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Update Ready",
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: context.themeTextColor),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "A new patch has been downloaded. Restart to apply.",
                                style: GoogleFonts.inter(fontSize: 13, color: context.themeMutedTextColor),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => exit(0),
                                  icon: const Icon(Icons.refresh_rounded, color: Colors.black, size: 18),
                                  label: Text("Restart Now", style: GoogleFonts.inter(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w700)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: context.themeAccentColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // ══════════════════════════════════════
          // SECTION 1: PLAYBACK & AUDIO
          // ══════════════════════════════════════
          _buildCollapsibleSection(
            context: context,
            title: "Playback & Audio",
            subtitle: "Data Saver: ${settings.isDataSaverEnabled ? 'On' : 'Off'} • GPU: ${settings.enableHardwareDecoding ? 'On' : 'Off'} • Quality: ${settings.defaultVideoQuality}",
            icon: Icons.graphic_eq_rounded,
            initiallyExpanded: true,
            children: [
              _buildSwitchItem(
                context: context,
                title: "Data Saver Mode",
                subtitle: settings.isDataSaverEnabled
                    ? "Audio quality reduced to 64kbps"
                    : "Reduces data usage by streaming at low quality",
                value: settings.isDataSaverEnabled,
                accentColor: context.themeAccentColor,
                onChanged: (val) => ref.read(settingsProvider.notifier).setDataSaverEnabled(val),
              ),
              _buildSelectableItem(
                context: context,
                title: "Wi-Fi Streaming Quality",
                subtitle: settings.wifiQuality,
                options: ["320 kbps (Very High)", "160 kbps (High)", "96 kbps (Medium)", "64 kbps (Low)"],
                currentValue: settings.wifiQuality,
                onSelected: (val) => ref.read(settingsProvider.notifier).setWifiQuality(val),
              ),
              _buildSelectableItem(
                context: context,
                title: "Mobile Data Quality",
                subtitle: settings.mobileQuality,
                options: ["320 kbps (Very High)", "160 kbps (High)", "96 kbps (Medium)", "64 kbps (Low)"],
                currentValue: settings.mobileQuality,
                onSelected: (val) => ref.read(settingsProvider.notifier).setMobileQuality(val),
              ),
              _buildSelectableItem(
                context: context,
                title: "Download Quality",
                subtitle: settings.downloadQuality,
                options: ["320 kbps (Very High)", "160 kbps (High)", "96 kbps (Medium)"],
                currentValue: settings.downloadQuality,
                onSelected: (val) => ref.read(settingsProvider.notifier).setDownloadQuality(val),
              ),
              _buildSelectableItem(
                context: context,
                title: "Video Quality",
                subtitle: settings.defaultVideoQuality,
                options: const ["1080p", "720p", "480p", "360p"],
                currentValue: settings.defaultVideoQuality,
                onSelected: (val) => ref.read(settingsProvider.notifier).setDefaultVideoQuality(val),
              ),
              _buildSwitchItem(
                context: context,
                title: "Video Audio Source",
                subtitle: settings.useVideoAudioSource
                    ? "Using YouTube stream in Video mode"
                    : "Using high-quality music player audio",
                value: settings.useVideoAudioSource,
                accentColor: context.themeAccentColor,
                onChanged: (val) => ref.read(settingsProvider.notifier).setUseVideoAudioSource(val),
              ),
              _buildSwitchItem(
                context: context,
                title: "Hardware Decoding (GPU)",
                subtitle: settings.enableHardwareDecoding
                    ? "Smooth playback & lower battery usage"
                    : "Software decoding fallback",
                value: settings.enableHardwareDecoding,
                accentColor: context.themeAccentColor,
                onChanged: (val) => ref.read(settingsProvider.notifier).setEnableHardwareDecoding(val),
              ),
              _buildSelectableItem(
                context: context,
                title: "Haptics & Feedback",
                subtitle: settings.hapticsMode,
                options: ["Off", "UI Only", "Audio Sync"],
                currentValue: settings.hapticsMode,
                onSelected: (val) {
                  ref.read(settingsProvider.notifier).setHapticsMode(val);
                  if (val == "Audio Sync") {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Warning: Real-time Audio Sync may drain battery.")),
                    );
                  }
                },
              ),
              _buildActionItem(
                context: context,
                title: "Pro Audio Settings",
                subtitle: "Crossfade, Equalizer, and Audio Effects",
                icon: Icons.tune_rounded,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AudioSettingsScreen())),
                showDivider: false,
              ),
            ],
          ),

          // ══════════════════════════════════════
          // SECTION 2: APPEARANCE
          // ══════════════════════════════════════
          _buildCollapsibleSection(
            context: context,
            title: "Appearance",
            subtitle: "Theme: ${settings.theme.split(' (').first} • Videos: ${settings.enableMusicVideos ? 'On' : 'Off'}",
            icon: Icons.palette_rounded,
            children: [
              // Graphics Quality — compact
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Graphics & Performance", style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: context.themeTextColor)),
                    const SizedBox(height: 4),
                    Text("Controls blur effects and animation quality", style: GoogleFonts.inter(fontSize: 12, color: context.themeMutedTextColor)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<GraphicsQuality>(
                        segments: const [
                          ButtonSegment<GraphicsQuality>(value: GraphicsQuality.low, label: Text('Low')),
                          ButtonSegment<GraphicsQuality>(value: GraphicsQuality.medium, label: Text('Medium')),
                          ButtonSegment<GraphicsQuality>(value: GraphicsQuality.high, label: Text('High')),
                        ],
                        selected: {settings.graphicsQuality},
                        onSelectionChanged: (s) => ref.read(settingsProvider.notifier).setGraphicsQuality(s.first),
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) =>
                              states.contains(WidgetState.selected) ? context.themeAccentColor.withValues(alpha: 0.2) : Colors.transparent),
                          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) =>
                              states.contains(WidgetState.selected) ? context.themeAccentColor : context.themeTextColor),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 0.5, color: context.themeMutedTextColor.withValues(alpha: 0.15), indent: 16, endIndent: 16),
              _buildSelectableItem(
                context: context,
                title: "App Theme",
                subtitle: settings.theme,
                options: ["System (Material You)", "Dynamic (Album Art)", "Light Mode", "Midnight Dark", "Burgundy Dark", "Pitch Black (AMOLED)", "Glass (Desktop)"],
                currentValue: settings.theme,
                onSelected: (val) {
                  ref.read(settingsProvider.notifier).setTheme(val);
                  AppThemeMode mode = AppThemeMode.dynamic;
                  if (val == "System (Material You)") mode = AppThemeMode.materialYou;
                  if (val == "Midnight Dark") mode = AppThemeMode.midnight;
                  if (val == "Burgundy Dark") mode = AppThemeMode.burgundy;
                  if (val == "Pitch Black (AMOLED)") mode = AppThemeMode.amoled;
                  if (val == "Light Mode") mode = AppThemeMode.light;
                  if (val == "Glass (Desktop)") mode = AppThemeMode.glass;
                  ref.read(audioPlayerProvider.notifier).setAppThemeMode(mode);
                },
              ),
              _buildSelectableItem(
                context: context,
                title: "Default Startup Category",
                subtitle: settings.defaultCategory,
                options: ["YOU", "Moods", "Charts", "Bollywood", "Telugu", "Tamil", "Punjabi", "Hollywood", "Trending", "Playlists", "Albums"],
                currentValue: settings.defaultCategory,
                onSelected: (val) => ref.read(settingsProvider.notifier).setDefaultCategory(val),
              ),
              _buildSwitchItem(
                context: context,
                title: "Music Videos & Video Tab",
                subtitle: settings.enableMusicVideos ? "Dedicated Videos tab unlocked" : "Pure audio mode",
                value: settings.enableMusicVideos,
                accentColor: context.themeAccentColor,
                onChanged: (val) => ref.read(settingsProvider.notifier).setEnableMusicVideos(val),
                showDivider: isDesktop, // only show divider if desktop items follow
              ),
              // Desktop-only appearance items
              if (isDesktop) ...[
                _buildSwitchItem(
                  context: context,
                  title: "Solid Title Bar",
                  subtitle: "Disables the translucent glass effect",
                  value: settings.useSolidTitleBar,
                  accentColor: context.themeAccentColor,
                  onChanged: (val) => ref.read(settingsProvider.notifier).toggleSolidTitleBar(val),
                ),
                _buildSwitchItem(
                  context: context,
                  title: "Launch at Startup",
                  subtitle: "Auto-start when you log in",
                  value: settings.launchAtStartup,
                  accentColor: context.themeAccentColor,
                  onChanged: (val) => ref.read(settingsProvider.notifier).toggleLaunchAtStartup(val),
                  showDivider: false,
                ),
              ],
            ],
          ),

          // ══════════════════════════════════════
          // SECTION 3: STORAGE & OFFLINE
          // ══════════════════════════════════════
          _buildCollapsibleSection(
            context: context,
            title: "Storage & Offline",
            subtitle: "Smart Downloads: ${settings.enableSmartDownloads ? 'On' : 'Off'} • ${downloader.downloadedSongs.length} tracks",
            icon: Icons.sd_storage_rounded,
            children: [
              _buildSwitchItem(
                context: context,
                title: "Smart Downloads",
                subtitle: settings.enableSmartDownloads
                    ? "Auto-downloads your top 50 played songs"
                    : "Background caching disabled",
                value: settings.enableSmartDownloads,
                accentColor: context.themeAccentColor,
                onChanged: (val) => ref.read(settingsProvider.notifier).setEnableSmartDownloads(val),
              ),
              _buildActionItem(
                context: context,
                title: "Storage Manager",
                subtitle: "Manage offline downloads and cache",
                icon: Icons.storage_rounded,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StorageScreen())),
              ),
              _buildActionItem(
                context: context,
                title: "Download Location",
                subtitle: settings.customDownloadPath.isEmpty ? "Internal App Storage" : settings.customDownloadPath,
                icon: Icons.folder_special_rounded,
                onTap: () async {
                  String? selected = await FilePicker.getDirectoryPath();
                  if (selected != null) {
                    ref.read(settingsProvider.notifier).setCustomDownloadPath(selected);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Location updated: $selected")));
                  }
                },
              ),
              if (isDesktop)
                _buildActionItem(
                  context: context,
                  title: "Open Downloads Folder",
                  subtitle: "View files in Explorer",
                  icon: Icons.folder_open_rounded,
                  onTap: () async {
                    try {
                      final path = await locator<DownloadService>().getDownloadDirectoryPath();
                      final uri = Uri.directory(path);
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to open directory: $e")));
                    }
                  },
                ),
              _buildActionItem(
                context: context,
                title: "Clear All Downloads",
                subtitle: "${downloader.downloadedSongs.length} tracks downloaded",
                icon: Icons.delete_outline_rounded,
                onTap: () async {
                  if (downloader.downloadedSongs.isEmpty) return;
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: context.themeSurfaceColor,
                      title: Text("Clear Downloads", style: GoogleFonts.outfit(color: context.themeTextColor)),
                      content: Text("Delete all offline downloaded songs?", style: GoogleFonts.inter(color: context.themeMutedTextColor)),
                      actions: [
                        TextButton(child: Text("Cancel", style: TextStyle(color: context.themeMutedTextColor)), onPressed: () => Navigator.pop(ctx, false)),
                        TextButton(child: const Text("Delete All", style: TextStyle(color: Colors.redAccent)), onPressed: () => Navigator.pop(ctx, true)),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(downloadProvider.notifier).clearAllDownloads();
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All downloads cleared")));
                  }
                },
              ),
              _buildActionItem(
                context: context,
                title: "Clear Cache",
                subtitle: "Free up temporary space",
                icon: Icons.cleaning_services_rounded,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cache cleared successfully"))),
                showDivider: false,
              ),
            ],
          ),

          // ══════════════════════════════════════
          // SECTION 4: ACCOUNT & INTEGRATIONS
          // ══════════════════════════════════════
          _buildCollapsibleSection(
            context: context,
            title: "Account & Integrations",
            subtitle: "Android Auto: ${settings.enableAndroidAuto ? 'On' : 'Off'}",
            icon: Icons.manage_accounts_rounded,
            children: [
              _buildActionItem(
                context: context,
                title: "AI Settings",
                subtitle: "Configure AI-powered playlist generation",
                icon: Icons.auto_awesome_rounded,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AISettingsScreen())),
              ),
              _buildActionItem(
                context: context,
                title: "Manage Hidden Songs",
                subtitle: "View and unhide removed songs",
                icon: Icons.visibility_off_outlined,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HiddenSongsScreen())),
              ),
              _buildActionItem(
                context: context,
                title: "Last.fm Scrobbling",
                subtitle: "Sync listening history",
                icon: Icons.queue_music,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LastfmSettingsScreen())),
              ),
              _buildSwitchItem(
                context: context,
                title: "Android Auto",
                subtitle: settings.enableAndroidAuto
                    ? "Playlists synced to car dashboard"
                    : "Sync playlists with your car",
                value: settings.enableAndroidAuto,
                accentColor: context.themeAccentColor,
                onChanged: (val) async {
                  if (val) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: context.themeSurfaceColor,
                        title: Text("Enable Android Auto", style: GoogleFonts.outfit(color: context.themeTextColor)),
                        content: Text("Expose your playlists to the car OS?", style: GoogleFonts.inter(color: context.themeMutedTextColor)),
                        actions: [
                          TextButton(child: Text("Cancel", style: TextStyle(color: context.themeMutedTextColor)), onPressed: () => Navigator.pop(ctx, false)),
                          TextButton(child: Text("Proceed", style: TextStyle(color: context.themeAccentColor)), onPressed: () => Navigator.pop(ctx, true)),
                        ],
                      ),
                    );
                    if (confirm == true) ref.read(settingsProvider.notifier).setEnableAndroidAuto(true);
                  } else {
                    ref.read(settingsProvider.notifier).setEnableAndroidAuto(false);
                  }
                },
                showDivider: false,
              ),
            ],
          ),

          // ══════════════════════════════════════
          // SECTION 5: ADVANCED
          // ══════════════════════════════════════
          _buildCollapsibleSection(
            context: context,
            title: "Advanced",
            subtitle: "Proxy: ${settings.useProxyBackend ? 'On' : 'Off'} • Cloud routing",
            icon: Icons.developer_board_rounded,
            children: [
              _buildSwitchItem(
                context: context,
                title: "Serverless Proxy Backend",
                subtitle: settings.useProxyBackend
                    ? "Active: Streaming via Cloud Proxy"
                    : "Inactive: Direct mode",
                value: settings.useProxyBackend,
                accentColor: context.themeAccentColor,
                onChanged: (val) async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: context.themeSurfaceColor,
                      title: Text("Advanced Setting", style: GoogleFonts.outfit(color: context.themeTextColor, fontWeight: FontWeight.bold)),
                      content: Text(
                        val ? "Only proceed if instructed." : "Disabling will break Last.fm and Lyrics. Are you sure?",
                        style: GoogleFonts.inter(color: context.themeTextColor),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Cancel", style: TextStyle(color: context.themeMutedTextColor))),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text("Proceed", style: TextStyle(color: context.themeAccentColor))),
                      ],
                    ),
                  );
                  if (confirm == true) ref.read(settingsProvider.notifier).setUseProxyBackend(val);
                },
              ),
              _buildActionItem(
                context: context,
                title: "Proxy URL",
                subtitle: settings.proxyUrl,
                icon: Icons.cloud_queue_rounded,
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: context.themeSurfaceColor,
                      title: Text("Advanced Setting", style: GoogleFonts.outfit(color: context.themeTextColor, fontWeight: FontWeight.bold)),
                      content: Text("Changing Proxy URL may break the app.", style: GoogleFonts.inter(color: context.themeTextColor)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Cancel", style: TextStyle(color: context.themeMutedTextColor))),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text("Proceed", style: TextStyle(color: context.themeAccentColor))),
                      ],
                    ),
                  );
                  if (confirm != true) return;
                  if (!context.mounted) return;
                  final tc = TextEditingController(text: settings.proxyUrl);
                  final newUrl = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: context.themeSurfaceColor,
                      title: Text("Proxy Endpoint", style: GoogleFonts.outfit(color: context.themeTextColor)),
                      content: TextField(controller: tc, style: TextStyle(color: context.themeTextColor)),
                      actions: [
                        TextButton(child: Text("Cancel", style: TextStyle(color: context.themeMutedTextColor)), onPressed: () => Navigator.pop(ctx)),
                        TextButton(child: Text("Save", style: TextStyle(color: context.themeAccentColor)), onPressed: () => Navigator.pop(ctx, tc.text.trim())),
                      ],
                    ),
                  );
                  if (newUrl != null && newUrl.isNotEmpty) ref.read(settingsProvider.notifier).setProxyUrl(newUrl);
                },
                showDivider: false,
              ),
            ],
          ),

          // ══════════════════════════════════════
          // SECTION 6: ABOUT
          // ══════════════════════════════════════
          _buildCollapsibleSection(
            context: context,
            title: "About",
            subtitle: "App version and updates",
            icon: Icons.info_outline_rounded,
            children: [
              _buildActionItem(
                context: context,
                title: "Check for Updates",
                subtitle: "See if a new version is available",
                icon: Icons.system_update_rounded,
                onTap: () => _handleCheckForUpdates(context, ref),
              ),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version ?? '...';
                  return _buildActionItem(
                    context: context,
                    title: "It Feels Music",
                    subtitle: "Version $version • Developer: FaiXal",
                    icon: Icons.info_outline_rounded,
                    onTap: () {},
                    showDivider: false,
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    ));
  }

  // ═══════════════════════════════════════════════
  //  HELPER WIDGETS
  // ═══════════════════════════════════════════════

  /// Wraps children in a collapsible ExpansionTile section
  Widget _buildCollapsibleSection({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: context.themeCardColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            iconColor: context.themeMutedTextColor,
            collapsedIconColor: context.themeMutedTextColor,
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Icon(icon, color: context.themeAccentColor, size: 24),
            title: Text(
              title,
              style: GoogleFonts.outfit(
                color: context.themeTextColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: GoogleFonts.inter(
                color: context.themeMutedTextColor,
                fontSize: 13,
              ),
            ),
            children: [
              Divider(height: 1, thickness: 1, color: context.themeMutedTextColor.withValues(alpha: 0.1)),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  /// A consistent toggle switch item for use inside grouped cards
  Widget _buildSwitchItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool value,
    required Color accentColor,
    required ValueChanged<bool> onChanged,
    bool showDivider = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: context.themeTextColor)),
          subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: context.themeMutedTextColor)),
          value: value,
          activeTrackColor: accentColor,
          onChanged: onChanged,
        ),
        if (showDivider)
          Divider(height: 1, thickness: 0.5, color: context.themeMutedTextColor.withValues(alpha: 0.15), indent: 16, endIndent: 16),
      ],
    );
  }

  /// A consistent selectable (dropdown) item for use inside grouped cards
  Widget _buildSelectableItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<String> options,
    required String currentValue,
    required Function(String) onSelected,
    bool showDivider = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: context.themeTextColor)),
          subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: context.themeMutedTextColor)),
          trailing: Icon(Icons.arrow_drop_down, color: context.themeMutedTextColor),
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => SimpleDialog(
                backgroundColor: context.themeSurfaceColor,
                title: Text(title, style: GoogleFonts.outfit(color: context.themeTextColor, fontSize: 18)),
                children: options.map((opt) {
                  final isSelected = opt == currentValue;
                  return SimpleDialogOption(
                    onPressed: () {
                      onSelected(opt);
                      Navigator.pop(ctx);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              opt,
                              style: GoogleFonts.inter(
                                color: isSelected ? context.themeAccentColor : context.themeMutedTextColor,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (isSelected) Icon(Icons.check, color: context.themeAccentColor, size: 18),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
        if (showDivider)
          Divider(height: 1, thickness: 0.5, color: context.themeMutedTextColor.withValues(alpha: 0.15), indent: 16, endIndent: 16),
      ],
    );
  }

  /// A consistent action tile (icon + chevron) for use inside grouped cards
  Widget _buildActionItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: Icon(icon, color: context.themeMutedTextColor, size: 22),
          title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: context.themeTextColor)),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 12, color: context.themeMutedTextColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Icon(Icons.chevron_right_rounded, color: context.themeMutedTextColor, size: 20),
          onTap: onTap,
        ),
        if (showDivider)
          Divider(height: 1, thickness: 0.5, color: context.themeMutedTextColor.withValues(alpha: 0.15), indent: 16, endIndent: 16),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  //  CHECK FOR UPDATES (extracted from inline)
  // ═══════════════════════════════════════════════
  Future<void> _handleCheckForUpdates(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 16),
          Text("Checking for updates..."),
        ]),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final shorebird = ShorebirdUpdater();
        final status = await shorebird.checkForUpdate();

        if (status == UpdateStatus.outdated && context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent)),
                SizedBox(width: 16),
                Text("Downloading background patch..."),
              ]),
              duration: Duration(seconds: 60),
            ),
          );

          await shorebird.update();

          if (context.mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ref.read(shorebirdUpdatePendingProvider.notifier).state = true;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Patch downloaded! Please restart the app to apply."), duration: Duration(seconds: 5)),
            );
          }
          return;
        }
      }
    } catch (e) {
      debugPrint("Shorebird check failed: $e");
    }

    AppConfig? config;
    try {
      config = await ConfigService.fetchRemoteConfig();
    } catch (e) {
      debugPrint("Error checking updates: $e");
    } finally {
      if (context.mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }

    if (!context.mounted) return;

    if (config != null) {
      final requiresForce = await ConfigService.requiresForceUpdate(config);
      final hasSoft = await ConfigService.hasSoftUpdate(config);
      if ((requiresForce || hasSoft) && context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ForceUpdateScreen(
              latestVersion: config!.latestVersion,
              updateUrl: config.updateUrl,
              releaseNotes: config.releaseNotes,
              iosUpdateUrl: config.iosUpdateUrl,
              isSoftUpdate: hasSoft,
            ),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You are on the latest version!")));
      }
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to check for updates. Check your connection.")));
    }
  }
}
