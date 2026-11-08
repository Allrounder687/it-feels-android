import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/services/audio_engine_service.dart';
import 'package:it_feels_music/data/services/equalizer_service.dart';
import '../theme/new_experience_tokens.dart';
import '../widgets/new_glass_container.dart';

/// Premium Obsidian-themed Equalizer & Acoustic DSP Control Sheet
class NewEqualizerSheet extends StatefulWidget {
  const NewEqualizerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NewEqualizerSheet(),
    );
  }

  @override
  State<NewEqualizerSheet> createState() => _NewEqualizerSheetState();
}

class _NewEqualizerSheetState extends State<NewEqualizerSheet> {
  late EqualizerService _eqService;
  late dynamic _player;

  @override
  void initState() {
    super.initState();
    _eqService = locator<EqualizerService>();
    _player = locator<AudioEngineService>().audioHandler.player;
  }

  @override
  Widget build(BuildContext context) {
    final state = _eqService.state;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: NewExperienceTokens.obsidianBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: NewExperienceTokens.specularBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Top Drag Handle ──
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // ── Header Row ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AUDIO ARCHITECTURE',
                        style: NewExperienceTokens.eyebrowLabel(
                          color: NewExperienceTokens.accentCyan,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '10-Band Graphic Equalizer',
                        style: NewExperienceTokens.sectionTitle(fontSize: 20),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        state.isEnabled ? 'ON' : 'OFF',
                        style: NewExperienceTokens.bodySmall(
                          color: state.isEnabled ? NewExperienceTokens.accentCyan : NewExperienceTokens.textMuted,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Switch.adaptive(
                        value: state.isEnabled,
                        activeColor: NewExperienceTokens.accentCyan,
                        onChanged: (val) async {
                          HapticFeedback.lightImpact();
                          await _eqService.setEnabled(val, _player);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  // ── Presets Carousel ──
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: EqualizerService.builtInPresets.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final preset = EqualizerService.builtInPresets[index];
                        final isSelected = state.activePresetId == preset.id;

                        return InkWell(
                          onTap: state.isEnabled
                              ? () async {
                                  HapticFeedback.selectionClick();
                                  await _eqService.applyPreset(preset.id, _player);
                                  setState(() {});
                                }
                              : null,
                          borderRadius: BorderRadius.circular(19),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? NewExperienceTokens.accentCyan.withValues(alpha: 0.22)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(19),
                              border: Border.all(
                                color: isSelected
                                    ? NewExperienceTokens.accentCyan
                                    : NewExperienceTokens.specularBorder,
                              ),
                            ),
                            child: Text(
                              preset.name,
                              style: NewExperienceTokens.bodySmall(
                                color: isSelected ? Colors.white : NewExperienceTokens.textSecondary,
                              ).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── 10-Band Sliders Grid ──
                  NewGlassContainer(
                    borderRadius: 20,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Frequency Response (-12dB to +12dB)',
                                style: NewExperienceTokens.bodySmall(
                                  color: NewExperienceTokens.textMuted,
                                ),
                              ),
                              InkWell(
                                onTap: state.isEnabled
                                    ? () async {
                                        HapticFeedback.mediumImpact();
                                        await _eqService.resetToFlat(_player);
                                        setState(() {});
                                      }
                                    : null,
                                child: Text(
                                  'Reset to Flat',
                                  style: NewExperienceTokens.bodySmall(
                                    color: NewExperienceTokens.accentCyan,
                                  ).copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 170,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: state.bands.map((band) {
                              return _buildBandSlider(band, state.isEnabled);
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Acoustic Boosters (Bass & Treble) ──
                  Row(
                    children: [
                      Expanded(
                        child: NewGlassContainer(
                          borderRadius: 18,
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('BASS BOOST', style: NewExperienceTokens.eyebrowLabel(color: NewExperienceTokens.accentViolet)),
                                  Text('${state.bassBoost.toStringAsFixed(1)} dB', style: NewExperienceTokens.numericTimer(color: Colors.white)),
                                ],
                              ),
                              SliderTheme(
                                data: _compactSliderTheme(NewExperienceTokens.accentViolet),
                                child: Slider(
                                  value: state.bassBoost,
                                  min: 0.0,
                                  max: 10.0,
                                  divisions: 20,
                                  onChanged: state.isEnabled
                                      ? (val) async {
                                          await _eqService.setBassBoost(val, _player);
                                          setState(() {});
                                        }
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: NewGlassContainer(
                          borderRadius: 18,
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('TREBLE BOOST', style: NewExperienceTokens.eyebrowLabel(color: NewExperienceTokens.accentCyan)),
                                  Text('${state.trebleBoost.toStringAsFixed(1)} dB', style: NewExperienceTokens.numericTimer(color: Colors.white)),
                                ],
                              ),
                              SliderTheme(
                                data: _compactSliderTheme(NewExperienceTokens.accentCyan),
                                child: Slider(
                                  value: state.trebleBoost,
                                  min: 0.0,
                                  max: 10.0,
                                  divisions: 20,
                                  onChanged: state.isEnabled
                                      ? (val) async {
                                          await _eqService.setTrebleBoost(val, _player);
                                          setState(() {});
                                        }
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Volume Normalization (ReplayGain / EBU R128) ──
                  NewGlassContainer(
                    borderRadius: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Loudness Normalization (ReplayGain)',
                                style: NewExperienceTokens.bodyMedium(color: Colors.white).copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Maintains uniform perceived loudness (-16 LUFS) across albums and tracks.',
                                style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: state.isLoudnessNormalizationEnabled,
                          activeColor: NewExperienceTokens.accentCyan,
                          onChanged: (val) async {
                            HapticFeedback.lightImpact();
                            await _eqService.setLoudnessNormalization(val, _player);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBandSlider(EqualizerBand band, bool enabled) {
    return Column(
      children: [
        // Gain readout
        Text(
          band.gainDb >= 0 ? '+${band.gainDb.toStringAsFixed(0)}' : band.gainDb.toStringAsFixed(0),
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: enabled ? (band.gainDb != 0 ? NewExperienceTokens.accentCyan : Colors.white60) : Colors.white30,
          ),
        ),
        const SizedBox(height: 4),

        // Vertical Slider Rotated
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3.5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                activeTrackColor: enabled ? NewExperienceTokens.accentCyan : Colors.white24,
                inactiveTrackColor: Colors.white12,
                thumbColor: enabled ? Colors.white : Colors.white38,
              ),
              child: Slider(
                value: band.gainDb,
                min: -12.0,
                max: 12.0,
                divisions: 24,
                onChanged: enabled
                    ? (val) async {
                        await _eqService.setBandGain(band.frequencyHz, val, _player);
                        setState(() {});
                      }
                    : null,
              ),
            ),
          ),
        ),

        const SizedBox(height: 4),
        // Frequency label
        Text(
          band.label,
          style: GoogleFonts.outfit(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: enabled ? Colors.white70 : Colors.white30,
          ),
        ),
      ],
    );
  }

  SliderThemeData _compactSliderTheme(Color accentColor) {
    return SliderTheme.of(context).copyWith(
      trackHeight: 3.0,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
      activeTrackColor: accentColor,
      inactiveTrackColor: Colors.white12,
      thumbColor: Colors.white,
    );
  }
}
