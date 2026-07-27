import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/ai_settings_provider.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/custom_playlist_provider.dart';

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
      if (audioProvider.queue.isNotEmpty) {
        // Zero cognitive overload queue dialog
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.midnightSurface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (bottomSheetContext) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: 24.0, 
                    left: 16.0, 
                    right: 16.0, 
                    bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 24.0
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'AI Playlist Ready',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${response.resultSongs!.length} songs generated based on your mood.',
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.midnightPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 28),
                        label: Text("Play Now & Clear Queue", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          audioProvider.playSong(response.resultSongs!.first, queue: response.resultSongs, index: 0);
                          Navigator.pop(bottomSheetContext);
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Colors.white24),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.queue_music, size: 20),
                              label: Text("Queue", style: GoogleFonts.outfit(fontSize: 14)),
                              onPressed: () {
                                audioProvider.addSongsToQueue(response.resultSongs!);
                                Navigator.pop(bottomSheetContext); // close bottom sheet
                                Navigator.pop(context); // close ask ai screen
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Added ${response.resultSongs!.length} songs to queue'), backgroundColor: AppColors.midnightPrimary),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Colors.white24),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.playlist_add, size: 20),
                              label: Text("Save", style: GoogleFonts.outfit(fontSize: 14)),
                              onPressed: () {
                                final customPlaylistProvider = Provider.of<CustomPlaylistProvider>(context, listen: false);
                                final playlistName = "AI: $query";
                                customPlaylistProvider.createPlaylistWithSongs(playlistName, response.resultSongs!);
                                Navigator.pop(bottomSheetContext);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Saved as "$playlistName"'), backgroundColor: AppColors.midnightPrimary),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      } else {
        // Play the generated playlist directly if queue is empty
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
      }
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

  List<String> _getSuggestionsForTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) {
      return ["Morning Acoustic", "Upbeat Commute", "Focus Coffee Shop", "Chill Morning"];
    } else if (hour >= 12 && hour < 17) {
      return ["Afternoon Energy", "Top Hits", "Chill Pop", "Workout Beats"];
    } else if (hour >= 17 && hour < 21) {
      return ["Evening Wind Down", "Dinner Jazz", "Sunset Vibes", "Relaxing R&B"];
    } else {
      return ["Late Night Lofi", "Deep Focus", "Sleep Ambient", "Midnight Synthwave"];
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

    final suggestions = _getSuggestionsForTimeOfDay();

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
          "Ask Feels",
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
              "What are you feeling like?",
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
            const SizedBox(height: 24),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      label: Text(suggestion, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13)),
                      backgroundColor: Colors.white.withOpacity(0.08),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onPressed: () {
                        _controller.text = suggestion;
                        _submitRequest();
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
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
