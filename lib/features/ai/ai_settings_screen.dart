import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

class AISettingsScreen extends ConsumerWidget {
  const AISettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Consumer(builder: (context, ref, _) { final aiSettings = ref.watch(aiSettingsProvider); 
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
              "AI Settings",
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
              // AI Enabled toggle
              _buildSectionHeader(context, "🤖 AI Features"),
              const SizedBox(height: 8),
              _buildSwitchTile(
                context: context,
                title: "Enable Ask Feels AI",
                subtitle: "Use AI to generate playlists, rename and describe them.",
                value: aiSettings.aiEnabled,
                onChanged: (v) => ref.read(aiSettingsProvider.notifier).setAIEnabled(v),
              ),

              if (aiSettings.aiEnabled) ...[
                const SizedBox(height: 24),
                _buildSectionHeader(context, "AI PROVIDER"),
                const SizedBox(height: 8),
                ...aiSettings.providerOptions.map((opt) {
                  return _buildRadioTile(
                    context,
                    title: opt['name']!,
                    value: opt['id']!,
                    groupValue: aiSettings.selectedProviderId,
                    onChanged: (v) => ref.read(aiSettingsProvider.notifier).setSelectedProvider(v),
                  );
                }),
                const SizedBox(height: 16),
                _buildActionTile(
                  context,
                  title: "Reset Provider",
                  subtitle: "Go back to Auto selection.",
                  icon: Icons.refresh_rounded,
                  onTap: () => ref.read(aiSettingsProvider.notifier).resetProvider(),
                ),

                const SizedBox(height: 24),
                _buildSectionHeader(context, "GENERAL"),
                const SizedBox(height: 8),
                _buildInfoTile(context, "By activating a custom API key, you gain direct access to the most advanced AI features for personalized music discovery, completely bypassing the default limited Mock AI."),
                const SizedBox(height: 16),
                _buildApiKeyField(
                  context: context,
                  label: "Gemini API Key",
                  hint: "AIzaSy...",
                  value: aiSettings.geminiKey,
                  onChanged: (v) => ref.read(aiSettingsProvider.notifier).setGeminiKey(v),
                ),
                const SizedBox(height: 12),
                _buildApiKeyField(
                  context: context,
                  label: "OpenAI API Key",
                  hint: "sk-...",
                  value: aiSettings.openaiKey,
                  onChanged: (v) => ref.read(aiSettingsProvider.notifier).setOpenaiKey(v),
                ),
                const SizedBox(height: 12),
                _buildApiKeyField(
                  context: context,
                  label: "Anthropic API Key",
                  hint: "sk-ant-...",
                  value: aiSettings.anthropicKey,
                  onChanged: (v) => ref.read(aiSettingsProvider.notifier).setAnthropicKey(v),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildApiKeyField({
    required BuildContext context,
    required String label,
    required String hint,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.themeTextColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              color: context.themeMutedTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: TextEditingController(text: value)..selection = TextSelection.fromPosition(TextPosition(offset: value.length)),
            style: GoogleFonts.outfit(color: context.themeTextColor, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.outfit(color: context.themeTextColor24),
              isDense: true,
              border: InputBorder.none,
            ),
            obscureText: true,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: context.themeMutedTextColor,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.themeTextColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(color: context.themeTextColor, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.outfit(color: context.themeMutedTextColor, fontSize: 13)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: context.themeAccentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildRadioTile(BuildContext context, {
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
          color: selected ? context.themeAccentColor.withValues(alpha: 0.12) : context.themeTextColor.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: selected ? Border.all(color: context.themeAccentColor.withValues(alpha: 0.5), width: 1) : null,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? context.themeAccentColor : context.themeMutedTextColor,
              size: 22,
            ),
            const SizedBox(width: 14),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: selected ? context.themeTextColor : context.themeMutedTextColor,
                fontSize: 16,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(BuildContext context, {
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
          color: context.themeTextColor.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: context.themeMutedTextColor, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(color: context.themeTextColor, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.outfit(color: context.themeMutedTextColor, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.themeTextColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: context.themeMutedTextColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(color: context.themeMutedTextColor, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

