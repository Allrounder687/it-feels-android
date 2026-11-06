import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/services/playlist_import_service.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/new_ambient_canvas.dart';
import '../widgets/new_action_button.dart';
import '../widgets/new_glass_container.dart';

class NewSpotifyImportScreen extends ConsumerStatefulWidget {
  const NewSpotifyImportScreen({super.key});

  @override
  ConsumerState<NewSpotifyImportScreen> createState() => _NewSpotifyImportScreenState();
}

class _NewSpotifyImportScreenState extends ConsumerState<NewSpotifyImportScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isImporting = false;
  String _statusText = '';

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() => _urlController.text = data.text!.trim());
    }
  }

  Future<void> _startImport() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isImporting = true;
      _statusText = 'Analyzing Spotify link and querying catalogue...';
    });

    final playlistState = ref.read(customPlaylistProvider);
    final repo = locator<IMusicRepository>();

    await PlaylistImportService().startBackgroundImport(url, playlistState, repo);

    if (mounted) {
      setState(() {
        _isImporting = false;
        _statusText = 'Import process finished. Check Your Library for the new playlist.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return NewAmbientCanvas(
      intensity: 0.35,
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
            'Spotify Playlist Import',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: [
              // Icon Header
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                    border: Border.all(
                      color: const Color(0xFF1DB954).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.import_export_rounded,
                      color: Color(0xFF1DB954),
                      size: 36,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Transfer Any Playlist',
                textAlign: TextAlign.center,
                style: NewExperienceTokens.displayHero(fontSize: 24),
              ),
              const SizedBox(height: 6),
              Text(
                'Paste a public Spotify playlist link below. Tracks will be automatically resolved against real JioSaavn lossless catalogue entries.',
                textAlign: TextAlign.center,
                style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textSecondary),
              ),
              const SizedBox(height: 28),

              // Input Container
              NewGlassContainer(
                borderRadius: NewExperienceTokens.radiusMedium,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        style: NewExperienceTokens.bodyMedium(),
                        decoration: InputDecoration(
                          hintText: 'https://open.spotify.com/playlist/...',
                          hintStyle: NewExperienceTokens.bodySmall(
                            color: NewExperienceTokens.textMuted,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Paste',
                      icon: const Icon(
                        Icons.content_paste_rounded,
                        color: NewExperienceTokens.accentCyan,
                        size: 20,
                      ),
                      onPressed: _pasteClipboard,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Import Action
              NewActionButton(
                label: _isImporting ? 'Importing...' : 'Start Import',
                icon: Icons.download_rounded,
                customAccent: const Color(0xFF1DB954),
                onPressed: _isImporting ? () {} : _startImport,
              ),

              if (_statusText.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NewExperienceTokens.specularBorder),
                  ),
                  child: Text(
                    _statusText,
                    style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.accentCyan),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 36),

              // Fallback Notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NewExperienceTokens.midnightSurface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: NewExperienceTokens.specularBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_user_rounded,
                          color: NewExperienceTokens.accentEmerald,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Compliance & Quality Guarantee',
                          style: NewExperienceTokens.bodyMedium().copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Only authorized playlist metadata is read.\n'
                      '• Songs are matched directly to 320kbps JioSaavn streams.\n'
                      '• Supports CSV & M3U playlist file exports as well.\n'
                      '• Audio is never scraped from proprietary streaming endpoints.',
                      style: NewExperienceTokens.captionMuted(
                        color: NewExperienceTokens.textSecondary,
                      ).copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
