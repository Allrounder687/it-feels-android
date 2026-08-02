import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:it_feels_music/services/backend_api_service.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

@immutable
class VideoPlayerState {
  final VideoPlayerController? videoController;
  final bool isVideoActive;
  final bool isLoading;
  final bool isMuted;
  final String currentVideoId;
  final String currentTitle;
  final String currentUploader;
  final List<Map<String, dynamic>> streams;
  final String selectedQuality;
  final List<Map<String, dynamic>> relatedVideos;
  final VoidCallback? onVideoStarted;
  final double volume;
  final double brightness;

  const VideoPlayerState({
    this.videoController,
    this.isVideoActive = false,
    this.isLoading = false,
    this.isMuted = false,
    this.currentVideoId = '',
    this.currentTitle = '',
    this.currentUploader = '',
    this.streams = const [],
    this.selectedQuality = '720p',
    this.relatedVideos = const [],
    this.onVideoStarted,
    this.volume = 0.5,
    this.brightness = 0.5,
  });

  VideoPlayerState copyWith({
    VideoPlayerController? videoController,
    bool clearVideoController = false,
    bool? isVideoActive,
    bool? isLoading,
    bool? isMuted,
    String? currentVideoId,
    String? currentTitle,
    String? currentUploader,
    List<Map<String, dynamic>>? streams,
    String? selectedQuality,
    List<Map<String, dynamic>>? relatedVideos,
    VoidCallback? onVideoStarted,
    double? volume,
    double? brightness,
  }) {
    return VideoPlayerState(
      videoController: clearVideoController ? null : (videoController ?? this.videoController),
      isVideoActive: isVideoActive ?? this.isVideoActive,
      isLoading: isLoading ?? this.isLoading,
      isMuted: isMuted ?? this.isMuted,
      currentVideoId: currentVideoId ?? this.currentVideoId,
      currentTitle: currentTitle ?? this.currentTitle,
      currentUploader: currentUploader ?? this.currentUploader,
      streams: streams ?? this.streams,
      selectedQuality: selectedQuality ?? this.selectedQuality,
      relatedVideos: relatedVideos ?? this.relatedVideos,
      onVideoStarted: onVideoStarted ?? this.onVideoStarted,
      volume: volume ?? this.volume,
      brightness: brightness ?? this.brightness,
    );
  }
}

class VideoPlayerNotifier extends Notifier<VideoPlayerState> {
  void setOnVideoStarted(VoidCallback? callback) {
    state = state.copyWith(onVideoStarted: callback);
  }

  bool _isRecovering = false;
  int _recoveryAttempts = 0;

  @override
  VideoPlayerState build() {
    _initSystemControls();
    ref.onDispose(() {
      state.videoController?.dispose();
    });
    return const VideoPlayerState();
  }

  Future<void> _initSystemControls() async {
    double vol = 0.5;
    double bright = 0.5;
    try {
      vol = await VolumeController.instance.getVolume();
    } catch (_) {}
    try {
      bright = await ScreenBrightness().current;
    } catch (_) {}
    state = state.copyWith(volume: vol, brightness: bright);
  }

