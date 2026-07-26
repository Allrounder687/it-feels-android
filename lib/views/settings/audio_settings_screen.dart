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

          _buildSectionHeader("🔊 Bass / Loudness Boost"),
          const SizedBox(height: 8),
          Text(
            "Hardware amplifier for a heavier punch. Careful, this can distort!",
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (isAndroid)
            SliderTheme(
              data: _sliderTheme(),
              child: Slider(
                value: audioProvider.loudnessEnhancer.targetGain,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                label: '${(audioProvider.loudnessEnhancer.targetGain * 100).toInt()}%',
                onChanged: (val) => audioProvider.setLoudnessGain(val),
              ),
            ),
          const SizedBox(height: 32),

          _buildSectionHeader("🎛️ Equalizer (EQ)"),
          const SizedBox(height: 8),
          Text(
            "Customize hardware frequency bands to match your headphones.",
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 24),
          if (isAndroid)
            FutureBuilder<AndroidEqualizerParameters>(
              future: audioProvider.equalizer.parameters,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const Text("Failed to load Equalizer from hardware", style: TextStyle(color: Colors.red));
                }

                final params = snapshot.data!;
                final maxGain = params.maxDecibels;
                final minGain = params.minDecibels;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: params.bands.asMap().entries.map((entry) {
                      final index = entry.key;
                      final band = entry.value;
                      final hz = (band.centerFrequency / 1000).toStringAsFixed(1);
                      final label = band.centerFrequency >= 1000 ? '${hz}k' : '${band.centerFrequency.toInt()}';

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Column(
                          children: [
                            Text(
                              "${band.gain > 0 ? '+' : ''}${band.gain.toStringAsFixed(1)}",
                              style: GoogleFonts.inter(color: AppColors.midnightPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 180,
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: SliderTheme(
                                  data: _sliderTheme(),
                                  child: Slider(
                                    value: band.gain,
                                    min: minGain,
                                    max: maxGain,
                                    onChanged: (val) => audioProvider.setEqBandGain(index, val),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              label,
                              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
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
