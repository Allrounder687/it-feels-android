import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:go_router/go_router.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';

class SongDeepLinkScreen extends ConsumerStatefulWidget {
  final String songId;
  const SongDeepLinkScreen({super.key, required this.songId});

  @override
  ConsumerState<SongDeepLinkScreen> createState() => _SongDeepLinkScreenState();
}

class _SongDeepLinkScreenState extends ConsumerState<SongDeepLinkScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAndPlaySong();
    });
  }

  Future<void> _fetchAndPlaySong() async {
    try {
      final musicApi = locator<MusicApiService>();
      final song = await musicApi.fetchSongDetails(widget.songId);
      
      if (mounted) {
        if (song != null) {
          // Play the song
          await ref.read(audioPlayerProvider.notifier).playSong(song);
          
          // Navigate to home and open full player
          context.go('/now_playing');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load song. It may be unavailable.')),
          );
          context.go('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load song: $e')),
        );
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.themeBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              "Loading Song...",
              style: TextStyle(
                color: context.themeTextColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
