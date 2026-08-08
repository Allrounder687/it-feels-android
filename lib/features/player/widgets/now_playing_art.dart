import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/player/fullscreen_video_screen.dart';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/player/widgets/pulse_glow_background.dart';
import 'package:it_feels_music/core/widgets/clever_loading_text.dart';

class NowPlayingArt extends ConsumerWidget {
  final bool isVideoMode;
  final bool isWide;
  final double artSize;
  final Song currentSong;
  final bool isPlaying;
  final Color surfaceColor;
  final Color accentColor;
  final VoidCallback onQualityPickerTap;

  const NowPlayingArt({
    super.key,
    required this.isVideoMode,
    required this.isWide,
    required this.artSize,
    required this.currentSong,
    required this.isPlaying,
    required this.surfaceColor,
    required this.accentColor,
    required this.onQualityPickerTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoProvider = ref.watch(videoPlayerProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: isVideoMode 
        ? AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              key: const ValueKey('video_player'),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: videoProvider.isLoading 
                        ? const CleverLoadingText()
                        : videoProvider.videoController != null
                          ? ExcludeSemantics(
                              child: Video(
                                controller: videoProvider.videoController!,
                                controls: NoVideoControls,
                                fill: Colors.black,
                              ),
                            )
                          : Center(child: Text('Video unavailable', style: GoogleFonts.inter(color: Colors.white))),
                    ),
                    if (videoProvider.videoController != null)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Downloading video for ${currentSong.title}...'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.file_download_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: onQualityPickerTap,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  videoProvider.selectedQuality,
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FullscreenVideoScreen(song: currentSong),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          )
        : Stack(
            key: const ValueKey('audio_art'),
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: PulseGlowBackground(
                  color: accentColor,
                  isPlaying: isPlaying,
                ),
              ),
              Hero(
                tag: 'cover_${currentSong.id}',
                child: Container(
                  width: artSize,
                  height: artSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(isWide ? 36 : 24),
                    boxShadow: [
                      BoxShadow(
                        color: context.themeInvertedTextColor.withValues(alpha: 0.35),
                        blurRadius: isWide ? 40 : 24,
                        offset: Offset(0, isWide ? 20 : 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isWide ? 36 : 24),
                    child: currentSong.coverArt.isNotEmpty
                        ? CustomImageWidget(
                            imageUrl: currentSong.coverArt,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(color: surfaceColor),
                          )
                        : Container(color: surfaceColor),
                  ),
                ),
              ),
            ],
          ),
    );
  }
}
