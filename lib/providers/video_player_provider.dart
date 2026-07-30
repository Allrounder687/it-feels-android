import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:miniplayer/miniplayer.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import '../services/backend_api_service.dart';
import '../services/local_stream_proxy.dart';

class VideoPlayerProvider extends ChangeNotifier {
  VideoPlayerController? videoController;
  
  bool isVideoActive = false;
  bool isLoading = false;
  bool isMuted = false;
  
  String currentVideoId = '';
  String currentTitle = '';
  String currentUploader = '';
  
  List<Map<String, dynamic>> streams = [];
  String selectedQuality = '720p'; // Default
  List<Map<String, dynamic>> relatedVideos = [];
  VoidCallback? onVideoStarted;

  double _volume = 0.5;
  double _brightness = 0.5;
  bool _isRecovering = false;

  VideoPlayerProvider() {
    _initSystemControls();
  }

  Future<void> _initSystemControls() async {
    try {
      _volume = await VolumeController.instance.getVolume();
    } catch (_) {
      _volume = 0.5;
    }
    try {
      _brightness = await ScreenBrightness().current;
    } catch (e) {
      debugPrint('[VideoPlayerProvider] Error initializing system controls: $e');
    }
  }

  /// Plays a video
  Future<void> playVideo(String videoId, String title, String uploader, {String? localPath, String? query, Duration? startPosition}) async {
    if (currentVideoId == videoId && videoController != null && videoController!.value.isInitialized) {
      // Fast resume without reloading network streams
      isVideoActive = true;
      if (startPosition != null) {
        await videoController!.seekTo(startPosition);
      }
      await videoController!.play();
      notifyListeners();
      return;
    }

    // Reset state
    isLoading = true;
    isVideoActive = true;
    currentVideoId = videoId;
    currentTitle = title;
    currentUploader = uploader;
    streams = [];
    relatedVideos = [];
    _recoveryAttempts = 0;
    notifyListeners();

    if (localPath != null && localPath.isNotEmpty) {
      // Offline Playback
      await _initPlayerWithFile(localPath, startPosition: startPosition);
      final results = await Future.wait([
        BackendApiService.getRelatedVideos(videoId),
      ]);
      relatedVideos = List<Map<String, dynamic>>.from(results[0] ?? []);
      isLoading = false;
      notifyListeners();
      return;
    }

    // Fetch streams and related videos in parallel
    final results = await Future.wait([
      BackendApiService.getVideoStreams(videoId, query: query),
      BackendApiService.getRelatedVideos(videoId, query: query),
    ]);

    final streamData = results[0] as Map<String, dynamic>;
    relatedVideos = List<Map<String, dynamic>>.from((results[1] as Iterable?) ?? []);
    
    streams = List<Map<String, dynamic>>.from(streamData['streams'] ?? []);
    
    if (streams.isNotEmpty) {
      _initializeStreamForQuality(selectedQuality, startPosition: startPosition);
    } else {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _initPlayerWithFile(String localPath, {Duration? startPosition}) async {
    try {
      await videoController?.dispose();
      videoController = VideoPlayerController.file(
        File(localPath),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await videoController!.initialize();
      if (startPosition != null) {
        await videoController!.seekTo(startPosition);
      }
      await videoController!.play();
    } catch (e) {
      debugPrint('[VideoPlayerProvider] Error playing offline file: $e');
    }
  }

  /// Initialize video controller for a specific quality
  Future<void> _initializeStreamForQuality(String targetQuality, {Duration? startPosition}) async {
    if (streams.isEmpty) return;

    isLoading = true;
    notifyListeners();

    final previousPosition = startPosition ?? videoController?.value.position ?? Duration.zero;
    final wasPlaying = videoController?.value.isPlaying ?? true;

    // Dispose old controller
    await videoController?.dispose();

    // Find the stream that matches the target quality, or fallback to the first (highest) available
    var selectedStream = streams.firstWhere(
      (s) => s['quality'] == targetQuality,
      orElse: () => streams.first,
    );
    
    selectedQuality = selectedStream['quality'];
    final streamUrl = selectedStream['url'] as String;
    final formatHint = streamUrl.contains('.m3u8') ? VideoFormat.hls : VideoFormat.other;
    
    // Route YouTube streams through local proxy to bypass ExoPlayer 403 / Header stripping
    final proxiedUrl = await LocalStreamProxy.getProxyUrl(streamUrl);
    
    videoController = VideoPlayerController.networkUrl(
      Uri.parse(proxiedUrl),
      formatHint: formatHint,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      // We still pass headers in case it's not proxied, though the proxy overrides them anyway
      httpHeaders: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36',
        'Referer': 'https://www.youtube.com/',
      },
    );
    
    try {
      await videoController!.initialize();
    } catch (e) {
      debugPrint('[VideoPlayerProvider] Error initializing video stream: $e');
      if (e.toString().contains('403') || e.toString().contains('Response code: 403')) {
        await _handleVideoPlaybackError(previousPosition, wasPlaying);
        return;
      }
    }

    videoController!.addListener(() {
      if (videoController != null && videoController!.value.hasError) {
        final err = videoController!.value.errorDescription;
        if (err != null && (err.contains('403') || err.contains('Response code: 403'))) {
          _handleVideoPlaybackError(videoController!.value.position, videoController!.value.isPlaying);
        }
      }
    });

    await videoController!.setVolume(isMuted ? 0.0 : 1.0);
    
    if (previousPosition != Duration.zero) {
      await videoController!.seekTo(previousPosition);
    }
    
    if (wasPlaying) {
      await videoController!.play();
    }

    isLoading = false;
    notifyListeners();
    onVideoStarted?.call();
  }

  int _recoveryAttempts = 0;

  /// Self-healing auto recovery for expired stream links (403 Forbidden)
  Future<void> _handleVideoPlaybackError(Duration position, bool wasPlaying) async {
    if (_isRecovering) return;
    if (_recoveryAttempts >= 2) {
      debugPrint('[VideoPlayerProvider] Max recovery attempts reached. Stopping auto-recovery.');
      return;
    }
    
    _isRecovering = true;
    _recoveryAttempts++;
    
    debugPrint('[VideoPlayerProvider] Expired stream (403 Forbidden) detected. Auto-recovering URL... Attempt: $_recoveryAttempts');
    try {
      BackendApiService.clearVideoStreamCache(currentVideoId);
      final freshData = await BackendApiService.getVideoStreams(currentVideoId, bypassCache: true);
      streams = List<Map<String, dynamic>>.from(freshData['streams'] ?? []);
      
      if (streams.isNotEmpty) {
        _isRecovering = false;
        await _initializeStreamForQuality(selectedQuality, startPosition: position);
      }
    } catch (e) {
      debugPrint('[VideoPlayerProvider] Auto-recovery failed: $e');
    } finally {
      _isRecovering = false;
    }
  }

  /// Change video quality
  Future<void> changeQuality(String quality) async {
    if (quality == selectedQuality) return;
    await _initializeStreamForQuality(quality);
  }

  /// Adjust brightness via swipe gesture
  void adjustBrightness(double delta) {
    _brightness += delta;
    _brightness = _brightness.clamp(0.0, 1.0);
    ScreenBrightness().setScreenBrightness(_brightness);
  }

  /// Adjust volume via swipe gesture
  void adjustVolume(double delta) {
    _volume += delta;
    _volume = _volume.clamp(0.0, 1.0);
    try {
      VolumeController.instance.setVolume(_volume);
    } catch (_) {}
  }

  /// Seek forward/backward
  void seek(Duration duration) {
    if (videoController == null) return;
    final currentPos = videoController!.value.position;
    var targetPos = currentPos + duration;
    var maxDur = videoController!.value.duration;
    if (targetPos < Duration.zero) targetPos = Duration.zero;
    if (targetPos > maxDur) targetPos = maxDur;
    videoController!.seekTo(targetPos);
  }

  /// Close the video player
  void closeVideo() {
    isVideoActive = false;
    videoController?.pause();
    videoController?.dispose();
    videoController = null;
    notifyListeners();
  }

  void setMuted(bool mute) {
    isMuted = mute;
    videoController?.setVolume(mute ? 0.0 : 1.0);
    notifyListeners();
  }

  @override
  void dispose() {
    videoController?.dispose();
    super.dispose();
  }
}
