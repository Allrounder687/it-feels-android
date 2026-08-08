import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/widgets/clever_loading_text.dart';
import 'package:it_feels_music/core/providers/fullscreen_provider.dart';
import 'package:it_feels_music/features/player/video_player_provider.dart';
import 'package:it_feels_music/services/storage_service.dart';
import 'package:go_router/go_router.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({super.key});

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  bool _showControls = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isFullscreen = false;
  Timer? _hideTimer;
  final FocusNode _focusNode = FocusNode();

  // Variables for gesture tracking
  double? _dragStartX;
  double? _dragStartY;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isFullscreen = MediaQuery.of(context).orientation == Orientation.landscape;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _hideTimer?.cancel();
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _showControls) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  void _toggleFullscreen() async {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    // Update global UI provider so the title bar vanishes
    ref.read(fullscreenProvider.notifier).state = _isFullscreen;

    if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      await windowManager.ensureInitialized();
      if (_isFullscreen) {
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      } else {
        await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      }
      await windowManager.setFullScreen(_isFullscreen);
    } else {
      if (_isFullscreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
  }

  void _onVerticalDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
    _dragStartY = details.globalPosition.dy;
  }

  void _onVerticalDragUpdate(
    DragUpdateDetails details,
    VideoPlayerState provider,
  ) {
    if (_dragStartX == null || _dragStartY == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final dy = details.primaryDelta ?? 0;

    // Negative dy means sliding UP (increase), positive means DOWN (decrease)
    final delta = -(dy / 200.0); // Sensitivity

    if (_dragStartX! < screenWidth / 2) {
      // Left side: Brightness
      ref.read(videoPlayerProvider.notifier).adjustBrightness(delta);
    } else {
      // Right side: Volume
      ref.read(videoPlayerProvider.notifier).adjustVolume(delta);
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _dragStartX = null;
    _dragStartY = null;
  }

  Future<void> _downloadVideo(VideoPlayerState provider) async {
    if (provider.streams.isEmpty || _isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final streamUrl = provider.streams.firstWhere(
        (s) => s['quality'] == provider.selectedQuality,
        orElse: () => provider.streams.first,
      )['url'];

      if (streamUrl == null) return;

      final dir = await getApplicationDocumentsDirectory();
      final videoDir = Directory('${dir.path}/downloaded_videos');
      if (!videoDir.existsSync()) videoDir.createSync(recursive: true);

      final cleanId = provider.currentVideoId.replaceAll('youtube:', '');
      final filePath = '${videoDir.path}/$cleanId.mp4';

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(streamUrl));
      final response = await client.send(request);

      final contentLength = response.contentLength ?? 0;
      int downloaded = 0;

      final file = File(filePath);
      final sink = file.openWrite();

      await response.stream.listen((chunk) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0 && mounted) {
          setState(() {
            _downloadProgress = downloaded / contentLength;
          });
        }
      }).asFuture();

      await sink.close();

      await StorageService.saveDownloadedVideo({
        'id': provider.currentVideoId,
        'title': provider.currentTitle,
        'uploader': provider.currentUploader,
        'localPath': filePath,
        'quality': provider.selectedQuality,
        'addedAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Downloaded "${provider.currentTitle}" for offline viewing! 📥',
            ),
            backgroundColor: AppColors.midnightAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint('[VideoPlayerScreen] Download failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoProvider = ref.watch(videoPlayerProvider);
    final topInset = MediaQuery.of(context).viewPadding.top;
    final isWide = MediaQuery.of(context).size.width > 800;

    Widget playerArea = Stack(
      children: [
        // Main Video or Loading State
        MouseRegion(
          cursor: _showControls
              ? SystemMouseCursors.basic
              : SystemMouseCursors.none,
          onHover: (_) {
            if (!_showControls) {
              setState(() => _showControls = true);
              _startHideTimer();
            }
          },
          child: GestureDetector(
            onTap: _toggleControls,
            onDoubleTapDown: (details) {
              _startHideTimer();
              final screenWidth = MediaQuery.of(context).size.width;
              if (details.globalPosition.dx < screenWidth / 2) {
                ref
                    .read(videoPlayerProvider.notifier)
                    .seek(const Duration(seconds: -10));
              } else {
                ref
                    .read(videoPlayerProvider.notifier)
                    .seek(const Duration(seconds: 10));
              }
            },
            onVerticalDragStart: _onVerticalDragStart,
            onVerticalDragUpdate: (details) =>
                _onVerticalDragUpdate(details, videoProvider),
            onVerticalDragEnd: _onVerticalDragEnd,
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: videoProvider.isLoading
                    ? const CleverLoadingText()
                    : (videoProvider.videoController != null)
                    ? ExcludeSemantics(
                        child: Video(
                          controller: videoProvider.videoController!,
                          controls: NoVideoControls, // custom controls above
                        ),
                      )
                    : Text(
                        "Video unavailable",
                        style: GoogleFonts.inter(color: Colors.white70),
                      ),
              ),
            ),
          ),
        ),

        // Controls Overlay
        if (_showControls && !videoProvider.isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black45,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Header Bar
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 8, right: 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white,
                            size: 32,
                          ),
                          onPressed: () {
                            // If we're fullscreen, exit it first before popping
                            if (_isFullscreen) _toggleFullscreen();
                            context.pop();
                          },
                        ),
                        const Expanded(child: SizedBox()),

                        // Quality Selector
                        if (videoProvider.streams.isNotEmpty)
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.settings,
                              color: Colors.white,
                              size: 28,
                            ),
                            onSelected: (q) => ref
                                .read(videoPlayerProvider.notifier)
                                .changeQuality(q),
                            itemBuilder: (context) {
                              // Display all native resolutions formatted clearly
                              return videoProvider.streams.map((s) {
                                var q = s['quality'] as String? ?? '';
                                if (q.toLowerCase() == 'high') q = '1080p';
                                if (q.toLowerCase() == 'medium') q = '720p';
                                if (q.toLowerCase() == 'low') q = '360p';
                                final RegExp regExp = RegExp(r'\d+');
                                final match = regExp.firstMatch(q);
                                final label = match != null
                                    ? '${match.group(0)}p'
                                    : q;
                                return PopupMenuItem<String>(
                                  value: q,
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        // Speed Selector
                        PopupMenuButton<double>(
                          icon: const Icon(
                            Icons.speed,
                            color: Colors.white,
                            size: 28,
                          ),
                          initialValue: videoProvider.playbackSpeed,
                          onSelected: (speed) => ref
                              .read(videoPlayerProvider.notifier)
                              .setPlaybackSpeed(speed),
                          itemBuilder: (context) {
                            return [
                              0.25,
                              0.5,
                              0.75,
                              1.0,
                              1.25,
                              1.5,
                              1.75,
                              2.0,
                            ].map((s) {
                              return PopupMenuItem<double>(
                                value: s,
                                child: Text(
                                  '${s}x',
                                  style: TextStyle(
                                    fontWeight: s == videoProvider.playbackSpeed
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ],
                    ),
                  ),

                  // Center Play/Pause & Skip Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 36,
                        icon: const Icon(Icons.replay_10, color: Colors.white),
                        onPressed: () {
                          _startHideTimer();
                          ref
                              .read(videoPlayerProvider.notifier)
                              .seek(const Duration(seconds: -10));
                        },
                      ),
                      const SizedBox(width: 32),
                      GestureDetector(
                        onTap: () {
                          _startHideTimer();
                          if (videoProvider.player != null) {
                            videoProvider.player!.state.playing
                                ? videoProvider.player!.pause()
                                : videoProvider.player!.play();
                            setState(() {}); // Trigger icon update
                          }
                        },
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: AppColors.midnightAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            (videoProvider.player?.state.playing ?? false)
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.black,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),
                      IconButton(
                        iconSize: 36,
                        icon: const Icon(Icons.forward_10, color: Colors.white),
                        onPressed: () {
                          _startHideTimer();
                          ref
                              .read(videoPlayerProvider.notifier)
                              .seek(const Duration(seconds: 10));
                        },
                      ),
                    ],
                  ),

                  // Bottom Progress Seekbar
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 8,
                      left: 16,
                      right: 16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (videoProvider.player != null)
                          ExcludeSemantics(
                            child: StreamBuilder<Duration>(
                              stream: videoProvider.player!.stream.position,
                              builder: (context, snapshot) {
                                final position =
                                    snapshot.data ??
                                    videoProvider.player!.state.position;
                                final duration =
                                    videoProvider.player!.state.duration;
                                return Row(
                                  children: [
                                    Text(
                                      _formatDuration(position),
                                      style: GoogleFonts.inter(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Expanded(
                                      child: SliderTheme(
                                        data: const SliderThemeData(
                                          thumbShape: RoundSliderThumbShape(
                                            enabledThumbRadius: 6,
                                          ),
                                          trackHeight: 3,
                                          activeTrackColor:
                                              AppColors.midnightAccent,
                                          inactiveTrackColor: Colors.white24,
                                          thumbColor: AppColors.midnightAccent,
                                        ),
                                        child: Slider(
                                          value: position.inMilliseconds
                                              .toDouble(),
                                          max: duration.inMilliseconds
                                              .toDouble(),
                                          onChanged: (val) {
                                            videoProvider.player!.seek(
                                              Duration(
                                                milliseconds: val.toInt(),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(duration),
                                      style: GoogleFonts.inter(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        _isFullscreen
                                            ? Icons.fullscreen_exit
                                            : Icons.fullscreen,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        _startHideTimer();
                                        _toggleFullscreen();
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    if (!_isFullscreen) {
      playerArea = SafeArea(
        bottom: false,
        child: AspectRatio(aspectRatio: 16 / 9, child: playerArea),
      );
    }
    // We removed the Expanded(child: playerArea) for fullscreen because it's no longer inside a Column.

    // We removed the Expanded(child: playerArea) for fullscreen because it's no longer inside a Column.

    final metadataWidget = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            videoProvider.currentTitle,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.themeTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: context.themeCardColor,
                child: const Icon(Icons.person, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                videoProvider.currentUploader,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: context.themeMutedTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: _isDownloading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          value: _downloadProgress > 0
                              ? _downloadProgress
                              : null,
                          strokeWidth: 2.5,
                          color: AppColors.midnightAccent,
                        ),
                      )
                    : Icon(
                        Icons.download_rounded,
                        color: context.themeTextColor,
                      ),
                onPressed: () => _downloadVideo(videoProvider),
              ),
            ],
          ),
        ],
      ),
    );

    final relatedVideosSliverList = SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final video = videoProvider.relatedVideos[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                video['thumbnail'],
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) =>
                    Container(color: Colors.grey.withValues(alpha: 0.2)),
              ),
            ),
          ),
          title: Text(
            video['title'],
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: context.themeTextColor,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              "${video['uploader']} • ${video['views']}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: context.themeMutedTextColor,
              ),
            ),
          ),
          onTap: () {
            ref
                .read(videoPlayerProvider.notifier)
                .playVideo(video['id'], video['title'], video['uploader']);
          },
        );
      }, childCount: videoProvider.relatedVideos.length),
    );

    final upNextHeader = Padding(
      padding: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 24.0,
        bottom: 12.0,
      ),
      child: Text(
        "Up Next",
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: context.themeTextColor,
        ),
      ),
    );

    return FocusableActionDetector(
      focusNode: _focusNode,
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.space): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft):
            const DirectionalFocusIntent(TraversalDirection.left),
        LogicalKeySet(LogicalKeyboardKey.arrowRight):
            const DirectionalFocusIntent(TraversalDirection.right),
        LogicalKeySet(LogicalKeyboardKey.keyF): const ScrollIntent(
          direction: AxisDirection.up,
        ), // Hack intent map for F
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) {
            final isPlaying = videoProvider.player?.state.playing ?? false;
            isPlaying
                ? videoProvider.player?.pause()
                : videoProvider.player?.play();
            _startHideTimer();
            setState(() => _showControls = true);
            return null;
          },
        ),
        DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(
          onInvoke: (intent) {
            if (intent.direction == TraversalDirection.left) {
              ref
                  .read(videoPlayerProvider.notifier)
                  .seek(const Duration(seconds: -10));
            } else if (intent.direction == TraversalDirection.right) {
              ref
                  .read(videoPlayerProvider.notifier)
                  .seek(const Duration(seconds: 10));
            }
            _startHideTimer();
            setState(() => _showControls = true);
            return null;
          },
        ),
        ScrollIntent: CallbackAction<ScrollIntent>(
          onInvoke: (intent) {
            if (intent.direction == AxisDirection.up) {
              _toggleFullscreen();
            }
            _startHideTimer();
            setState(() => _showControls = true);
            return null;
          },
        ),
      },
      child: Material(
        color: _isFullscreen ? Colors.black : context.themeBackgroundColor,
        child: _isFullscreen
            ? playerArea
            : isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: playerArea),
                        SliverToBoxAdapter(child: metadataWidget),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Container(
                      color: context.themeCardColor.withValues(alpha: 0.3),
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(child: upNextHeader),
                          relatedVideosSliverList,
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  playerArea,
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [metadataWidget, upNextHeader],
                          ),
                        ),
                        relatedVideosSliverList,
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
