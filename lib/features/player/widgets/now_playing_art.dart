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
import 'package:it_feels_music/services/storage_service.dart';
import 'package:it_feels_music/features/player/video_player_provider.dart';

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
                            PopupMenuButton<String>(
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.more_vert, color: Colors.white, size: 16),
                              ),
                              color: context.themeCardColor,
                              onSelected: (value) async {
                                if (value == 'retry') {
                                  if (videoProvider.originalSongId.isNotEmpty) {
                                    final newQuery = '${videoProvider.currentTitle} ${videoProvider.currentUploader} official music video';
                                    ref.read(videoPlayerProvider.notifier).playVideo(
                                          videoProvider.originalSongId,
                                          videoProvider.currentTitle,
                                          videoProvider.currentUploader,
                                          query: newQuery,
                                          forceReload: true,
                                        );
                                  }
                                } else if (value == 'custom') {
                                  _showCustomLinkDialog(context, ref, videoProvider);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'retry',
                                  child: Row(
                                    children: [
                                      Icon(Icons.refresh, color: context.themeTextColor),
                                      const SizedBox(width: 12),
                                      Text('Retry Match', style: GoogleFonts.inter(color: context.themeTextColor)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'custom',
                                  child: Row(
                                    children: [
                                      Icon(Icons.link, color: context.themeTextColor),
                                      const SizedBox(width: 12),
                                      Text('Set Custom Video', style: GoogleFonts.inter(color: context.themeTextColor)),
                                    ],
                                  ),
                                ),
                              ],
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
              Builder(
                builder: (context) {
                  bool isHovering = false;
                  return StatefulBuilder(
                    builder: (context, setState) {
                  return MouseRegion(
                    onEnter: (_) => isWide ? setState(() => isHovering = true) : null,
                    onExit: (_) => isWide ? setState(() => isHovering = false) : null,
                    child: AnimatedScale(
                      scale: isHovering ? 1.03 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      child: Hero(
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
                    ),
                  );
                },
              );
            },
          ),
              if (isWide)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Text(
                          (currentSong.streamUrl?.toLowerCase().endsWith('.flac') ?? false) || (currentSong.streamUrl?.toLowerCase().endsWith('.alac') ?? false)
                              ? 'LOSSLESS'
                              : (currentSong.streamUrl?.toLowerCase().endsWith('.wav') ?? false)
                                  ? 'HIGH-RES'
                                  : '320 KBPS',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.amber,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Builder(builder: (context) {
                        String sourceName = 'SAAVN';
                        Color sourceColor = Colors.tealAccent;
                        
                        if (currentSong.id.startsWith('youtube:') || currentSong.id.startsWith('search:')) {
                          sourceName = 'YOUTUBE';
                          sourceColor = Colors.redAccent;
                        } else if (currentSong.id.startsWith('spotify:')) {
                          sourceName = 'SPOTIFY';
                          sourceColor = const Color(0xFF1DB954);
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Text(
                            sourceName,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: sourceColor,
                              letterSpacing: 1.0,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
            ],
          ),
    );
  }

  void _showCustomLinkDialog(BuildContext context, WidgetRef ref, VideoPlayerState videoProvider) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.themeSurfaceColor,
          title: Text(
            'Set Custom YouTube Video',
            style: GoogleFonts.outfit(color: context.themeTextColor, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            style: GoogleFonts.inter(color: context.themeTextColor),
            decoration: InputDecoration(
              hintText: 'Paste YouTube URL or ID...',
              hintStyle: GoogleFonts.inter(color: context.themeMutedTextColor),
              filled: true,
              fillColor: context.themeCardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: context.themeMutedTextColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.themeAccentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final input = controller.text.trim();
                if (input.isNotEmpty) {
                  String? customId;
                  if (input.contains('v=')) {
                    customId = input.split('v=')[1].split('&').first.substring(0, 11);
                  } else if (input.contains('youtu.be/')) {
                    customId = input.split('youtu.be/')[1].split('?').first.substring(0, 11);
                  } else if (input.length == 11) {
                    customId = input;
                  }

                  if (customId != null && videoProvider.originalSongId.isNotEmpty) {
                    await StorageService.saveCustomVideoLink(
                      videoProvider.originalSongId,
                      customId,
                    );
                    if (context.mounted) Navigator.pop(context);
                    ref.read(videoPlayerProvider.notifier).playVideo(
                          videoProvider.originalSongId,
                          videoProvider.currentTitle,
                          videoProvider.currentUploader,
                          query: '', // Bypass query search since we have exact ID
                          forceReload: true,
                        );
                  }
                }
              },
              child: Text('Save & Reload', style: GoogleFonts.inter(color: context.themeInvertedTextColor, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
