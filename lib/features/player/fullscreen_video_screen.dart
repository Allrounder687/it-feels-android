import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/player/video_player_provider.dart';
import 'package:it_feels_music/core/widgets/animated_play_pause_button.dart';
import 'package:it_feels_music/core/widgets/bouncy_icon_button.dart';
import 'package:it_feels_music/core/widgets/wavy_seek_bar.dart';

class FullscreenVideoScreen extends ConsumerStatefulWidget {
  final Song song;
  const FullscreenVideoScreen({super.key, required this.song});

  @override
  ConsumerState<FullscreenVideoScreen> createState() =>
      _FullscreenVideoScreenState();
}

class _FullscreenVideoScreenState extends ConsumerState<FullscreenVideoScreen> {
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    // Force Landscape & Hide System Navigation Bars
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _startHideControlsTimer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    // Restore Portrait & System Navigation Bars
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  void _showQualityPicker(
    BuildContext context,
    VideoPlayerState videoProvider,
  ) {
    if (videoProvider.streams.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.hd_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Select Video Quality',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: videoProvider.streams.length,
                  itemBuilder: (context, index) {
                    final stream = videoProvider.streams[index];
                    final quality = stream['quality'] as String;
                    final isSelected = quality == videoProvider.selectedQuality;

                    return ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: isSelected
                          ? Colors.white12
                          : Colors.transparent,
                      title: Text(
                        quality,
                        style: GoogleFonts.inter(
                          color: isSelected
                              ? context.themeAccentColor
                              : Colors.white,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: context.themeAccentColor,
                            )
                          : null,
                      onTap: () {
                        ref
                            .read(videoPlayerProvider.notifier)
                            .changeQuality(quality);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final audioProvider = ref.watch(audioPlayerProvider);
        final downloadProviderLocal = ref.watch(downloadProvider);
        final videoProvider = ref.watch(videoPlayerProvider);
        final settingsProviderLocal = ref.watch(settingsProvider);
        final ctrl = videoProvider.videoController;
        final isInitialized = ctrl != null;

        return Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: _toggleControls,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video Player Container
                Center(
                  child: isInitialized
                      ? ExcludeSemantics(
                          child: Video(
                            controller: ctrl,
                            controls:
                                NoVideoControls, // We use custom controls below
                            fill: Colors.black,
                          ),
                        )
                      : videoProvider.isLoading
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Extracting Secure 4K Stream...',
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Video unavailable',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                ),

                // Controls Overlay
                AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.7),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                          stops: const [0.0, 0.25, 0.75, 1.0],
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Top Bar
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  BouncyIconButton(
                                    child: const Icon(
                                      Icons.fullscreen_exit_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          widget.song.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          widget.song.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Download Video Button
                                  BouncyIconButton(
                                    child: const Icon(
                                      Icons.file_download_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                    onPressed: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Downloading video for ${widget.song.title}...',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),

                                  // Quality Selector Button
                                  GestureDetector(
                                    onTap: () => _showQualityPicker(
                                      context,
                                      videoProvider,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white24,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.high_quality_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            videoProvider.selectedQuality,
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Center Play / Pause & Skip 10s Controls
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                BouncyIconButton(
                                  child: const Icon(
                                    Icons.replay_10_rounded,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                  onPressed: () {
                                    _startHideControlsTimer();
                                    final player = videoProvider.player;
                                    if (player != null) {
                                      final newPos =
                                          player.state.position -
                                          const Duration(seconds: 10);
                                      player.seek(newPos);
                                      if (!settingsProviderLocal
                                          .useVideoAudioSource) {
                                        ref
                                            .read(audioPlayerProvider.notifier)
                                            .seek(newPos);
                                      }
                                    }
                                  },
                                ),
                                const SizedBox(width: 36),
                                Container(
                                  width: 72,
                                  height: 72,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: context.themeAccentColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: StreamBuilder<bool>(
                                    stream:
                                        videoProvider.player?.stream.playing,
                                    builder: (context, snapshot) {
                                      final isPlaying =
                                          snapshot.data ??
                                          videoProvider.player?.state.playing ??
                                          false;
                                      return AnimatedPlayPauseButton(
                                        isPlaying: isPlaying,
                                        color: Colors.black,
                                        size: 44,
                                        onPressed: () {
                                          _startHideControlsTimer();
                                          final player = videoProvider.player;
                                          if (player != null) {
                                            if (isPlaying) {
                                              player.pause();
                                              if (!settingsProviderLocal
                                                  .useVideoAudioSource) {
                                                ref
                                                    .read(
                                                      audioPlayerProvider
                                                          .notifier,
                                                    )
                                                    .pause();
                                              }
                                            } else {
                                              player.play();
                                              if (!settingsProviderLocal
                                                  .useVideoAudioSource) {
                                                ref
                                                    .read(
                                                      audioPlayerProvider
                                                          .notifier,
                                                    )
                                                    .seek(
                                                      player.state.position,
                                                    );
                                                ref
                                                    .read(
                                                      audioPlayerProvider
                                                          .notifier,
                                                    )
                                                    .play();
                                              }
                                            }
                                            setState(() {});
                                          }
                                        },
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 36),
                                BouncyIconButton(
                                  child: const Icon(
                                    Icons.forward_10_rounded,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                  onPressed: () {
                                    _startHideControlsTimer();
                                    final player = videoProvider.player;
                                    if (player != null) {
                                      final newPos =
                                          player.state.position +
                                          const Duration(seconds: 10);
                                      player.seek(newPos);
                                      if (!settingsProviderLocal
                                          .useVideoAudioSource) {
                                        ref
                                            .read(audioPlayerProvider.notifier)
                                            .seek(newPos);
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),

                            // Bottom Seek Bar
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              child: videoProvider.player != null
                                  ? ExcludeSemantics(
                                      child: StreamBuilder<Duration>(
                                        stream: videoProvider
                                            .player!
                                            .stream
                                            .position,
                                        builder: (context, snapshot) {
                                          final position =
                                              snapshot.data ??
                                              videoProvider
                                                  .player!
                                                  .state
                                                  .position;
                                          final duration = videoProvider
                                              .player!
                                              .state
                                              .duration;
                                          return WavySeekBar(
                                            position: position,
                                            duration: duration,
                                            activeColor:
                                                context.themeAccentColor,
                                            inactiveColor: Colors.white24,
                                            onSeek: (newPos) {
                                              _startHideControlsTimer();
                                              videoProvider.player?.seek(newPos);
                                              if (!settingsProviderLocal.useVideoAudioSource) {
                                                ref.read(audioPlayerProvider.notifier).seek(newPos);
                                              }
                                            },
                                          );
                                        },
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
