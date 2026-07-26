import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/ai_settings_provider.dart';

class AISettingsScreen extends StatelessWidget {
  const AISettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AISettingsProvider>(
      builder: (context, aiSettings, _) {
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
              "AI Settings",
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
              // AI Enabled toggle
              _buildSectionHeader("🤖 AI Features"),
              const SizedBox(height: 8),
              _buildSwitchTile(
                title: "Enable AI",
                subtitle: "Use AI to generate playlists, rename and describe them.",
                value: aiSettings.aiEnabled,
                onChanged: (v) => aiSettings.setAIEnabled(v),
              ),

              if (aiSettings.aiEnabled) ...[
                const SizedBox(height: 24),
                _buildSectionHeader("🔌 Provider"),
                const SizedBox(height: 8),
                ...aiSettings.providerOptions.map((opt) {
                  return _buildRadioTile(
                    title: opt['name']!,
                    value: opt['id']!,
                    groupValue: aiSettings.selectedProviderId,
                    onChanged: (v) => aiSettings.setSelectedProvider(v),
                  );
                }),
                const SizedBox(height: 16),
                _buildActionTile(
                  title: "Reset Provider",
                  subtitle: "Go back to Auto selection.",
                  icon: Icons.refresh_rounded,
                  onTap: () => aiSettings.resetProvider(),
                ),

                const SizedBox(height: 24),
                _buildSectionHeader("🔑 Advanced"),
                const SizedBox(height: 8),
                _buildInfoTile(
                  "API keys are only needed for real providers (ChatGPT, Gemini, Claude). "
                  "They are stored locally on your device and never sent to us.",
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.midnightPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildRadioTile({
    required String title,
    required String value,
    required String groupValue,
    required ValueChanged<String> onChanged,
  }) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.midnightPrimary.withOpacity(0.12) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: selected ? Border.all(color: AppColors.midnightPrimary.withOpacity(0.5), width: 1) : null,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.midnightPrimary : Colors.white38,
              size: 22,
            ),
            const SizedBox(width: 14),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 16,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white54, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.white38, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
