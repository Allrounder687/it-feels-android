import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/widgets/animated_play_pause_button.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/features/cast/cast_service.dart';
import 'package:it_feels_music/features/cast/cast_bottom_sheet.dart';
import 'package:it_feels_music/features/settings/settings_provider.dart';

class MiniPlayer extends ConsumerWidget {
  final VoidCallback onTap;

  const MiniPlayer({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Consumer(builder: (context, ref, child) { 
        final playerProvider = ref.watch(audioPlayerProvider); 
        final videoProvider = ref.watch(videoPlayerProvider);
        final settings = ref.watch(settingsProvider);
        final isSameSong = playerProvider.currentSong != null && 
                           (videoProvider.currentVideoId == playerProvider.currentSong!.id || 
                            videoProvider.currentVideoId == 'search:${playerProvider.currentSong!.id}');
        final isMutedCanvas = !settings.useVideoAudioSource && isSameSong;

        if (videoProvider.isVideoActive && !isMutedCanvas) return const SizedBox.shrink();

        final currentSong = playerProvider.currentSong;
        if (currentSong == null) return const SizedBox.shrink();



        final bottomInset = MediaQuery.of(context).viewPadding.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Builder(
              builder: (context) {
                final child = Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  height: 72,
                  decoration: BoxDecoration(
                    color: playerProvider.themeSurfaceColor.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Builder(
                      builder: (context) {
                        double blurAmount = 20.0;
                        if (settings.graphicsQuality == GraphicsQuality.medium) blurAmount = 10.0;
                        if (settings.graphicsQuality == GraphicsQuality.low) blurAmount = 0.0;
                        if (kDebugMode) blurAmount = 0.0; // Hot reload performance

                        final Widget playerContent = Stack(
                          children: [
                            // Top Progress Indicator Line (YouTube Music style)
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 0,
                              child: RepaintBoundary(
                                child: ExcludeSemantics(
                                  child: StreamBuilder<Duration>(
                                    stream: ref.read(audioPlayerProvider.notifier).audioHandler.player.positionStream,
                                    initialData: playerProvider.position,
                                    builder: (context, snapshot) {
                                      final pos = snapshot.data ?? playerProvider.position;
                                      final progress = (playerProvider.duration.inMilliseconds > 0)
                                          ? (pos.inMilliseconds / playerProvider.duration.inMilliseconds).clamp(0.0, 1.0)
                                          : 0.0;
                                      return LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 2.5,
                                        backgroundColor: context.themeTextColor12,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          playerProvider.themeAccentColor,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),

                            // Main Mini Player Tap Area
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: onTap,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Row(
                                    children: [
                                      // Cover Art Thumbnail with Hero
                                      Hero(
                                        tag: 'cover_${currentSong.id}',
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: SizedBox(
                                            width: 44,
                                            height: 44,
                                            child: currentSong.coverArt.isNotEmpty
                                                ? CustomImageWidget(
                                                    imageUrl: currentSong.coverArt,
                                                    fit: BoxFit.cover,
                                                    errorWidget: (context, url, error) =>
                                                        Icon(
                                                          Icons.music_note,
                                                          color: context.themeTextColor,
                                                        ),
                                                  )
                                                : Icon(
                                                    Icons.music_note,
                                                    color: context.themeTextColor,
                                                  ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Song Title & Artist
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              currentSong.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: context.themeTextColor,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              currentSong.artist,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: context.themeTextColor.withValues(
                                                  alpha: 0.7,
                                                ),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Cast Action Button
                                      Builder(
                                        builder: (context) {
                                          final isCasting = locator<CastService>().isConnected;
                                          return IconButton(
                                            icon: Icon(
                                              isCasting ? Icons.cast_connected_rounded : Icons.cast_rounded,
                                              color: isCasting ? playerProvider.themeAccentColor : context.themeMutedTextColor,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              CastBottomSheet.show(context);
                                            },
                                            tooltip: 'Cast Audio',
                                          );
                                        },
                                      ),

                                      // Play/Pause Button
                                      Container(
                                        decoration: BoxDecoration(
                                          color: context.themeTextColor.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: AnimatedPlayPauseButton(
                                          isPlaying: playerProvider.isPlaying,
                                          onPressed: () => ref.read(audioPlayerProvider.notifier).togglePlayPause(),
                                          color: context.themeTextColor,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Close Player Button
                                      IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 20),
                                        color: context.themeMutedTextColor,
                                        onPressed: () {
                                          ref.read(audioPlayerProvider.notifier).closePlayer();
                                        },
                                        tooltip: 'Close Player',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );

                        return blurAmount > 0
                            ? BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
                                child: playerContent,
                              )
                            : playerContent;
                      },
                    ),
                  ),
                );
                
                return child;
              },
            ),
          ),
        );
      },
    );
  }
}