  Future<void> playVideo(String videoId, String title, String uploader, {String? localPath, String? query, Duration? startPosition}) async {
    if (state.currentVideoId == videoId && state.videoController != null && state.videoController!.value.isInitialized) {
      state = state.copyWith(isVideoActive: true);
      if (startPosition != null) {
        await state.videoController!.seekTo(startPosition);
      }
      await state.videoController!.play();
      return;
    }

    _recoveryAttempts = 0;
    
    // EXPLICITLY KILL OLD VIDEO TO PREVENT GLITCH
    state.videoController?.pause();
    state.videoController?.dispose();

    // FORCE PAUSE AUDIO PLAYER WHEN STARTING A VIDEO
    ref.read(audioPlayerProvider.notifier).pause();

    state = state.copyWith(
      isLoading: true,
      isVideoActive: true,
      currentVideoId: videoId,
      currentTitle: title,
      currentUploader: uploader,
      streams: const [],
      relatedVideos: const [],
      clearVideoController: true, // Wipe the old controller safely
    );

    if (localPath != null && localPath.isNotEmpty) {
      await _initPlayerWithFile(localPath, startPosition: startPosition);
      final results = await Future.wait([
        BackendApiService.getRelatedVideos(videoId),
      ]);
      state = state.copyWith(
        relatedVideos: List<Map<String, dynamic>>.from(results[0] ?? []),
        isLoading: false,
      );
      return;
    }

    final results = await Future.wait([
      BackendApiService.getVideoStreams(videoId, query: query),
      BackendApiService.getRelatedVideos(videoId, query: query),
    ]);

    final streamData = results[0] as Map<String, dynamic>;
    final relVideos = List<Map<String, dynamic>>.from((results[1] as Iterable?) ?? []);
    final streamList = List<Map<String, dynamic>>.from(streamData['streams'] ?? []);

    state = state.copyWith(
      relatedVideos: relVideos,
      streams: streamList,
    );
    
    if (streamList.isNotEmpty) {
      _initializeStreamForQuality(state.selectedQuality, startPosition: startPosition);
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _initPlayerWithFile(String localPath, {Duration? startPosition}) async {
    try {
      await state.videoController?.dispose();
      final controller = VideoPlayerController.file(
        File(localPath),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await controller.initialize();
      if (startPosition != null) {
        await controller.seekTo(startPosition);
      }
      await controller.play();
      state = state.copyWith(videoController: controller);
    } catch (e) {
      debugPrint('[VideoPlayerNotifier] Error playing offline file: $e');
    }
  }

  Future<void> _initializeStreamForQuality(String targetQuality, {Duration? startPosition}) async {
    if (state.streams.isEmpty) return;

    state = state.copyWith(isLoading: true);

    final previousPosition = startPosition ?? state.videoController?.value.position ?? Duration.zero;
    final wasPlaying = state.videoController?.value.isPlaying ?? true;

    await state.videoController?.dispose();

    var selectedStream = state.streams.firstWhere(
      (s) => s['quality'] == targetQuality,
      orElse: () => state.streams.first,
    );
    
    final quality = selectedStream['quality'];
    final streamUrl = selectedStream['url'] as String;
    final formatHint = streamUrl.contains('.m3u8') ? VideoFormat.hls : VideoFormat.other;
    
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(streamUrl),
      formatHint: formatHint,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      httpHeaders: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36',
        'Referer': 'https://www.youtube.com/',
      },
    );
    
    try {
      await controller.initialize();
    } catch (e) {
      debugPrint('[VideoPlayerNotifier] Error initializing video stream: $e');
      if (e.toString().contains('403') || e.toString().contains('Response code: 403')) {
        await _handleVideoPlaybackError(previousPosition, wasPlaying);
        return;
      }
    }

    controller.addListener(() {
      if (controller.value.hasError) {
        final err = controller.value.errorDescription;
        if (err != null && (err.contains('403') || err.contains('Response code: 403'))) {
          _handleVideoPlaybackError(controller.value.position, controller.value.isPlaying);
        }
      }
    });

    await controller.setVolume(state.isMuted ? 0.0 : 1.0);
    
    if (previousPosition != Duration.zero) {
      await controller.seekTo(previousPosition);
    }
    
    if (wasPlaying) {
      await controller.play();
    }

    state = state.copyWith(
      videoController: controller,
      selectedQuality: quality,
      isLoading: false,
    );
    state.onVideoStarted?.call();
  }

  Future<void> _handleVideoPlaybackError(Duration position, bool wasPlaying) async {
    if (_isRecovering) return;
    if (_recoveryAttempts >= 2) return;
    
    _isRecovering = true;
    _recoveryAttempts++;
    
    try {
      BackendApiService.clearVideoStreamCache(state.currentVideoId);
      final freshData = await BackendApiService.getVideoStreams(state.currentVideoId, bypassCache: true);
      final freshStreams = List<Map<String, dynamic>>.from(freshData['streams'] ?? []);
      state = state.copyWith(streams: freshStreams);
      
      if (freshStreams.isNotEmpty) {
        _isRecovering = false;
        await _initializeStreamForQuality(state.selectedQuality, startPosition: position);
      }
    } catch (e) {
      debugPrint('[VideoPlayerNotifier] Auto-recovery failed: $e');
    } finally {
      _isRecovering = false;
    }
  }

  Future<void> changeQuality(String quality) async {
    if (quality == state.selectedQuality) return;
    await _initializeStreamForQuality(quality);
  }

  void adjustBrightness(double delta) {
    final newB = (state.brightness + delta).clamp(0.0, 1.0);
    ScreenBrightness().setScreenBrightness(newB);
    state = state.copyWith(brightness: newB);
  }

  void adjustVolume(double delta) {
    final newV = (state.volume + delta).clamp(0.0, 1.0);
    try {
      VolumeController.instance.setVolume(newV);
    } catch (_) {}
    state = state.copyWith(volume: newV);
  }

  void seek(Duration duration) {
    if (state.videoController == null) return;
    final currentPos = state.videoController!.value.position;
    var targetPos = currentPos + duration;
    var maxDur = state.videoController!.value.duration;
    if (targetPos < Duration.zero) targetPos = Duration.zero;
    if (targetPos > maxDur) targetPos = maxDur;
    state.videoController!.seekTo(targetPos);
  }

  void closeVideo() {
    state.videoController?.pause();
    state.videoController?.dispose();
    state = state.copyWith(
      isVideoActive: false,
      videoController: null,
    );
  }

  void setMuted(bool mute) {
    state.videoController?.setVolume(mute ? 0.0 : 1.0);
    state = state.copyWith(isMuted: mute);
  }
}

typedef VideoPlayerProvider = VideoPlayerNotifier;
