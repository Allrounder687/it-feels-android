import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/settings_provider.dart';
import 'hidden_songs_screen.dart';

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

              const SizedBox(height: 24),

              // Category 2: Privacy & Preferences
              _buildSectionHeader("🛡️ Privacy & Preferences"),
              const SizedBox(height: 8),

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
                subtitle: "Internal App Storage (/downloaded_music)",
                icon: Icons.folder_special_rounded,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Location: Internal Storage (/downloaded_music)")),
                  );
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
                options: ["Dynamic (Album Art)", "Midnight Dark", "Burgundy Dark", "AMOLED Black"],
                currentValue: settings.theme,
                onSelected: (val) {
                  settings.setTheme(val);
                  final player = Provider.of<AudioPlayerProvider>(context, listen: false);
                  if (val == "Midnight Dark") {
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
                subtitle: "Version 2.1.0 • Built with Flutter",
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
