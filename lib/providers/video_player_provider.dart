import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:miniplayer/miniplayer.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import '../services/backend_api_service.dart';

class VideoPlayerProvider extends ChangeNotifier {
  VideoPlayerController? videoController;
  final MiniplayerController miniplayerController = MiniplayerController();
  
  bool isVideoActive = false;
  bool isLoading = false;
  
  String currentVideoId = '';
  String currentTitle = '';
  String currentUploader = '';
  
  List<Map<String, dynamic>> streams = [];
  String selectedQuality = '720p'; // Default
  List<Map<String, dynamic>> relatedVideos = [];

  double _volume = 0.5;
  double _brightness = 0.5;

  VideoPlayerProvider() {
    _initSystemControls();
  }

  Future<void> _initSystemControls() async {
    try {
      _volume = await VolumeController().getVolume();
      _brightness = await ScreenBrightness().current;
    } catch (e) {
      debugPrint('[VideoPlayerProvider] Error initializing system controls: $e');
    }
  }

  /// Plays a video and initializes the Miniplayer
  Future<void> playVideo(String videoId, String title, String uploader, {String? localPath}) async {
    // Reset state
    isLoading = true;
    isVideoActive = true;
    currentVideoId = videoId;
    currentTitle = title;
    currentUploader = uploader;
    streams = [];
    relatedVideos = [];
    notifyListeners();

    // Expand the miniplayer
    miniplayerController.animateToHeight(state: PanelState.MAX);

    if (localPath != null && localPath.isNotEmpty) {
      // Offline Playback
      await _initPlayerWithFile(localPath);
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
      BackendApiService.getVideoStreams(videoId),
      BackendApiService.getRelatedVideos(videoId),
    ]);

    final streamData = results[0] as Map<String, dynamic>;
    relatedVideos = List<Map<String, dynamic>>.from(results[1] ?? []);
    
    streams = List<Map<String, dynamic>>.from(streamData['streams'] ?? []);
    
    if (streams.isNotEmpty) {
      _initializeStreamForQuality(selectedQuality);
    } else {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _initPlayerWithFile(String localPath) async {
    try {
      await videoController?.dispose();
      videoController = VideoPlayerController.file(File(localPath));
      await videoController!.initialize();
      await videoController!.play();
    } catch (e) {
      debugPrint('[VideoPlayerProvider] Error playing offline file: $e');
    }
  }

  /// Initialize video controller for a specific quality
  Future<void> _initializeStreamForQuality(String targetQuality) async {
    if (streams.isEmpty) return;

    isLoading = true;
    notifyListeners();

    final previousPosition = videoController?.value.position ?? Duration.zero;
    final wasPlaying = videoController?.value.isPlaying ?? true;

    // Dispose old controller
    await videoController?.dispose();

    // Find the stream that matches the target quality, or fallback to the first (highest) available
    var selectedStream = streams.firstWhere(
      (s) => s['quality'] == targetQuality,
      orElse: () => streams.first,
    );
    
    selectedQuality = selectedStream['quality'];
    
    videoController = VideoPlayerController.networkUrl(Uri.parse(selectedStream['url']));
    await videoController!.initialize();
    
    if (previousPosition != Duration.zero) {
      await videoController!.seekTo(previousPosition);
    }
    
    if (wasPlaying) {
      videoController!.play();
    }

    isLoading = false;
    notifyListeners();
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
    VolumeController().setVolume(_volume);
  }

  /// Seek forward/backward
  void seek(Duration duration) {
    if (videoController == null) return;
    final currentPos = videoController!.value.position;
    final targetPos = currentPos + duration;
    videoController!.seekTo(targetPos.clamp(Duration.zero, videoController!.value.duration));
  }

  /// Close the video player
  void closeVideo() {
    isVideoActive = false;
    videoController?.pause();
    videoController?.dispose();
    videoController = null;
    notifyListeners();
  }

  @override
  void dispose() {
    videoController?.dispose();
    super.dispose();
  }
}
