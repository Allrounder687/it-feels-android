import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:miniplayer/miniplayer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_ext.dart';
import '../../providers/video_player_provider.dart';
import '../../services/storage_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _showControls = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isFullscreen = false;
  Timer? _hideTimer;
  
  // Variables for gesture tracking
  double? _dragStartX;
  double? _dragStartY;
  
  @override
  void dispose() {
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

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _onVerticalDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
    _dragStartY = details.globalPosition.dy;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, VideoPlayerProvider provider) {
    if (_dragStartX == null || _dragStartY == null) return;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final dy = details.primaryDelta ?? 0;
    
    // Negative dy means sliding UP (increase), positive means DOWN (decrease)
    final delta = -(dy / 200.0); // Sensitivity

    if (_dragStartX! < screenWidth / 2) {
      // Left side: Brightness
      provider.adjustBrightness(delta);
    } else {
      // Right side: Volume
      provider.adjustVolume(delta);
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _dragStartX = null;
    _dragStartY = null;
  }

  Future<void> _downloadVideo(VideoPlayerProvider provider) async {
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
            content: Text('Downloaded "${provider.currentTitle}" for offline viewing! 📥'),
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
    final videoProvider = Provider.of<VideoPlayerProvider>(context);
    final topInset = MediaQuery.of(context).viewPadding.top;

    Widget playerArea = Stack(
      children: [
                  // Video or Loading State
                  GestureDetector(
                    onTap: _toggleControls,
                    onDoubleTapDown: (details) {
                      _startHideTimer();
                      final screenWidth = MediaQuery.of(context).size.width;
                      if (details.globalPosition.dx < screenWidth / 2) {
                        videoProvider.seek(const Duration(seconds: -10));
                      } else {
                        videoProvider.seek(const Duration(seconds: 10));
                      }
                    },
                    onVerticalDragStart: _onVerticalDragStart,
                    onVerticalDragUpdate: (details) => _onVerticalDragUpdate(details, videoProvider),
                    onVerticalDragEnd: _onVerticalDragEnd,
                    child: Container(
                      color: Colors.black,
                      child: Center(
                        child: videoProvider.isLoading
                            ? const CircularProgressIndicator(color: AppColors.midnightAccent)
                            : (videoProvider.videoController != null && videoProvider.videoController!.value.isInitialized)
                                ? VideoPlayer(videoProvider.videoController!)
                                : Text(
                                    "Video unavailable",
                                    style: GoogleFonts.inter(color: Colors.white70),
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
                              padding: EdgeInsets.only(top: 8, left: 8, right: 16),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 32),
                                    onPressed: () {
                                      // Minimize
                                      videoProvider.miniplayerController.animateToHeight(state: PanelState.MIN);
                                    },
                                  ),
                                  Expanded(child: SizedBox()),
                                  
                                  // Quality Selector
                                  if (videoProvider.streams.isNotEmpty)
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.settings, color: Colors.white, size: 28),
                                      onSelected: (q) => videoProvider.changeQuality(q),
                                      itemBuilder: (context) => videoProvider.streams.map((s) => PopupMenuItem<String>(
                                        value: s['quality'],
                                        child: Text("${s['quality']} (MP4)"),
                                      )).toList(),
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
                                    videoProvider.seek(const Duration(seconds: -10));
                                  },
                                ),
                                const SizedBox(width: 32),
                                GestureDetector(
                                  onTap: () {
                                    _startHideTimer();
                                    if (videoProvider.videoController != null) {
                                      videoProvider.videoController!.value.isPlaying
                                          ? videoProvider.videoController!.pause()
                                          : videoProvider.videoController!.play();
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
                                      (videoProvider.videoController?.value.isPlaying ?? false) ? Icons.pause : Icons.play_arrow,
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
                                    videoProvider.seek(const Duration(seconds: 10));
                                  },
                                ),
                              ],
                            ),

                            // Bottom Progress Seekbar
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (videoProvider.videoController != null && videoProvider.videoController!.value.isInitialized)
                                    ValueListenableBuilder(
                                      valueListenable: videoProvider.videoController!,
                                      builder: (context, VideoPlayerValue value, child) {
                                        return Row(
                                          children: [
                                            Text(
                                              _formatDuration(value.position),
                                              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                                            ),
                                            Expanded(
                                              child: SliderTheme(
                                                data: SliderThemeData(
                                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                                  trackHeight: 3,
                                                  activeTrackColor: AppColors.midnightAccent,
                                                  inactiveTrackColor: Colors.white24,
                                                  thumbColor: AppColors.midnightAccent,
                                                ),
                                                child: Slider(
                                                  value: value.position.inMilliseconds.toDouble(),
                                                  max: value.duration.inMilliseconds.toDouble(),
                                                  onChanged: (val) {
                                                    videoProvider.videoController!.seekTo(Duration(milliseconds: val.toInt()));
                                                  },
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _formatDuration(value.duration),
                                              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
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
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: playerArea,
        ),
      );
    } else {
      playerArea = Expanded(child: playerArea);
    }

    return Material(
      color: _isFullscreen ? Colors.black : context.themeBackgroundColor,
      child: Column(
        children: [
          playerArea,
          if (!_isFullscreen)
            Expanded(
              child: CustomScrollView(
                slivers: [
                SliverToBoxAdapter(
                  child: Padding(
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
                              child: const Icon(Icons.person, size: 20), // Can replace with actual avatar URL if fetched
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
                            // Download Button
                            IconButton(
                              icon: _isDownloading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        value: _downloadProgress > 0 ? _downloadProgress : null,
                                        strokeWidth: 2.5,
                                        color: AppColors.midnightAccent,
                                      ),
                                    )
                                  : Icon(Icons.download_rounded, color: context.themeTextColor),
                              onPressed: () => _downloadVideo(videoProvider),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Up Next",
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.themeTextColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                
                // Related Videos List
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final video = videoProvider.relatedVideos[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(
                              video['thumbnail'],
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(color: Colors.grey.withValues(alpha: 0.2)),
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
                          // Play related video
                          videoProvider.playVideo(video['id'], video['title'], video['uploader']);
                        },
                      );
                    },
                    childCount: videoProvider.relatedVideos.length,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
