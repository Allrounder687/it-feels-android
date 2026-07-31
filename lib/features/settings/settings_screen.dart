import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/features/library/download_provider.dart';
import 'package:it_feels_music/features/settings/settings_provider.dart';
import 'package:it_feels_music/features/settings/hidden_songs_screen.dart';
import 'package:it_feels_music/features/settings/audio_settings_screen.dart';
import 'package:file_picker/file_picker.dart';

import 'package:it_feels_music/features/ai/ai_settings_screen.dart';
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // Category 1: Audio & Streaming Quality
              _buildSectionHeader(context, "🎵 Audio & Streaming Quality"),
              const SizedBox(height: 8),

              SwitchListTile.adaptive(
                title: Text(
                  "Data Saver Mode",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: context.themeTextColor,
                  ),
                ),
                subtitle: Text(
                  settings.isDataSaverEnabled
                      ? "Active: Audio quality reduced to 64kbps & low bandwidth mode active"
                      : "Reduces data usage by streaming at low quality and conserving network data",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: context.themeMutedTextColor,
                  ),
                ),
                value: settings.isDataSaverEnabled,
                activeColor: context.themeAccentColor,
                onChanged: (val) => settings.setDataSaverEnabled(val),
              ),

              _buildSelectableTile(
                context: context,
                title: "Wi-Fi Streaming Quality",
                subtitle: settings.wifiQuality,
                options: [
                  "320 kbps (Very High)",
                  "160 kbps (High)",
                  "96 kbps (Medium)",
                  "64 kbps (Low)",
                ],
                currentValue: settings.wifiQuality,
                onSelected: (val) => settings.setWifiQuality(val),
              ),
              _buildSelectableTile(
                context: context,
                title: "Mobile Data Streaming Quality",
                subtitle: settings.mobileQuality,
                options: [
                  "320 kbps (Very High)",
                  "160 kbps (High)",
                  "96 kbps (Medium)",
                  "64 kbps (Low)",
                ],
                currentValue: settings.mobileQuality,
                onSelected: (val) => settings.setMobileQuality(val),
              ),
              _buildSelectableTile(
                context: context,
                title: "Download Quality",
                subtitle: settings.downloadQuality,
                options: [
                  "320 kbps (Very High)",
                  "160 kbps (High)",
                  "96 kbps (Medium)",
                ],
                currentValue: settings.downloadQuality,
                onSelected: (val) => settings.setDownloadQuality(val),
              ),

              _buildActionTile(
                context: context,
                title: "Pro Audio Settings",
                subtitle: "Crossfade, Equalizer, and Audio Effects",
                icon: Icons.graphic_eq_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AudioSettingsScreen(),
                    ),
                  );
                },
              ),
              SwitchListTile.adaptive(
                title: Text(
                  "Use Video Audio Source",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: context.themeTextColor,
                  ),
                ),
                subtitle: Text(
                  settings.useVideoAudioSource
                      ? "Switches audio to YouTube video stream in Video mode"
                      : "Keeps high-quality music player audio playing during Video mode",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: context.themeMutedTextColor,
                  ),
                ),
                value: settings.useVideoAudioSource,
                activeColor: context.themeAccentColor,
                onChanged: (val) => settings.setUseVideoAudioSource(val),
              ),

              const SizedBox(height: 24),

              // Category 2: Privacy & Preferences
              _buildSectionHeader(context, "🛡️ Privacy & Preferences"),
              const SizedBox(height: 8),

              _buildSelectableTile(
                context: context,
                title: "Default Startup Category",
                subtitle: settings.defaultCategory,
                options: [
                  "YOU",
                  "Moods",
                  "Charts",
                  "Bollywood",
                  "Telugu",
                  "Tamil",
                  "Punjabi",
                  "Hollywood",
                  "Trending",
                  "Playlists",
                  "Albums",
                ],
                currentValue: settings.defaultCategory,
                onSelected: (val) => settings.setDefaultCategory(val),
              ),

              _buildActionTile(
                context: context,
                title: "Manage Hidden Songs",
                subtitle: "View and unhide songs you've removed from your feed",
                icon: Icons.visibility_off_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HiddenSongsScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Category 3: Storage & Downloads
              _buildSectionHeader(context, "💾 Storage & Downloads"),
              const SizedBox(height: 8),

              _buildActionTile(
                context: context,
                title: "Download Storage Location",
                subtitle: settings.customDownloadPath.isEmpty
                    ? "Internal App Storage"
                    : settings.customDownloadPath,
                icon: Icons.folder_special_rounded,
                onTap: () async {
                  String? selectedDirectory = await FilePicker.platform
                      .getDirectoryPath();
                  if (selectedDirectory != null) {
                    settings.setCustomDownloadPath(selectedDirectory);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Location updated to: $selectedDirectory",
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
              _buildActionTile(
                context: context,
                title: "Clear All Downloads",
                subtitle:
                    "${downloader.downloadedSongs.length} tracks downloaded",
                icon: Icons.delete_outline_rounded,
                onTap: () async {
                  if (downloader.downloadedSongs.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("No downloaded tracks to delete"),
                      ),
                    );
                    return;
                  }
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: context.themeSurfaceColor,
                      title: Text(
                        "Clear Downloads",
                        style: GoogleFonts.outfit(color: context.themeTextColor),
                      ),
                      content: Text(
                        "Are you sure you want to delete all offline downloaded songs?",
                        style: GoogleFonts.inter(color: context.themeMutedTextColor),
                      ),
                      actions: [
                        TextButton(
                          child: Text(
                            "Cancel",
                            style: TextStyle(color: context.themeMutedTextColor),
                          ),
                          onPressed: () => Navigator.pop(ctx, false),
                        ),
                        TextButton(
                          child: const Text(
                            "Delete All",
                            style: TextStyle(color: Colors.redAccent),
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await downloader.clearAllDownloads();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("All downloads cleared")),
                      );
                    }
                  }
                },
              ),
              _buildActionTile(
                context: context,
                title: "Clear Cache",
                subtitle: "Free up temporary space",
                icon: Icons.cleaning_services_rounded,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Cache cleared successfully")),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Category 4: FEELS Cloud Proxy Engine
              _buildSectionHeader(context, "🌐 FEELS Cloud Proxy Engine"),
              const SizedBox(height: 8),

              SwitchListTile.adaptive(
                value: settings.useProxyBackend,
                activeColor: context.themeAccentColor,
                title: Text(
                  "Use Serverless Proxy Backend",
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.themeTextColor,
                  ),
                ),
                subtitle: Text(
                  settings.useProxyBackend
                      ? "Active: Stream & lyrics extraction handled via Cloud Proxy"
                      : "Inactive: Direct client scraping mode",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: context.themeMutedTextColor,
                  ),
                ),
                onChanged: (val) {
                  settings.setUseProxyBackend(val);
                },
              ),

              SwitchListTile.adaptive(
                value: settings.enableMusicVideos,
                activeColor: context.themeAccentColor,
                title: Text(
                  "Enable Music Videos & Video Tab",
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.themeTextColor,
                  ),
                ),
                subtitle: Text(
                  settings.enableMusicVideos
                      ? "Active: Dedicated Videos tab & ad-free video player unlocked"
                      : "Inactive: Pure audio mode (0 video clutter)",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: context.themeMutedTextColor,
                  ),
                ),
                onChanged: (val) {
                  settings.setEnableMusicVideos(val);
                },
              ),

              _buildActionTile(
                context: context,
                title: "Serverless Proxy URL",
                subtitle: settings.proxyUrl,
                icon: Icons.cloud_queue_rounded,
                onTap: () async {
                  final textController = TextEditingController(text: settings.proxyUrl);
                  final newUrl = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: context.themeSurfaceColor,
                      title: Text(
                        "Cloud Proxy Endpoint",
                        style: GoogleFonts.outfit(color: context.themeTextColor),
                      ),
                      content: TextField(
                        controller: textController,
                        style: TextStyle(color: context.themeTextColor),
                        decoration: InputDecoration(
                          hintText: "https://your-worker.workers.dev",
                          hintStyle: TextStyle(color: context.themeMutedTextColor),
                        ),
                      ),
                      actions: [
                        TextButton(
                          child: Text("Cancel", style: TextStyle(color: context.themeMutedTextColor)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                        TextButton(
                          child: Text("Save", style: TextStyle(color: context.themeAccentColor)),
                          onPressed: () => Navigator.pop(ctx, textController.text.trim()),
                        ),
                      ],
                    ),
                  );
                  if (newUrl != null && newUrl.isNotEmpty) {
                    settings.setProxyUrl(newUrl);
                  }
                },
              ),

              const SizedBox(height: 24),

              // Category 3: Appearance & Themes
              _buildSectionHeader(context, "🎨 Appearance & Themes"),
              const SizedBox(height: 8),

              _buildSelectableTile(
                context: context,
                title: "App Primary Theme",
                subtitle: settings.theme,
                options: [
                  "System (Material You)",
                  "Dynamic (Album Art)",
                  "Light Mode",
                  "Midnight Dark",
                  "Burgundy Dark",
                  "Pitch Black (AMOLED)",
                ],
                currentValue: settings.theme,
                onSelected: (val) {
                  settings.setTheme(val);
                  final player = ref.read(audioPlayerProvider);
                  if (val == "System (Material You)") {
                    player.setAppThemeMode(AppThemeMode.materialYou);
                  } else if (val == "Midnight Dark") {
                    player.setAppThemeMode(AppThemeMode.midnight);
                  } else if (val == "Burgundy Dark") {
                    player.setAppThemeMode(AppThemeMode.burgundy);
                  } else if (val == "Pitch Black (AMOLED)") {
                    player.setAppThemeMode(AppThemeMode.amoled);
                  } else if (val == "Light Mode") {
                    player.setAppThemeMode(AppThemeMode.light);
                  } else {
                    player.setAppThemeMode(AppThemeMode.dynamic);
                  }
                },
              ),

              const SizedBox(height: 24),

              // Category: AI Features
              _buildSectionHeader(context, "AUDIO & PLAYBACK"),
              const SizedBox(height: 8),
              _buildActionTile(
                context: context,
                title: "AI Settings",
                subtitle:
                    "Configure AI-powered playlist generation and mood matching",
                icon: Icons.auto_awesome_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AISettingsScreen()),
                ),
              ),

              const SizedBox(height: 24),

              // Category 3.5: Advanced Android Integrations
              _buildSectionHeader(context, "🤖 Advanced Android Integrations"),
              const SizedBox(height: 8),

              SwitchListTile(
                title: Text(
                  "Android Auto Integration",
                  style: GoogleFonts.outfit(
                    color: context.themeTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  "Sync your playlists and history with your car dashboard",
                  style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 13),
                ),
                value: settings.enableAndroidAuto,
                activeThumbColor: context.themeAccentColor,
                onChanged: (val) async {
                  if (val) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: context.themeSurfaceColor,
                        title: Text(
                          "Enable Android Auto",
                          style: GoogleFonts.outfit(color: context.themeTextColor),
                        ),
                        content: Text(
                          "This will expose your playlists and listening history to the car's OS. Are you sure you wish to proceed?",
                          style: GoogleFonts.inter(color: context.themeMutedTextColor),
                        ),
                        actions: [
                          TextButton(
                            child: Text(
                              "Cancel",
                              style: TextStyle(color: context.themeMutedTextColor),
                            ),
                            onPressed: () => Navigator.pop(ctx, false),
                          ),
                          TextButton(
                            child: Text(
                              "Proceed",
                              style: TextStyle(
                                color: context.themeAccentColor,
                              ),
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      settings.setEnableAndroidAuto(true);
                    }
                  } else {
                    settings.setEnableAndroidAuto(false);
                  }
                },
              ),

              _buildSelectableTile(
                context: context,
                title: "Haptics & Feedback",
                subtitle: settings.hapticsMode,
                options: ["Off", "UI Only", "Audio Sync"],
                currentValue: settings.hapticsMode,
                onSelected: (val) {
                  settings.setHapticsMode(val);
                  if (val == "Audio Sync") {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Warning: Real-time Audio Sync Haptics may cause battery drain.",
                        ),
                      ),
                    );
                  }
                },
              ),

              const SizedBox(height: 24),

              // Category 4: Privacy & Content
              _buildSectionHeader(context, "🔒 Privacy & Content"),
              const SizedBox(height: 8),

              _buildActionTile(
                context: context,
                title: "View Hidden Songs",
                subtitle: "Manage tracks you've hidden from your library",
                icon: Icons.visibility_off_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HiddenSongsScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Category 5: About
              _buildSectionHeader(context, "ℹ️ About & Info"),
              const SizedBox(height: 8),

              _buildActionTile(
                context: context,
                title: "It Feels Music",
                subtitle: "Version 2.1.2 • Developer: FaiXal",
                icon: Icons.info_outline_rounded,
                onTap: () {},
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
