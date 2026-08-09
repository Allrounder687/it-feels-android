import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/services/audio_engine_service.dart';
import 'package:media_kit_video/media_kit_video.dart';

class DesktopMiniplayerScreen extends ConsumerStatefulWidget {
  const DesktopMiniplayerScreen({super.key});

  @override
  ConsumerState<DesktopMiniplayerScreen> createState() => _DesktopMiniplayerScreenState();
}

class _DesktopMiniplayerScreenState extends ConsumerState<DesktopMiniplayerScreen> {
  bool _isHovering = false;
  bool _isDebouncing = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _restoreWindow() async {
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setMinimumSize(const Size(800, 600));
    await windowManager.setSize(const Size(1280, 720)); // Restore to normal bounds
    await windowManager.setAlignment(Alignment.center);
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioPlayerProvider);
    final videoState = ref.watch(videoPlayerProvider);
    final currentSong = audioState.currentSong;
    final engine = locator<AudioEngineService>();

    if (currentSong == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _restoreWindow,
          ),
        ),
      );
    }

    final isPlaying = audioState.isPlaying || (videoState.player?.state.playing ?? false);
    final hasVideo = videoState.isVideoActive && videoState.videoController != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          onPanUpdate: (details) {
            windowManager.startDragging();
          },
          onDoubleTap: _restoreWindow,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Canvas (Video or Artwork)
              if (hasVideo)
                Video(controller: videoState.videoController!, fit: BoxFit.cover, controls: NoVideoControls)
              else
                CustomImageWidget(
                  imageUrl: currentSong.coverArt,
                  fit: BoxFit.cover,
                ),

              // Overlay Gradient
              if (_isHovering || !isPlaying)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),

              // Controls overlay
              if (_isHovering || !isPlaying)
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Bar (Restore / Drag)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.open_in_full, color: Colors.white, size: 20),
                            tooltip: "Restore Window",
                            onPressed: _restoreWindow,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 20),
                            tooltip: "Close Player",
                            onPressed: () async {
                              await windowManager.close();
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    // Bottom Bar (Info & Playback)
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currentSong.title,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  currentSong.artist,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.skip_previous, color: Colors.white),
                                iconSize: 24,
                                onPressed: () => engine.skipToPrevious(),
                              ),
                              IconButton(
                                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                                iconSize: 32,
                                onPressed: () async {
                                  if (_isDebouncing) return;
                                  setState(() => _isDebouncing = true);
                                  
                                  if (isPlaying) {
                                    if (hasVideo) await videoState.player?.pause();
                                    await ref.read(audioPlayerProvider.notifier).pause();
                                  } else {
                                    if (hasVideo) await videoState.player?.play();
                                    await ref.read(audioPlayerProvider.notifier).playSong(
                                      currentSong,
                                      queue: audioState.queue,
                                      index: audioState.currentIndex,
                                    );
                                  }
                                  
                                  Future.delayed(const Duration(milliseconds: 300), () {
                                    if (mounted) setState(() => _isDebouncing = false);
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.skip_next, color: Colors.white),
                                iconSize: 24,
                                onPressed: () => engine.skipToNext(),
                              ),
                            ],
                          ),
                        ],
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
}
