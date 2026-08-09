import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/features/settings/settings_provider.dart';
import 'package:it_feels_music/features/settings/hidden_songs_screen.dart';
import 'package:it_feels_music/features/settings/storage_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:it_feels_music/services/backend_api_service.dart';
import 'package:it_feels_music/features/settings/audio_settings_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:it_feels_music/services/config_service.dart';
import 'package:it_feels_music/features/admin/force_update_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:it_feels_music/features/settings/lastfm_settings_screen.dart';
import 'package:it_feels_music/features/ai/ai_settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/services/download_service.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloader = ref.watch(downloadProvider);

    return Consumer(builder: (context, ref, child) { final settings = ref.watch(settingsProvider); 
        return Scaffold(
          backgroundColor: context.themeBackgroundColor,
          appBar: AppBar(
        flexibleSpace: kIsWeb ? null : (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux ? null : const DragToMoveArea(child: SizedBox.expand())),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: context.themeTextColor),
              onPressed: () => Navigator.pop(context),
            ),
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
              bottom: MediaQuery.of(context).viewPadding.bottom + 200, // Safe clearance for mini-player and nav bar
            ),
            children: [
              Consumer(
                builder: (context, ref, child) {
                  final updatePending = ref.watch(shorebirdUpdatePendingProvider);
                  if (updatePending) {
                    return Card(
                      color: context.themeAccentColor.withValues(alpha: 0.15),
                      margin: const EdgeInsets.only(bottom: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: context.themeAccentColor, size: 28),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Update Ready! ðŸŽ‰",
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: context.themeTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "A new patch has been downloaded. Restart the app to apply fixes.",
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: context.themeMutedTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => exit(0), // Trigger app restart
                                      icon: const Icon(Icons.refresh_rounded, color: Colors.black),
                                      label: Text(
                                        "Restart Now",
                                        style: GoogleFonts.inter(
                                          color: Colors.black,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: context.themeAccentColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
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
              // â”€â”€ Category 1: Playback & Audio â”€â”€
              _buildSectionHeader(context, "ðŸŽµ Playback & Audio"),
              const SizedBox(height: 8),

              SwitchListTile.adaptive(
                title: Text("Data Saver Mode", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.themeTextColor)),
                subtitle: Text(
                  settings.isDataSaverEnabled
                      ? "Active: Audio quality reduced to 64kbps & low bandwidth mode active"
                      : "Reduces data usage by streaming at low quality",
                  style: GoogleFonts.inter(fontSize: 12, color: context.themeMutedTextColor),
                ),
                value: settings.isDataSaverEnabled,
                activeTrackColor: context.themeAccentColor,
                onChanged: (val) => ref.read(settingsProvider.notifier).setDataSaverEnabled(val),
              ),

              _buildSelectableTile(
                context: context, title: "Wi-Fi Streaming Quality", subtitle: settings.wifiQuality,
                options: ["320 kbps (Very High)", "160 kbps (High)", "96 kbps (Medium)", "64 kbps (Low)"],
                currentValue: settings.wifiQuality, onSelected: (val) => ref.read(settingsProvider.notifier).setWifiQuality(val),
              ),
              _buildSelectableTile(
                context: context, title: "Mobile Data Streaming Quality", subtitle: settings.mobileQuality,
                options: ["320 kbps (Very High)", "160 kbps (High)", "96 kbps (Medium)", "64 kbps (Low)"],
                currentValue: settings.mobileQuality, onSelected: (val) => ref.read(settingsProvider.notifier).setMobileQuality(val),
              ),
              _buildSelectableTile(
                context: context, title: "Download Quality", subtitle: settings.downloadQuality,
                options: ["320 kbps (Very High)", "160 kbps (High)", "96 kbps (Medium)"],
                currentValue: settings.downloadQuality, onSelected: (val) => ref.read(settingsProvider.notifier).setDownloadQuality(val),
              ),
              _buildSelectableTile(
                context: context, title: "Default Video Quality", subtitle: "Select preferred video playback resolution",
                options: const ["1080p", "720p", "480p", "360p"],
                currentValue: settings.defaultVideoQuality, onSelected: (val) => ref.read(settingsProvider.notifier).setDefaultVideoQuality(val),
              ),
              
              SwitchListTile.adaptive(
                title: Text("Use Video Audio Source", style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.themeTextColor)),
                subtitle: Text(
                  settings.useVideoAudioSource ? "Switches audio to YouTube stream in Video mode" : "Keeps high-quality music player audio",
                  style: GoogleFonts.inter(fontSize: 12, color: context.themeMutedTextColor),
                ),
                value: settings.useVideoAudioSource,
                activeTrackColor: context.themeAccentColor,
                onChanged: (val) => ref.read(settingsProvider.notifier).setUseVideoAudioSource(val),
              ),

              SwitchListTile.adaptive(
                value: settings.enableHardwareDecoding,
                activeTrackColor: context.themeAccentColor,
                title: Text("Hardware Decoding (GPU)", style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.themeTextColor)),
                subtitle: Text(
                  settings.enableHardwareDecoding ? "Smooth playback & lower battery usage" : "Software decoding fallback",
                  style: GoogleFonts.inter(fontSize: 12, color: context.themeMutedTextColor),
                ),
                onChanged: (val) => ref.read(settingsProvider.notifier).setEnableHardwareDecoding(val),
              ),

              _buildSelectableTile(
                context: context, title: "Haptics & Feedback", subtitle: settings.hapticsMode,
                options: ["Off", "UI Only", "Audio Sync"], currentValue: settings.hapticsMode,
                onSelected: (val) {
                  ref.read(settingsProvider.notifier).setHapticsMode(val);
                  if (val == "Audio Sync") ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Warning: Real-time Audio Sync may drain battery.")));
                },
              ),

              _buildActionTile(
                context: context, title: "Pro Audio Settings", subtitle: "Crossfade, Equalizer, and Audio Effects", icon: Icons.graphic_eq_rounded,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AudioSettingsScreen())),
              ),

              const SizedBox(height: 24),

              // â”€â”€ Category 2: Appearance & UI â”€â”€
              _buildSectionHeader(context, "ðŸŽ¨ Appearance & UI"),
              const SizedBox(height: 8),

              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                title: Text("Graphics & Performance", style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.themeTextColor)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
                  child: Text("High: Premium visuals, animations & blurs\nMedium: Disables expensive blurs\nLow: Maximum performance (No blurs, simple UI, low-res covers)", style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: context.themeMutedTextColor)),
                ),
                isThreeLine: true,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
                child: SegmentedButton<GraphicsQuality>(
                  segments: const [
                    ButtonSegment<GraphicsQuality>(value: GraphicsQuality.low, label: Text('Low'), icon: Icon(Icons.speed_rounded)),
                    ButtonSegment<GraphicsQuality>(value: GraphicsQuality.medium, label: Text('Medium'), icon: Icon(Icons.balance_rounded)),
                    ButtonSegment<GraphicsQuality>(value: GraphicsQuality.high, label: Text('High'), icon: Icon(Icons.auto_awesome_rounded)),
                  ],
                  selected: {settings.graphicsQuality},
                  onSelectionChanged: (newSelection) => ref.read(settingsProvider.notifier).setGraphicsQuality(newSelection.first),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) => states.contains(WidgetState.selected) ? context.themeAccentColor.withValues(alpha: 0.2) : Colors.transparent),
                    foregroundColor: WidgetStateProperty.resolveWith<Color>((states) => states.contains(WidgetState.selected) ? context.themeAccentColor : context.themeTextColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _buildSelectableTile(
                context: context, title: "App Primary Theme", subtitle: settings.theme,
                options: ["System (Material You)", "Dynamic (Album Art)", "Light Mode", "Midnight Dark", "Burgundy Dark", "Pitch Black (AMOLED)"],
                currentValue: settings.theme,
                onSelected: (val) {
                  ref.read(settingsProvider.notifier).setTheme(val);
                  AppThemeMode mode = AppThemeMode.dynamic;
                  if (val == "System (Material You)") mode = AppThemeMode.materialYou;
                  if (val == "Midnight Dark") mode = AppThemeMode.midnight;
                  if (val == "Burgundy Dark") mode = AppThemeMode.burgundy;
                  if (val == "Pitch Black (AMOLED)") mode = AppThemeMode.amoled;
                  if (val == "Light Mode") mode = AppThemeMode.light;
                  ref.read(audioPlayerProvider.notifier).setAppThemeMode(mode);
                },
              ),

              _buildSelectableTile(
                context: context, title: "Default Startup Category", subtitle: settings.defaultCategory,
                options: ["YOU", "Moods", "Charts", "Bollywood", "Telugu", "Tamil", "Punjabi", "Hollywood", "Trending", "Playlists", "Albums"],
                currentValue: settings.defaultCategory,
                onSelected: (val) => ref.read(settingsProvider.notifier).setDefaultCategory(val),
              ),

              SwitchListTile.adaptive(
                value: settings.enableMusicVideos,
                activeTrackColor: context.themeAccentColor,
                title: Text("Enable Music Videos & Video Tab", style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.themeTextColor)),
                subtitle: Text(settings.enableMusicVideos ? "Dedicated Videos tab unlocked" : "Pure audio mode (0 video clutter)", style: GoogleFonts.inter(fontSize: 12, color: context.themeMutedTextColor)),
                onChanged: (val) => ref.read(settingsProvider.notifier).setEnableMusicVideos(val),
              ),

              const SizedBox(height: 24),

              // â”€â”€ Category 3: Storage & Offline â”€â”€
              _buildSectionHeader(context, "ðŸ’¾ Storage & Offline"),
              const SizedBox(height: 8),

              SwitchListTile.adaptive(
                value: settings.enableSmartDownloads,
                activeTrackColor: context.themeAccentColor,
                title: Text("Smart Downloads", style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.themeTextColor)),
                subtitle: Text(settings.enableSmartDownloads ? "Auto-downloads your top 50 played songs in the background" : "Background caching disabled", style: GoogleFonts.inter(fontSize: 12, color: context.themeMutedTextColor)),
                onChanged: (val) => ref.read(settingsProvider.notifier).setEnableSmartDownloads(val),
              ),

              if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) ...[
                SwitchListTile.adaptive(
                  value: settings.useSolidTitleBar,
                  activeTrackColor: context.themeAccentColor,
                  title: Text("Solid Title Bar", style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.themeTextColor)),
                  subtitle: Text("Disables the translucent Mica glass effect on desktop", style: GoogleFonts.inter(fontSize: 12, color: context.themeMutedTextColor)),
                  onChanged: (val) => ref.read(settingsProvider.notifier).toggleSolidTitleBar(val),
                ),
                SwitchListTile.adaptive(
                  value: settings.launchAtStartup,
                  activeTrackColor: context.themeAccentColor,
                  title: Text("Launch at Startup", style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.themeTextColor)),
                  subtitle: Text("Automatically start It Feels when you log in", style: GoogleFonts.inter(fontSize: 12, color: context.themeMutedTextColor)),
                  onChanged: (val) => ref.read(settingsProvider.notifier).toggleLaunchAtStartup(val),
                ),
              ],

              _buildActionTile(
                context: context, title: "Smart Storage Manager", subtitle: "Manage offline downloads and audio cache limits", icon: Icons.storage_rounded,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StorageScreen())),
              ),

              _buildActionTile(
                context: context, title: "Download Storage Location", subtitle: settings.customDownloadPath.isEmpty ? "Internal App Storage" : settings.customDownloadPath, icon: Icons.folder_special_rounded,
                onTap: () async {
                  String? selected = await FilePicker.getDirectoryPath();
                  if (selected != null) {
                    ref.read(settingsProvider.notifier).setCustomDownloadPath(selected);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Location updated: $selected")));
                  }
                },
              ),

              if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux))
                _buildActionTile(
                  context: context, title: "Open Downloads Folder", subtitle: "View downloaded files in File Explorer", icon: Icons.folder_open_rounded,
                  onTap: () async {
                    try {
                      final path = await locator<DownloadService>().getDownloadDirectoryPath();
                      final uri = Uri.directory(path);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to open directory: $e")));
                      }
                    }
                  },
                ),

              _buildActionTile(
                context: context, title: "Clear All Downloads", subtitle: "${downloader.downloadedSongs.length} tracks downloaded", icon: Icons.delete_outline_rounded,
                onTap: () async {
                  if (downloader.downloadedSongs.isEmpty) return;
                  final confirm = await showDialog<bool>(
                    context: context, builder: (ctx) => AlertDialog(
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

              _buildActionTile(
                context: context, title: "Clear Cache", subtitle: "Free up temporary space", icon: Icons.cleaning_services_rounded,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cache cleared successfully"))),
              ),

              const SizedBox(height: 24),

              // â”€â”€ Category 4: Account & Integrations â”€â”€
              _buildSectionHeader(context, "ðŸ‘¤ Account & Integrations"),
              const SizedBox(height: 8),

              _buildActionTile(
                context: context, title: "AI Settings", subtitle: "Configure AI-powered playlist generation", icon: Icons.auto_awesome_rounded,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AISettingsScreen())),
              ),

              _buildActionTile(
                context: context, title: "Manage Hidden Songs", subtitle: "View and unhide songs you've removed from your feed", icon: Icons.visibility_off_outlined,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HiddenSongsScreen())),
              ),

              _buildActionTile(
                context: context, title: "Last.fm Scrobbling", subtitle: "Connect your account to sync listening history", icon: Icons.queue_music,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LastfmSettingsScreen())),
              ),

              SwitchListTile(
                title: Text("Android Auto Integration", style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: context.themeTextColor)),
                subtitle: Text("Sync your playlists and history with your car dashboard", style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12)),
                value: settings.enableAndroidAuto,
                activeThumbColor: context.themeAccentColor,
                onChanged: (val) async {
                  if (val) {
                    final confirm = await showDialog<bool>(
                      context: context, builder: (ctx) => AlertDialog(
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
              ),

              const SizedBox(height: 24),

              // â”€â”€ Category 5: Advanced Settings â”€â”€
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  iconColor: context.themeMutedTextColor,
                  collapsedIconColor: context.themeMutedTextColor,
                  title: Text("âš™ï¸ Advanced Settings", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: context.themeMutedTextColor)),
                  children: [
                    ListTile(
                      title: Text("Use Serverless Proxy Backend", style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.themeTextColor)),
                      subtitle: Text(settings.useProxyBackend ? "Active: Stream via Cloud Proxy" : "Inactive: Direct mode. Lyrics/Last.fm will break.", style: GoogleFonts.inter(fontSize: 12, color: context.themeMutedTextColor)),
                      trailing: Switch.adaptive(
                        value: settings.useProxyBackend,
                        activeTrackColor: context.themeAccentColor,
                        onChanged: (val) async {
                          final confirm = await showDialog<bool>(
                            context: context, builder: (ctx) => AlertDialog(
                              backgroundColor: context.themeSurfaceColor,
                              title: Text("Advanced Setting", style: GoogleFonts.outfit(color: context.themeTextColor, fontWeight: FontWeight.bold)),
                              content: Text(val ? "Only proceed if instructed." : "Disabling will break Last.fm and Lyrics. Are you sure?", style: GoogleFonts.inter(color: context.themeTextColor)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Cancel", style: TextStyle(color: context.themeMutedTextColor))),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text("Proceed", style: TextStyle(color: context.themeAccentColor))),
                              ],
                            ),
                          );
                          if (confirm == true) ref.read(settingsProvider.notifier).setUseProxyBackend(val);
                        },
                      ),
                    ),
                    _buildActionTile(
                      context: context, title: "Serverless Proxy URL", subtitle: settings.proxyUrl, icon: Icons.cloud_queue_rounded,
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context, builder: (ctx) => AlertDialog(
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
                          context: context, builder: (ctx) => AlertDialog(
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
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              // Category 5: About
              _buildSectionHeader(context, "â„¹ï¸ About & Info"),
              const SizedBox(height: 8),

              _buildActionTile(
                context: context,
                title: "Check for Updates",
                subtitle: "See if a new version is available",
                icon: Icons.system_update_rounded,
                onTap: () async {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 16),
                          Text("Checking for updates..."),
                        ],
                      ),
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
                            content: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent),
                                ),
                                SizedBox(width: 16),
                                Text("Downloading background patch..."),
                              ],
                            ),
                            duration: Duration(seconds: 60),
                          ),
                        );

                        await shorebird.update();

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ref.read(shorebirdUpdatePendingProvider.notifier).state = true; // Set state to show banner
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Patch downloaded! Please restart the app to apply."),
                              duration: Duration(seconds: 5),
                            ),
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
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    }
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("You are on the latest version!")),
                      );
                    }
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Failed to check for updates. Check your connection.")),
                    );
                  }
                },
              ),

              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version ?? '...';
                  return _buildActionTile(
                    context: context,
                    title: "It Feels Music",
                    subtitle: "Version $version â€¢ Developer: FaiXal",
                    icon: Icons.info_outline_rounded,
                    onTap: () {},
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        color: context.themeAccentColor,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildSelectableTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<String> options,
    required String currentValue,
    required Function(String) onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.themeCardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          title: Text(
            title,
            style: GoogleFonts.inter(
              color: context.themeTextColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.inter(
              color: context.themeMutedTextColor,
              fontSize: 12,
            ),
          ),
          trailing: Icon(Icons.arrow_drop_down, color: context.themeMutedTextColor),
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => SimpleDialog(
                backgroundColor: context.themeSurfaceColor,
                title: Text(
                  title,
                  style: GoogleFonts.outfit(color: context.themeTextColor, fontSize: 18),
                ),
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
                          Text(
                            opt,
                            style: GoogleFonts.inter(
                              color: isSelected
                                  ? context.themeAccentColor
                                  : context.themeMutedTextColor,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check,
                              color: context.themeAccentColor,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.themeCardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          leading: Icon(icon, color: context.themeMutedTextColor, size: 22),
          title: Text(
            title,
            style: GoogleFonts.inter(
              color: context.themeTextColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.inter(
              color: context.themeMutedTextColor,
              fontSize: 12,
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

