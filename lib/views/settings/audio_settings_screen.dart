import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/audio_player_provider.dart';

class AudioSettingsScreen extends StatefulWidget {
  const AudioSettingsScreen({super.key});

  @override
  State<AudioSettingsScreen> createState() => _AudioSettingsScreenState();
}

class _AudioSettingsScreenState extends State<AudioSettingsScreen> {
  double _crossfadeDuration = 0;

  @override
  Widget build(BuildContext context) {
    final audioProvider = Provider.of<AudioPlayerProvider>(context);
    final isAndroid = Platform.isAndroid;

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
          "Pro Audio Settings",
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Platform Warning
          if (!isAndroid)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Equalizer and Bass Boost are only supported on Android hardware.",
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          _buildSectionHeader("⚡ Speed & Pitch"),
          const SizedBox(height: 8),
          Text(
            "Slow down for vibes, or pitch shift for karaoke.",
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Speed: ${audioProvider.playbackSpeed.toStringAsFixed(2)}x", style: GoogleFonts.inter(color: Colors.white)),
                    SliderTheme(
                      data: _sliderTheme(),
                      child: Slider(
                        value: audioProvider.playbackSpeed,
                        min: 0.5,
                        max: 2.0,
                        divisions: 15,
                        onChanged: (val) => audioProvider.setPlaybackSpeed(val),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Pitch: ${audioProvider.playbackPitch.toStringAsFixed(2)}x", style: GoogleFonts.inter(color: Colors.white)),
                    SliderTheme(
                      data: _sliderTheme(),
                      child: Slider(
                        value: audioProvider.playbackPitch,
                        min: 0.5,
                        max: 2.0,
                        divisions: 15,
                        onChanged: (val) => audioProvider.setPlaybackPitch(val),
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
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.midnightCard),
                onPressed: () {
                  audioProvider.setPlaybackSpeed(1.0);
                  audioProvider.setPlaybackPitch(1.0);
                },
                child: const Text("Reset Speed/Pitch"),
              ),
            ],
          ),
          const SizedBox(height: 32),

          _buildSectionHeader("🎛️ It Feels DSP Engine"),
          const SizedBox(height: 8),
          Text(
            "Our custom-tuned Digital Signal Processor. Enables a premium, punchy EQ and hardware loudness boost for an audiophile experience.",
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (isAndroid)
            SwitchListTile(
              title: Text("Enable DSP Engine", style: GoogleFonts.inter(color: Colors.white)),
              value: audioProvider.isDspEngineEnabled,
              onChanged: (val) => audioProvider.setDspEngine(val),
              activeColor: AppColors.midnightPrimary,
              tileColor: Colors.white.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          const SizedBox(height: 32),

          _buildSectionHeader("📳 Haptic Feedback"),
          const SizedBox(height: 8),
          Text(
            "Premium physical responses to your interactions.",
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text("UI Haptics", style: GoogleFonts.inter(color: Colors.white)),
            subtitle: Text("Subtle vibrations on Play/Pause, Skip, etc.", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
            value: audioProvider.uiHapticsEnabled,
            onChanged: (val) => audioProvider.setUiHaptics(val),
            activeColor: AppColors.midnightPrimary,
            tileColor: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text("Audio-Sync Haptics (Experimental)", style: GoogleFonts.inter(color: Colors.white)),
            subtitle: Text("Simulates beat drops. Warning: May cause battery drain.", style: GoogleFonts.inter(color: Colors.orangeAccent, fontSize: 12)),
            value: audioProvider.audioSyncHapticsEnabled,
            onChanged: (val) => audioProvider.setAudioSyncHaptics(val),
            activeColor: AppColors.midnightPrimary,
            tileColor: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader("🎚️ Crossfade"),
          const SizedBox(height: 8),
          Text(
            "Smoothly fade one song into the next for gapless playback.",
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text("0s", style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.w600)),
              Expanded(
                child: SliderTheme(
                  data: _sliderTheme(),
                  child: Slider(
                    value: _crossfadeDuration,
                    min: 0,
                    max: 12,
                    divisions: 12,
                    label: '${_crossfadeDuration.toInt()}s',
                    onChanged: (val) {
                      setState(() {
                        _crossfadeDuration = val;
                      });
                    },
                  ),
                ),
              ),
              Text("12s", style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  SliderThemeData _sliderTheme() {
    return SliderThemeData(
      activeTrackColor: AppColors.midnightAccent,
      inactiveTrackColor: Colors.white10,
      thumbColor: AppColors.midnightPrimary,
      overlayColor: AppColors.midnightAccent.withOpacity(0.2),
      trackHeight: 4.0,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        color: AppColors.midnightPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
