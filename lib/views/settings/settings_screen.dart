import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/settings_provider.dart';
import 'hidden_songs_screen.dart';
import 'audio_settings_screen.dart';
import 'package:file_picker/file_picker.dart';

import 'ai_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final downloadProvider = Provider.of<DownloadProvider>(context);

    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return Scaffold(
          backgroundColor: AppColors.midnightBackground,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              "Settings",
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // Category 1: Audio & Streaming Quality
              _buildSectionHeader("🎵 Audio & Streaming Quality"),
              const SizedBox(height: 8),

              _buildSelectableTile(
                context: context,
                title: "Wi-Fi Streaming Quality",
                subtitle: settings.wifiQuality,
                options: ["320 kbps (Very High)", "160 kbps (High)", "96 kbps (Medium)", "64 kbps (Low)"],
                currentValue: settings.wifiQuality,
                onSelected: (val) => settings.setWifiQuality(val),
              ),
              _buildSelectableTile(
                context: context,
                title: "Mobile Data Streaming Quality",
                subtitle: settings.mobileQuality,
                options: ["320 kbps (Very High)", "160 kbps (High)", "96 kbps (Medium)", "64 kbps (Low)"],
                currentValue: settings.mobileQuality,
                onSelected: (val) => settings.setMobileQuality(val),
              ),
              _buildSelectableTile(
                context: context,
                title: "Download Quality",
                subtitle: settings.downloadQuality,
                options: ["320 kbps (Very High)", "160 kbps (High)", "96 kbps (Medium)"],
                currentValue: settings.downloadQuality,
                onSelected: (val) => settings.setDownloadQuality(val),
              ),

              _buildActionTile(
                title: "Pro Audio Settings",
                subtitle: "Crossfade, Equalizer, and Audio Effects",
                icon: Icons.graphic_eq_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AudioSettingsScreen()),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Category 2: Privacy & Preferences
              _buildSectionHeader("🛡️ Privacy & Preferences"),
              const SizedBox(height: 8),

              _buildSelectableTile(
                context: context,
                title: "Default Startup Category",
                subtitle: settings.defaultCategory,
                options: ["YOU", "Moods", "Charts", "Bollywood", "Telugu", "Tamil", "Punjabi", "Hollywood", "Trending", "Playlists", "Albums"],
                currentValue: settings.defaultCategory,
                onSelected: (val) => settings.setDefaultCategory(val),
              ),

              _buildActionTile(
                title: "Manage Hidden Songs",
                subtitle: "View and unhide songs you've removed from your feed",
                icon: Icons.visibility_off_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HiddenSongsScreen()),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Category 3: Storage & Downloads
              _buildSectionHeader("💾 Storage & Downloads"),
              const SizedBox(height: 8),

              _buildActionTile(
                title: "Download Storage Location",
                subtitle: settings.customDownloadPath.isEmpty ? "Internal App Storage" : settings.customDownloadPath,
                icon: Icons.folder_special_rounded,
                onTap: () async {
                  String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
                  if (selectedDirectory != null) {
                    settings.setCustomDownloadPath(selectedDirectory);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Location updated to: $selectedDirectory")),
                      );
                    }
                  }
                },
              ),
              _buildActionTile(
                title: "Clear All Downloads",
                subtitle: "${downloadProvider.downloadedSongs.length} tracks downloaded",
                icon: Icons.delete_outline_rounded,
                onTap: () async {
                  if (downloadProvider.downloadedSongs.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("No downloaded tracks to delete")),
                    );
                    return;
                  }
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.midnightSurface,
                      title: Text("Clear Downloads", style: GoogleFonts.outfit(color: Colors.white)),
                      content: Text(
                        "Are you sure you want to delete all offline downloaded songs?",
                        style: GoogleFonts.inter(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
                          onPressed: () => Navigator.pop(ctx, false),
                        ),
                        TextButton(
                          child: const Text("Delete All", style: TextStyle(color: Colors.redAccent)),
                          onPressed: () => Navigator.pop(ctx, true),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await downloadProvider.clearAllDownloads();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("All downloads cleared")),
                      );
                    }
                  }
                },
              ),
              _buildActionTile(
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

              // Category 3: Appearance & Themes
              _buildSectionHeader("🎨 Appearance & Themes"),
              const SizedBox(height: 8),

              _buildSelectableTile(
                context: context,
                title: "App Primary Theme",
                subtitle: settings.theme,
                options: ["System (Material You)", "Dynamic (Album Art)", "Midnight Dark", "Burgundy Dark", "AMOLED Black"],
                currentValue: settings.theme,
                onSelected: (val) {
                  settings.setTheme(val);
                  final player = Provider.of<AudioPlayerProvider>(context, listen: false);
                  if (val == "System (Material You)") {
                    player.setAppThemeMode(AppThemeMode.materialYou);
                  } else if (val == "Midnight Dark") {
                    player.setAppThemeMode(AppThemeMode.midnight);
                  } else if (val == "Burgundy Dark") {
                    player.setAppThemeMode(AppThemeMode.burgundy);
                  } else if (val == "AMOLED Black") {
                    player.setAppThemeMode(AppThemeMode.amoled);
                  } else {
                    player.setAppThemeMode(AppThemeMode.dynamic);
                  }
                },
              ),

              const SizedBox(height: 24),

              // Category: AI Features
              _buildSectionHeader("✨ AI Features"),
              const SizedBox(height: 8),
              _buildActionTile(
                title: "AI Settings",
                subtitle: "Configure AI-powered playlist generation and mood matching",
                icon: Icons.auto_awesome_rounded,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AISettingsScreen())),
              ),

              const SizedBox(height: 24),

              // Category 3.5: Advanced Android Integrations
              _buildSectionHeader("🤖 Advanced Android Integrations"),
              const SizedBox(height: 8),

              SwitchListTile(
                title: Text("Android Auto Integration", style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                subtitle: Text("Sync your playlists and history with your car dashboard", style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                value: settings.enableAndroidAuto,
                activeColor: AppColors.midnightPrimary,
                onChanged: (val) async {
                  if (val) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.midnightSurface,
                        title: Text("Enable Android Auto", style: GoogleFonts.outfit(color: Colors.white)),
                        content: Text(
                          "This will expose your playlists and listening history to the car's OS. Are you sure you wish to proceed?",
                          style: GoogleFonts.inter(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
                            onPressed: () => Navigator.pop(ctx, false),
                          ),
                          TextButton(
                            child: const Text("Proceed", style: TextStyle(color: AppColors.midnightPrimary)),
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
                      const SnackBar(content: Text("Warning: Real-time Audio Sync Haptics may cause battery drain.")),
                    );
                  }
                },
              ),

              const SizedBox(height: 24),

              // Category 4: Privacy & Content
              _buildSectionHeader("🔒 Privacy & Content"),
              const SizedBox(height: 8),

              _buildActionTile(
                title: "Hidden Songs",
                subtitle: "Manage tracks you've hidden",
                icon: Icons.visibility_off_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HiddenSongsScreen()),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Category 5: About
              _buildSectionHeader("ℹ️ About & Info"),
              const SizedBox(height: 8),

              _buildActionTile(
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        color: AppColors.midnightPrimary,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.midnightCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        title: Text(
          title,
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(color: AppColors.midnightTextMuted, fontSize: 12),
        ),
        trailing: const Icon(Icons.arrow_drop_down, color: Colors.white54),
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => SimpleDialog(
              backgroundColor: AppColors.midnightSurface,
              title: Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 18)),
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
                            color: isSelected ? AppColors.midnightPrimary : Colors.white70,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check, color: AppColors.midnightPrimary, size: 18),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.midnightCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white70, size: 22),
        title: Text(
          title,
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(color: AppColors.midnightTextMuted, fontSize: 12),
        ),
        onTap: onTap,
      ),
    );
  }
}
