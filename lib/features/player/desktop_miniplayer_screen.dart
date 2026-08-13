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
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/features/settings/settings_provider.dart';

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
      windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);
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
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);
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
                _PiPLyricsView(
                  song: currentSong,
                  engine: engine,
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
                    // Top Bar (Expand)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.open_in_full, color: Colors.white, size: 20),
                            onPressed: _restoreWindow,
                            tooltip: 'Expand',
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
                                icon: const Icon(Icons.replay_10, color: Colors.white),
                                iconSize: 24,
                                onPressed: () {
                                  final newPos = engine.position - const Duration(seconds: 15);
                                  engine.seek(newPos < Duration.zero ? Duration.zero : newPos);
                                },
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
                                icon: const Icon(Icons.forward_10, color: Colors.white),
                                iconSize: 24,
                                onPressed: () {
                                  final newPos = engine.position + const Duration(seconds: 15);
                                  engine.seek(newPos);
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

class _PiPLyricsView extends ConsumerWidget {
  final dynamic song;
  final AudioEngineService engine;

  const _PiPLyricsView({required this.song, required this.engine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyricsState = ref.watch(lyricsProvider);
    final lyricsResult = lyricsState.lyricsResult;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Blurred Background
        CustomImageWidget(
          imageUrl: song.coverArt,
          fit: BoxFit.cover,
        ),
        Consumer(
          builder: (context, ref, child) {
            final settings = ref.watch(settingsProvider);
            double blurAmount = 30.0;
            if (settings.graphicsQuality == GraphicsQuality.medium) blurAmount = 15.0;
            if (settings.graphicsQuality == GraphicsQuality.low) blurAmount = 0.0;

            return blurAmount > 0
                ? BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
                    child: Container(color: Colors.black.withValues(alpha: 0.5)),
                  )
                : Container(color: Colors.black.withValues(alpha: 0.8)); // darker if no blur
          },
        ),
        // Lyrics Content
        RepaintBoundary(
          child: StreamBuilder<Duration>(
            stream: engine.positionStream,
            initialData: engine.position,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;

              String currentLine = "Playing ${song.title}...";
              if (lyricsState.isLoading) {
                currentLine = "Searching lyrics...";
              } else if (lyricsResult != null && lyricsResult.hasSynced) {
                final activeIdx = lyricsState.getActiveLineIndex(position);
                if (activeIdx >= 0 && activeIdx < lyricsResult.syncedLyrics.length) {
                  currentLine = lyricsResult.syncedLyrics[activeIdx].text;
                }
              } else if (lyricsResult != null && lyricsResult.hasStatic && lyricsResult.staticLyrics != null) {
                currentLine = "Lyrics available (Static)";
              } else if (lyricsState.lyricsNotFound) {
                currentLine = "";
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60.0),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      currentLine,
                      key: ValueKey(currentLine),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        shadows: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

