import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_ext.dart';
import '../../providers/audio_player_provider.dart';
import '../../services/backend_api_service.dart';
import '../../services/storage_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoId;
  final String title;
  final String uploader;
  final String? initialUrl;

  const VideoPlayerScreen({
    super.key,
    required this.videoId,
    required this.title,
    required this.uploader,
    this.initialUrl,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _showControls = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  List<Map<String, dynamic>> _streams = [];
  String _selectedQuality = '720p';
  String _currentVideoTitle = '';

  @override
  void initState() {
    super.initState();
    _currentVideoTitle = widget.title;

    // Force landscape mode for immersive video experience
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);

    // Pause audio player while watching video
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final playerProvider = Provider.of<AudioPlayerProvider>(context, listen: false);
      if (playerProvider.isPlaying) {
        playerProvider.togglePlayPause();
      }
    });

    _initVideoPlayer();
  }

  Future<void> _initVideoPlayer({String? targetUrl}) async {
    setState(() => _isLoading = true);

    try {
      String streamUrl = targetUrl ?? widget.initialUrl ?? '';

      if (streamUrl.isEmpty) {
        final videoData = await BackendApiService.getVideoStreams(widget.videoId);
        _currentVideoTitle = videoData['title'] ?? widget.title;
        final streamsList = videoData['streams'] as List<dynamic>? ?? [];

        _streams = streamsList.map((s) => Map<String, dynamic>.from(s)).toList();

        if (_streams.isNotEmpty) {
          // Select 720p or highest available stream
          final target = _streams.firstWhere(
            (s) => s['quality'] == '720p' || s['quality'] == '1080p',
            orElse: () => _streams.first,
          );
          streamUrl = target['url'] ?? '';
          _selectedQuality = target['quality'] ?? '720p';
        }
      }

      if (streamUrl.isNotEmpty) {
        _controller?.dispose();
        _controller = VideoPlayerController.networkUrl(Uri.parse(streamUrl));
        await _controller!.initialize();
        await _controller!.play();
        _controller!.addListener(_onControllerUpdate);
      }
    } catch (e) {
      debugPrint('[VideoPlayerScreen] Initialization error: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _seekRelative(int seconds) {
    if (_controller != null && _controller!.value.isInitialized) {
      final current = _controller!.value.position;
      final target = current + Duration(seconds: seconds);
      _controller!.seekTo(target.clamp(Duration.zero, _controller!.value.duration));
    }
  }

  Future<void> _downloadVideo() async {
    if (_streams.isEmpty || _isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final streamUrl = _streams.firstWhere(
        (s) => s['quality'] == _selectedQuality,
        orElse: () => _streams.first,
      )['url'];

      if (streamUrl == null) return;

      final dir = await getApplicationDocumentsDirectory();
      final videoDir = Directory('${dir.path}/downloaded_videos');
      if (!videoDir.existsSync()) videoDir.createSync(recursive: true);

      final cleanId = widget.videoId.replaceAll('youtube:', '');
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

      // Save metadata to storage service
      await StorageService.saveDownloadedVideo({
        'id': widget.videoId,
        'title': _currentVideoTitle,
        'uploader': widget.uploader,
        'localPath': filePath,
        'quality': _selectedQuality,
        'addedAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded "$_currentVideoTitle" for offline viewing! 📥'),
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
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();

    // Reset preferred orientation to portrait
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final topInset = MediaQuery.of(context).viewPadding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            // Video Player Center Area
            GestureDetector(
              onTap: _toggleControls,
              onDoubleTapDown: (details) {
                final screenWidth = MediaQuery.of(context).size.width;
                if (details.globalPosition.dx < screenWidth / 2) {
                  _seekRelative(-10); // Rewind 10s
                } else {
                  _seekRelative(10); // Fast Forward 10s
                }
              },
              child: Center(
                child: _isLoading
                    ? const CircularProgressIndicator(color: AppColors.midnightAccent)
                    : (_controller != null && _controller!.value.isInitialized)
                        ? AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
                          )
                        : Text(
                            "Video unavailable or format restricted",
                            style: GoogleFonts.inter(color: Colors.white70),
                          ),
              ),
            ),

            // Controls Overlay
            if (_showControls && !_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black45,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Header Bar
                      Padding(
                        padding: EdgeInsets.only(
                          top: topInset + 12,
                          left: 20,
                          right: 20,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _currentVideoTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    widget.uploader,
                                    style: GoogleFonts.inter(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Download Button
                            IconButton(
                              icon: _isDownloading
                                  ? SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        value: _downloadProgress > 0 ? _downloadProgress : null,
                                        strokeWidth: 2.5,
                                        color: AppColors.midnightAccent,
                                      ),
                                    )
                                  : const Icon(Icons.file_download, color: Colors.white),
                              onPressed: _downloadVideo,
                            ),

                            // Quality Selector Menu
                            if (_streams.isNotEmpty)
                              PopupMenuButton<String>(
                                icon: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _selectedQuality,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                onSelected: (q) {
                                  final match = _streams.firstWhere(
                                    (s) => s['quality'] == q,
                                    orElse: () => _streams.first,
                                  );
                                  setState(() => _selectedQuality = q);
                                  _initVideoPlayer(targetUrl: match['url']);
                                },
                                itemBuilder: (context) => _streams
                                    .map(
                                      (s) => PopupMenuItem<String>(
                                        value: s['quality'],
                                        child: Text(
                                          "${s['quality']} (MP4)",
                                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    )
                                    .toList(),
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
                            onPressed: () => _seekRelative(-10),
                          ),
                          const SizedBox(width: 32),
                          GestureDetector(
                            onTap: () {
                              if (_controller != null) {
                                _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
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
                                (_controller?.value.isPlaying ?? false) ? Icons.pause : Icons.play_arrow,
                                color: Colors.black,
                                size: 36,
                              ),
                            ),
                          ),
                          const SizedBox(width: 32),
                          IconButton(
                            iconSize: 36,
                            icon: const Icon(Icons.forward_10, color: Colors.white),
                            onPressed: () => _seekRelative(10),
                          ),
                        ],
                      ),

                      // Bottom Progress Seekbar
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: bottomInset + 16,
                          left: 24,
                          right: 24,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_controller != null && _controller!.value.isInitialized)
                              Row(
                                children: [
                                  Text(
                                    _formatDuration(_controller!.value.position),
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
                                        value: _controller!.value.position.inMilliseconds.toDouble(),
                                        max: _controller!.value.duration.inMilliseconds.toDouble(),
                                        onChanged: (val) {
                                          _controller!.seekTo(Duration(milliseconds: val.toInt()));
                                        },
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(_controller!.value.duration),
                                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
