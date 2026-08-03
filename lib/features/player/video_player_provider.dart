import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:it_feels_music/services/backend_api_service.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

@immutable
class VideoPlayerState {
  final Player? player;
  final VideoController? videoController;
  final bool isVideoActive;
  final bool isLoading;
  final bool isMuted;
  final String currentVideoId;
  final String currentTitle;
  final String currentUploader;
  final List<Map<String, dynamic>> streams;
  final String audioUrl;
  final String selectedQuality;
  final List<Map<String, dynamic>> relatedVideos;
  final VoidCallback? onVideoStarted;
  final double volume;
  final double brightness;

  const VideoPlayerState({
    this.player,
    this.videoController,
    this.isVideoActive = false,
    this.isLoading = false,
    this.isMuted = false,
    this.currentVideoId = '',
    this.currentTitle = '',
    this.currentUploader = '',
    this.streams = const [],
    this.audioUrl = '',
    this.selectedQuality = '720p',
    this.relatedVideos = const [],
    this.onVideoStarted,
    this.volume = 0.5,
    this.brightness = 0.5,
  });

  VideoPlayerState copyWith({
    Player? player,
    VideoController? videoController,
    bool clearVideoController = false,
    bool? isVideoActive,
    bool? isLoading,
    bool? isMuted,
    String? currentVideoId,
    String? currentTitle,
    String? currentUploader,
    List<Map<String, dynamic>>? streams,
    String? audioUrl,
    String? selectedQuality,
    List<Map<String, dynamic>>? relatedVideos,
    VoidCallback? onVideoStarted,
    double? volume,
    double? brightness,
  }) {
    return VideoPlayerState(
      player: clearVideoController ? null : (player ?? this.player),
      videoController: clearVideoController ? null : (videoController ?? this.videoController),
      isVideoActive: isVideoActive ?? this.isVideoActive,
      isLoading: isLoading ?? this.isLoading,
      isMuted: isMuted ?? this.isMuted,
      currentVideoId: currentVideoId ?? this.currentVideoId,
      currentTitle: currentTitle ?? this.currentTitle,
      currentUploader: currentUploader ?? this.currentUploader,
      streams: streams ?? this.streams,
      audioUrl: audioUrl ?? this.audioUrl,
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
      state.player?.dispose();
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
    if (state.currentVideoId == videoId && state.player != null) {
      state = state.copyWith(isVideoActive: true);
      if (startPosition != null) {
        await state.player!.seek(startPosition);
      }
      await state.player!.play();
      return;
    }

    _recoveryAttempts = 0;

    // RESET mute state so videos played from the Video section or Search
    // always start with audio enabled, regardless of NowPlayingScreen's
    // previous toggle state.
    state = state.copyWith(isMuted: false);

    // EXPLICITLY KILL OLD VIDEO TO PREVENT GLITCH
    await state.player?.pause();
    await state.player?.dispose();

    // FORCE PAUSE AUDIO PLAYER WHEN STARTING A VIDEO
    ref.read(audioPlayerProvider.notifier).pause();

    state = state.copyWith(
      isLoading: true,
      isVideoActive: true,
      currentVideoId: videoId,
      currentTitle: title,
      currentUploader: uploader,
      streams: const [],
      audioUrl: '',
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
    final audioUrl = streamData['audioUrl'] as String? ?? '';

    state = state.copyWith(
      relatedVideos: relVideos,
      streams: streamList,
      audioUrl: audioUrl,
    );
    
    if (streamList.isNotEmpty) {
      _initializeStreamForQuality(state.selectedQuality, startPosition: startPosition);
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _initPlayerWithFile(String localPath, {Duration? startPosition}) async {
    try {
      await state.player?.dispose();
      
      final player = Player();
      final controller = VideoController(player);
      
      await player.open(Media(localPath), play: true);
      
      if (startPosition != null) {
        await player.seek(startPosition);
      }
      state = state.copyWith(player: player, videoController: controller);
    } catch (e) {
      debugPrint('[VideoPlayerNotifier] Error playing offline file: $e');
    }
  }

  Future<void> _initializeStreamForQuality(String targetQuality, {Duration? startPosition}) async {
    if (state.streams.isEmpty) return;

    state = state.copyWith(isLoading: true);

    final previousPosition = startPosition ?? state.player?.state.position ?? Duration.zero;
    final wasPlaying = state.player?.state.playing ?? true;

    await state.player?.dispose();

    var selectedStream = state.streams.firstWhere(
      (s) => s['quality'] == targetQuality,
      orElse: () => state.streams.first,
    );
    
    final quality = selectedStream['quality'];
    final streamUrl = selectedStream['url'] as String;
    
    final player = Player();
    final controller = VideoController(player);
    
    try {
      await player.open(Media(streamUrl), play: false);
      
      // If it's a separated video-only stream, we need to attach the audio stream
      if (selectedStream['videoOnly'] == true && state.audioUrl.isNotEmpty) {
        await player.setAudioTrack(AudioTrack.uri(state.audioUrl, title: 'Original', language: 'en'));
      }
      
    } catch (e) {
      debugPrint('[VideoPlayerNotifier] Error initializing video stream: $e');
      if (e.toString().contains('403') || e.toString().contains('Response code: 403')) {
        await _handleVideoPlaybackError(previousPosition, wasPlaying);
        return;
      }
    }

    player.stream.error.listen((event) {
      final err = event.toString();
      if (err.contains('403') || err.contains('Response code: 403')) {
        _handleVideoPlaybackError(player.state.position, player.state.playing);
      }
    });

    await player.setVolume(state.isMuted ? 0.0 : 100.0);
    
    if (previousPosition != Duration.zero) {
      await player.seek(previousPosition);
    }
    
    if (wasPlaying) {
      await player.play();
    }

    state = state.copyWith(
      player: player,
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
    if (state.player == null) return;
    final currentPos = state.player!.state.position;
    var targetPos = currentPos + duration;
    var maxDur = state.player!.state.duration;
    if (targetPos < Duration.zero) targetPos = Duration.zero;
    if (targetPos > maxDur) targetPos = maxDur;
    state.player!.seek(targetPos);
  }

  void closeVideo() {
    state.player?.pause();
    state.player?.dispose();
    state = state.copyWith(
      isVideoActive: false,
      clearVideoController: true,
    );
  }

  void setMuted(bool mute) {
    state.player?.setVolume(mute ? 0.0 : 100.0);
    state = state.copyWith(isMuted: mute);
  }
}

typedef VideoPlayerProvider = VideoPlayerNotifier;
