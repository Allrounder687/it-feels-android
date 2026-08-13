import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/subscription/paywall_bottom_sheet.dart';
import 'package:it_feels_music/features/player/lyrics_screen.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:it_feels_music/features/player/widgets/share_story_canvas.dart';

class NowPlayingActions extends ConsumerStatefulWidget {
  final Song currentSong;
  final bool isFav;
  final bool isDown;
  final bool isDownloading;
  final Color surfaceColor;
  final Color accentColor;

  const NowPlayingActions({
    super.key,
    required this.currentSong,
    required this.isFav,
    required this.isDown,
    required this.isDownloading,
    required this.surfaceColor,
    required this.accentColor,
  });

  @override
  ConsumerState<NowPlayingActions> createState() => _NowPlayingActionsState();
}

class _NowPlayingActionsState extends ConsumerState<NowPlayingActions> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareSong() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    
    try {
      // Need a slight delay to ensure image is painted
      await Future.delayed(const Duration(milliseconds: 100));
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/story_${widget.currentSong.id}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      
      final exp = DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Listening to "${widget.currentSong.title}" by ${widget.currentSong.artist} on It Feels Music! 🎧\nhttps://allrounder687.github.io/room/${widget.currentSong.id}?exp=$exp', // Fake room link for now to test deep links later
      );
    } catch (e) {
      debugPrint("Share error: $e");
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Hidden canvas for story export
        Positioned(
          left: -9999, // Move far off screen
          top: -9999,
          child: RepaintBoundary(
            key: _boundaryKey,
            child: SizedBox(
              width: 1080,
              height: 1920,
              child: ShareStoryCanvas(
                song: widget.currentSong,
                dominantColor: widget.accentColor,
              ),
            ),
          ),
        ),
        
        SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => ref.read(audioPlayerProvider.notifier).toggleFavorite(widget.currentSong),
            tooltip: widget.isFav ? "Unlike" : "Like",
            icon: Icon(
              widget.isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: widget.isFav ? Colors.pinkAccent : context.themeMutedTextColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () async {
              if (widget.isDown) {
                await ref.read(downloadProvider.notifier).removeDownload(widget.currentSong);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Removed ${widget.currentSong.title} from downloads")),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Downloading ${widget.currentSong.title}...")),
                );
                final ok = await ref.read(downloadProvider.notifier).downloadSong(widget.currentSong);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? "Downloaded ${widget.currentSong.title}" : "Download failed")),
                  );
                }
              }
            },
            tooltip: widget.isDown ? "Downloaded" : "Download",
            icon: widget.isDownloading
                ? SizedBox(
                    width: 28, height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2, color: context.themeTextColor),
                  )
                : Icon(
                    widget.isDown ? Icons.download_done_rounded : Icons.file_download_outlined,
                    color: widget.isDown ? widget.accentColor : context.themeMutedTextColor,
                    size: 28,
                  ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () {
              final sub = ref.read(subscriptionProvider);
              if (sub.isPremium) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LyricsScreen()),
                );
              } else {
                PaywallBottomSheet.show(context, featureName: "Lyrics");
              }
            },
            tooltip: "Lyrics",
            icon: Icon(Icons.lyrics_outlined, color: context.themeMutedTextColor, size: 28),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: _shareSong,
            tooltip: "Share",
            icon: _isSharing
                ? SizedBox(
                    width: 28, height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2, color: context.themeMutedTextColor),
                  )
                : Icon(Icons.share_outlined, color: context.themeMutedTextColor, size: 28),
          ),
        ],
      ),
    ),
      ],
    );
  }
}
