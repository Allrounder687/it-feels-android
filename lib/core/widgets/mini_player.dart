import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/widgets/animated_play_pause_button.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/features/cast/cast_service.dart';
import 'package:it_feels_music/features/cast/cast_bottom_sheet.dart';

class MiniPlayer extends ConsumerWidget {
  final VoidCallback onTap;

  const MiniPlayer({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Consumer(builder: (context, ref, child) { final playerProvider = ref.watch(audioPlayerProvider); 
        final currentSong = playerProvider.currentSong;
        if (currentSong == null) return const SizedBox.shrink();

        final progress = (playerProvider.duration.inMilliseconds > 0)
            ? (playerProvider.position.inMilliseconds /
                      playerProvider.duration.inMilliseconds)
                  .clamp(0.0, 1.0)
            : 0.0;

        final bottomInset = MediaQuery.of(context).viewPadding.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                height: 72,
                decoration: BoxDecoration(
                  color: playerProvider.themeSurfaceColor.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: context.themeInvertedTextColor.withValues(alpha: 0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Top Progress Indicator Line (YouTube Music style)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
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
                            GestureDetector(
                              onTap: () => ref.read(audioPlayerProvider.notifier).togglePlayPause(),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: context.themeTextColor.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: AnimatedPlayPauseButton(
                                  isPlaying: playerProvider.isPlaying,
                                  onPressed: () =>
                                      ref.read(audioPlayerProvider.notifier).togglePlayPause(),
                                  color: context.themeTextColor,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),
            ),
          ),
        );
      },
    );
  }
}
