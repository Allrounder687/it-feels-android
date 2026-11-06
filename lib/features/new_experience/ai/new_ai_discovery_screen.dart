import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/intelligence/ai/ai_discovery_orchestrator.dart';
import 'package:it_feels_music/core/intelligence/taste/taste_profile_service.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/new_ambient_canvas.dart';
import '../widgets/new_action_button.dart';
import '../widgets/new_media_tile.dart';
import '../widgets/new_glass_container.dart';

class NewAIDiscoveryScreen extends ConsumerStatefulWidget {
  const NewAIDiscoveryScreen({super.key});

  @override
  ConsumerState<NewAIDiscoveryScreen> createState() => _NewAIDiscoveryScreenState();
}

class _NewAIDiscoveryScreenState extends ConsumerState<NewAIDiscoveryScreen> {
  final TextEditingController _promptController = TextEditingController();
  bool _isGenerating = false;
  List<Song> _curatedSongs = [];
  String _generatedTitle = '';

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generatePlaylist(String prompt) async {
    final cleanPrompt = prompt.trim();
    if (cleanPrompt.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _curatedSongs = [];
      _generatedTitle = cleanPrompt;
    });

    try {
      final orchestrator = AIDiscoveryOrchestrator();
      final tasteProfile = TasteProfileService.instance.profile;
      final result = await orchestrator.discoverAndValidate(
        prompt: cleanPrompt,
        profile: tasteProfile,
        count: 20,
      );

      if (mounted) {
        setState(() {
          _curatedSongs = result.songs;
          _generatedTitle = result.title;
          _isGenerating = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerNotifier = ref.read(audioPlayerProvider.notifier);

    return NewAmbientCanvas(
      intensity: 0.4,
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
            'AI Music Discovery',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // Header
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [NewExperienceTokens.accentViolet, NewExperienceTokens.accentCyan],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: NewExperienceTokens.accentViolet.withValues(alpha: 0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 30),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'Describe Your Vibe',
                textAlign: TextAlign.center,
                style: NewExperienceTokens.displayHero(fontSize: 24),
              ),
              const SizedBox(height: 4),
              Text(
                'Type a feeling, artist cluster, or mood. We match real JioSaavn tracks and discard karaoke or instrumental remakes.',
                textAlign: TextAlign.center,
                style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textSecondary),
              ),
              const SizedBox(height: 20),

              // Prompt Input Box
              NewGlassContainer(
                borderRadius: NewExperienceTokens.radiusMedium,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: TextField(
                  controller: _promptController,
                  style: NewExperienceTokens.bodyMedium(),
                  decoration: InputDecoration(
                    hintText: 'e.g., Rainy day acoustic indie like Prateek Kuhad...',
                    hintStyle: NewExperienceTokens.bodySmall(
                      color: NewExperienceTokens.textMuted,
                    ),
                    border: InputBorder.none,
                  ),
                  onSubmitted: _generatePlaylist,
                ),
              ),
              const SizedBox(height: 14),

              // Preset Inspiration Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'Late Night Lo-Fi',
                  'High Energy Workout',
                  'Bollywood Acoustic',
                  '90s Nostalgia',
                  'Punjabi Hype',
                ].map((preset) {
                  return InkWell(
                    onTap: () {
                      _promptController.text = preset;
                      _generatePlaylist(preset);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: NewExperienceTokens.specularBorder),
                      ),
                      child: Text(
                        preset,
                        style: NewExperienceTokens.captionMuted(
                          color: NewExperienceTokens.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              NewActionButton(
                label: _isGenerating ? 'Curating Catalogue...' : 'Generate Playlist',
                icon: Icons.auto_awesome_rounded,
                onPressed: _isGenerating ? () {} : () => _generatePlaylist(_promptController.text),
              ),

              const SizedBox(height: 24),

              // Curated Track Results
              if (_curatedSongs.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Curated Tracks (${_curatedSongs.length})',
                        style: NewExperienceTokens.sectionTitle(fontSize: 18),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.playlist_add_rounded, size: 18),
                      label: const Text('Save Playlist'),
                      style: TextButton.styleFrom(
                        foregroundColor: NewExperienceTokens.accentCyan,
                      ),
                      onPressed: () {
                        ref
                            .read(customPlaylistProvider.notifier)
                            .createPlaylist('AI: $_generatedTitle');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('AI Playlist saved to Your Library'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ..._curatedSongs.map(
                  (song) => NewMediaTile(
                    song: song,
                    onTap: () => playerNotifier.playSong(song),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
