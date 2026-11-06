import 'package:flutter/material.dart';
import 'package:it_feels_music/core/intelligence/taste/taste_profile_service.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/new_ambient_canvas.dart';
import '../widgets/new_glass_container.dart';

class TasteProfileScreen extends StatefulWidget {
  const TasteProfileScreen({super.key});

  @override
  State<TasteProfileScreen> createState() => _TasteProfileScreenState();
}

class _TasteProfileScreenState extends State<TasteProfileScreen> {
  final TasteProfileService _service = TasteProfileService.instance;

  void _showAddExclusionDialog({required bool isArtist}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: NewExperienceTokens.midnightSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isArtist ? 'Exclude Artist' : 'Exclude Genre',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: isArtist ? 'e.g. Bad Singer' : 'e.g. Heavy Metal',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: NewExperienceTokens.accentViolet,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  if (isArtist) {
                    _service.excludeArtist(text);
                  } else {
                    _service.excludeGenre(text);
                  }
                  setState(() {});
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Exclude', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: NewExperienceTokens.midnightSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Reset Music Taste Profile?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'This will clear learned artist affinities, genre weights, and exclusions, restoring recommendation defaults.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                await _service.reset();
                if (mounted) {
                  setState(() {});
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Reset Everything', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _service.profile;

    return NewAmbientCanvas(
      intensity: 0.3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Taste Profile',
            style: NewExperienceTokens.sectionTitle(fontSize: 18),
          ),
        ),
        body: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // ── Novelty Balance ──
              _buildSectionHeader('DISCOVERY BALANCE'),
              NewGlassContainer(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Novelty Tolerance', style: NewExperienceTokens.sectionTitle(fontSize: 15)),
                        Text(
                          '${(profile.noveltyTolerance * 100).toInt()}%',
                          style: const TextStyle(
                            color: NewExperienceTokens.accentCyan,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.noveltyTolerance < 0.35
                          ? 'Prioritizing core favorites & familiar hits'
                          : (profile.noveltyTolerance > 0.65
                              ? 'Adventurous discovery with unfamiliar gems'
                              : 'Balanced mix of favorites and fresh recommendations'),
                      style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
                    ),
                    const SizedBox(height: 12),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: NewExperienceTokens.accentViolet,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                        thumbColor: Colors.white,
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: profile.noveltyTolerance,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (val) {
                          _service.setNoveltyTolerance(val);
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Top Artist Affinities ──
              _buildSectionHeader('TOP ARTIST AFFINITIES'),
              NewGlassContainer(
                padding: const EdgeInsets.all(16),
                child: profile.shortTermArtistAffinities.isEmpty
                    ? Text(
                        'No artist data recorded yet. Play a few songs to build your taste profile!',
                        style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
                      )
                    : Column(
                        children: profile.shortTermArtistAffinities.entries.take(5).map((e) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      e.key.toUpperCase(),
                                      style: NewExperienceTokens.bodySmall(color: Colors.white)
                                          .copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${(e.value * 100).toInt()}%',
                                      style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textSecondary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: e.value,
                                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                                    valueColor: const AlwaysStoppedAnimation(NewExperienceTokens.accentViolet),
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 20),

              // ── Excluded Artists ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader('EXCLUDED ARTISTS'),
                  TextButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 16, color: NewExperienceTokens.accentCyan),
                    label: const Text('Add', style: TextStyle(color: NewExperienceTokens.accentCyan, fontSize: 13)),
                    onPressed: () => _showAddExclusionDialog(isArtist: true),
                  ),
                ],
              ),
              NewGlassContainer(
                padding: const EdgeInsets.all(16),
                child: profile.excludedArtists.isEmpty
                    ? Text(
                        'No artists excluded. Excluded artists are never recommended or autoplayed.',
                        style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: profile.excludedArtists.map((artist) {
                          return Chip(
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            label: Text(artist, style: const TextStyle(color: Colors.white, fontSize: 13)),
                            deleteIcon: const Icon(Icons.close_rounded, size: 16, color: Colors.white70),
                            onDeleted: () async {
                              await _service.unexcludeArtist(artist);
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 20),

              // ── Excluded Genres ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader('EXCLUDED GENRES'),
                  TextButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 16, color: NewExperienceTokens.accentCyan),
                    label: const Text('Add', style: TextStyle(color: NewExperienceTokens.accentCyan, fontSize: 13)),
                    onPressed: () => _showAddExclusionDialog(isArtist: false),
                  ),
                ],
              ),
              NewGlassContainer(
                padding: const EdgeInsets.all(16),
                child: profile.excludedGenres.isEmpty
                    ? Text(
                        'No genres excluded.',
                        style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: profile.excludedGenres.map((genre) {
                          return Chip(
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            label: Text(genre, style: const TextStyle(color: Colors.white, fontSize: 13)),
                            deleteIcon: const Icon(Icons.close_rounded, size: 16, color: Colors.white70),
                            onDeleted: () async {
                              await _service.unexcludeGenre(genre);
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 32),

              // ── Reset Button ──
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.restart_alt_rounded, size: 20),
                label: const Text('Reset Personalization Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _confirmReset,
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: NewExperienceTokens.eyebrowLabel(
          color: NewExperienceTokens.textMuted,
        ),
      ),
    );
  }
}
