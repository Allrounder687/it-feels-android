import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/ai_settings_provider.dart';
import '../../providers/audio_player_provider.dart';

class AskAIScreen extends StatefulWidget {
  const AskAIScreen({super.key});

  @override
  State<AskAIScreen> createState() => _AskAIScreenState();
}

class _AskAIScreenState extends State<AskAIScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitRequest() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    final aiSettings = Provider.of<AISettingsProvider>(context, listen: false);
    final audioProvider = Provider.of<AudioPlayerProvider>(context, listen: false);
    
    // Unfocus keyboard
    FocusScope.of(context).unfocus();

    // Use favorites + current queue as the local "library" context
    final allSongs = [
      ...audioProvider.favoriteSongs,
      ...audioProvider.queue,
    ];

    final response = await aiSettings.askAI(query, allSongs);
    if (!mounted) return;

    if (response.success && response.resultSongs != null && response.resultSongs!.isNotEmpty) {
      // Play the generated playlist
      final firstSong = response.resultSongs!.first;
      audioProvider.playSong(firstSong, queue: response.resultSongs, index: 0);
      Navigator.pop(context); // Go back home/player
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playing: "$query"'),
          backgroundColor: AppColors.midnightPrimary,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      // Show error
      final err = response.error ?? aiSettings.lastError ?? 'No songs found for that mood.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiSettings = Provider.of<AISettingsProvider>(context);

    if (!aiSettings.aiEnabled) {
      return Scaffold(
        backgroundColor: AppColors.midnightBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(
            'AI features are disabled in Settings.',
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

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
          "Ask AI",
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "What do you want to hear?",
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Try \"Play something for a rainy evening\" or \"Give me 45 minutes of calm songs.\"",
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _controller,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 18),
              autofocus: true,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: "E.g., I need focus music...",
                hintStyle: GoogleFonts.outfit(color: Colors.white30),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(20),
              ),
              onSubmitted: (_) => _submitRequest(),
            ),
            const SizedBox(height: 32),
            if (aiSettings.isLoading)
              const Center(
                child: CircularProgressIndicator(),
              )
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.midnightPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _submitRequest,
                child: Text(
                  "Generate Playlist",
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
