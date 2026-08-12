import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

class DownloadDeepLinkScreen extends ConsumerStatefulWidget {
  final String songId;
  const DownloadDeepLinkScreen({super.key, required this.songId});

  @override
  ConsumerState<DownloadDeepLinkScreen> createState() => _DownloadDeepLinkScreenState();
}

class _DownloadDeepLinkScreenState extends ConsumerState<DownloadDeepLinkScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAndDownloadSong();
    });
  }

  Future<void> _fetchAndDownloadSong() async {
    try {
      final musicApi = locator<MusicApiService>();
      final song = await musicApi.fetchSongDetails(widget.songId);
      
      if (mounted) {
        if (song != null) {
          // Trigger the download
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Magic Link Activated: Downloading ${song.title}...')),
          );
          ref.read(downloadProvider.notifier).downloadSong(song);
          
          // Navigate to library or home
          context.go('/library');
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
            const Icon(Icons.downloading, size: 64, color: Colors.white),
            const SizedBox(height: 24),
            Text(
              "Preparing Magic Download...",
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
