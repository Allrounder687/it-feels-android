import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/features/subscription/paywall_bottom_sheet.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/theme/app_dimensions.dart';

class AudioSettingsScreen extends ConsumerStatefulWidget {
  const AudioSettingsScreen({super.key});

  @override
  ConsumerState<AudioSettingsScreen> createState() => _AudioSettingsScreenState();
}

class _AudioSettingsScreenState extends ConsumerState<AudioSettingsScreen> {

  @override
  Widget build(BuildContext context) {
    final audioProvider = ref.watch(audioPlayerProvider);
    final isAndroid = Platform.isAndroid;

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
          "Pro Audio Settings",
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: context.themeTextColor,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.only(left: 20, top: 20, right: 20, bottom: AppDimensions.bottomClearance + MediaQuery.of(context).viewPadding.bottom),
        children: [
          // Platform Warning
          if (!isAndroid)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Equalizer and Bass Boost are only supported on Android hardware.",
                      style: GoogleFonts.inter(color: context.themeTextColor, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          _buildSectionHeader("âš¡ Speed & Pitch"),
          const SizedBox(height: 8),
          Text(
            "Slow down for vibes, or pitch shift for karaoke.",
            style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Speed: ${audioProvider.playbackSpeed.toStringAsFixed(2)}x", style: GoogleFonts.inter(color: context.themeTextColor)),
                    SliderTheme(
                      data: _sliderTheme(),
                      child: Slider(
                        value: audioProvider.playbackSpeed,
                        min: 0.5,
                        max: 2.0,
                        divisions: 15,
                        onChanged: (val) => ref.read(audioPlayerProvider.notifier).setPlaybackSpeed(val),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Pitch: ${audioProvider.playbackPitch.toStringAsFixed(2)}x", style: GoogleFonts.inter(color: context.themeTextColor)),
                    SliderTheme(
                      data: _sliderTheme(),
                      child: Slider(
                        value: audioProvider.playbackPitch,
                        min: 0.5,
                        max: 2.0,
                        divisions: 15,
                        onChanged: (val) => ref.read(audioPlayerProvider.notifier).setPlaybackPitch(val),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: context.themeCardColor),
                onPressed: () {
                  ref.read(audioPlayerProvider.notifier).setPlaybackSpeed(1.0);
                  ref.read(audioPlayerProvider.notifier).setPlaybackPitch(1.0);
                },
                child: const Text("Reset Speed/Pitch"),
              ),
            ],
          ),
          const SizedBox(height: 32),

          _buildSectionHeader("ðŸŽ›ï¸ It Feels DSP Engine"),
          const SizedBox(height: 8),
          Text(
            "Our custom-tuned Digital Signal Processor. Enables a premium, punchy EQ and hardware loudness boost for an audiophile experience.",
            style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (isAndroid)
            SwitchListTile(
              title: Text("Enable DSP Engine", style: GoogleFonts.inter(color: context.themeTextColor)),
              value: audioProvider.isDspEngineEnabled,
              onChanged: (val) {
                if (val) {
                  final sub = ref.read(subscriptionProvider);
                  if (!sub.isPremium) {
                    PaywallBottomSheet.show(context, featureName: "DSP Engine");
                    return;
                  }
                }
                ref.read(audioPlayerProvider.notifier).setDspEngine(val);
              },
              activeThumbColor: context.themeAccentColor,
              tileColor: context.themeTextColor.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          const SizedBox(height: 32),

          _buildSectionHeader("ðŸ“³ Haptic Feedback"),
          const SizedBox(height: 8),
          Text(
            "Premium physical responses to your interactions.",
            style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text("UI Haptics", style: GoogleFonts.inter(color: context.themeTextColor)),
            subtitle: Text("Subtle vibrations on Play/Pause, Skip, etc.", style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12)),
            value: audioProvider.uiHapticsEnabled,
            onChanged: (val) => ref.read(audioPlayerProvider.notifier).setUiHaptics(val),
            activeThumbColor: context.themeAccentColor,
            tileColor: context.themeTextColor.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text("Audio-Sync Haptics (Experimental)", style: GoogleFonts.inter(color: context.themeTextColor)),
            subtitle: Text("Simulates beat drops. Warning: May cause battery drain.", style: GoogleFonts.inter(color: Colors.orangeAccent, fontSize: 12)),
            value: audioProvider.audioSyncHapticsEnabled,
            onChanged: (val) => ref.read(audioPlayerProvider.notifier).setAudioSyncHaptics(val),
            activeThumbColor: context.themeAccentColor,
            tileColor: context.themeTextColor.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader("ðŸŽšï¸ Crossfade"),
          const SizedBox(height: 8),
          Text(
            "Smoothly fade one song into the next for gapless playback.",
            style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text("0s", style: GoogleFonts.inter(color: context.themeMutedTextColor, fontWeight: FontWeight.w600)),
              Expanded(
                child: SliderTheme(
                  data: _sliderTheme(),
                  child: Slider(
                    value: audioProvider.crossfadeDuration,
                    min: 0,
                    max: 12,
                    divisions: 12,
                    label: '${audioProvider.crossfadeDuration.toInt()}s',
                    onChanged: (val) {
                      ref.read(audioPlayerProvider.notifier).setCrossfadeDuration(val);
                    },
                  ),
                ),
              ),
              Text("12s", style: GoogleFonts.inter(color: context.themeMutedTextColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  SliderThemeData _sliderTheme() {
    return SliderThemeData(
      activeTrackColor: AppColors.midnightAccent,
      inactiveTrackColor: context.themeTextColor10,
      thumbColor: context.themeAccentColor,
      overlayColor: AppColors.midnightAccent.withValues(alpha: 0.2),
      trackHeight: 4.0,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        color: context.themeAccentColor,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

