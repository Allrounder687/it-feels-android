import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                title: "Wi-Fi Streaming Quality",
                subtitle: settings.wifiQuality,
                options: ["320 kbps (Very High)", "160 kbps (High)", "96 kbps (Medium)", "64 kbps (Low)"],
                currentValue: settings.wifiQuality,
                onSelected: (val) => settings.setWifiQuality(val),
              ),
              _buildSelectableTile(
                title: "Mobile Data Streaming Quality",
                subtitle: settings.mobileQuality,
                options: ["320 kbps (Very High)", "160 kbps (High)", "96 kbps (Medium)", "64 kbps (Low)"],
                currentValue: settings.mobileQuality,
                onSelected: (val) => settings.setMobileQuality(val),
              ),
              _buildSelectableTile(
                title: "Download Quality",
                subtitle: settings.downloadQuality,
                options: ["320 kbps (Very High)", "160 kbps (High)", "96 kbps (Medium)"],
                currentValue: settings.downloadQuality,
                onSelected: (val) => settings.setDownloadQuality(val),
              ),

              const SizedBox(height: 24),

              // Category 2: Storage & Downloads
              _buildSectionHeader("💾 Storage & Downloads"),
              const SizedBox(height: 8),

              _buildActionTile(
                title: "Download Storage Location",
                subtitle: "Internal Storage (/downloaded_music)",
                icon: Icons.folder_special_rounded,
                onTap: () {},
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
                title: "App Primary Theme",
                subtitle: settings.theme,
                options: ["Midnight Dark", "Burgundy Dark"],
                currentValue: settings.theme,
                onSelected: (val) => settings.setTheme(val),
              ),

              const SizedBox(height: 24),

              // Category 4: About
              _buildSectionHeader("ℹ️ About & Info"),
              const SizedBox(height: 8),

              _buildActionTile(
                title: "PixelPlayer Saavn Edition",
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
          // Show Options Dialog
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
