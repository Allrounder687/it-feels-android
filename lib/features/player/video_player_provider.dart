import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/features/social/room_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:it_feels_music/features/player/active_media_provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:it_feels_music/services/backend_api_service.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/settings/settings_provider.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';

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
  final double playbackSpeed;
  final String? currentRoomId;
  final bool isHost;
  final bool allowGuestControl;

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
    this.playbackSpeed = 1.0,
    this.currentRoomId,
    this.isHost = false,
    this.allowGuestControl = false,
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
    double? playbackSpeed,
    String? currentRoomId,
    bool? isHost,
    bool? allowGuestControl,
    bool clearRoom = false,
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
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      currentRoomId: clearRoom ? null : (currentRoomId ?? this.currentRoomId),
      isHost: clearRoom ? false : (isHost ?? this.isHost),
      allowGuestControl: clearRoom ? false : (allowGuestControl ?? this.allowGuestControl),
    );
  }
}

class VideoPlayerNotifier extends Notifier<VideoPlayerState> {
  void setOnVideoStarted(VoidCallback? callback) {
    state = state.copyWith(onVideoStarted: callback);
  }

  bool _isRecovering = false;
  int _recoveryAttempts = 0;
  
  Timer? _hostSyncTimer;
  StreamSubscription<DatabaseEvent>? _roomSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  @override
  VideoPlayerState build() {
    _initSystemControls();
    
    // React to external audio player state changes (like Notification/Headset controls)
    ref.listen(audioPlayerProvider, (previous, current) {
      if (previous?.currentSong?.id != current.currentSong?.id && current.currentSong != null) {
        // Song has changed in the audio player (e.g. skipped track). 
        // We MUST kill the video player to prevent dual-audio overlapping!
        if (state.isVideoActive || state.player != null) {
          closeVideo();
        }
        return;
      }

      final settings = ref.read(settingsProvider);
      final isSameSong = current.currentSong != null && 
                         (state.currentVideoId == current.currentSong!.id || 
                          state.currentVideoId == 'search:${current.currentSong!.id}');
      
      final isSynced = !settings.useVideoAudioSource && isSameSong;
      final isCompeting = settings.useVideoAudioSource || !isSameSong;

      if (current.isPlaying && !(previous?.isPlaying ?? false)) {
        if (isCompeting && state.isVideoActive && state.player != null && state.player!.state.playing) {
          pauseVideo();
        } else if (isSynced && state.isVideoActive && state.player != null && !state.player!.state.playing) {
          // Force perfect sync by seeking the video to the audio's exact position before playing
          state.player!.seek(current.position);
          state.player!.play();
        }
      } else if (!current.isPlaying && (previous?.isPlaying ?? false)) {
        if (isSynced && state.isVideoActive && state.player != null && state.player!.state.playing) {
          pauseVideo();
        }
      }
    });

    ref.onDispose(() {
      _hostSyncTimer?.cancel();
      _roomSubscription?.cancel();
      _positionSubscription?.cancel();
      state.player?.dispose();
    });
    final defaultQuality = ref.read(settingsProvider).defaultVideoQuality;
    return VideoPlayerState(selectedQuality: defaultQuality);
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

  Future<void> setPlaybackSpeed(double speed) async {
    try {
      await state.player?.setRate(speed);
      state = state.copyWith(playbackSpeed: speed);
    } catch (e) {
      debugPrint('[VideoPlayerNotifier] Error setting playback speed: $e');
    }
  }

  void startVideoRoom(String roomId, Map<String, dynamic> videoDetails, {bool isHost = true}) {
    state = state.copyWith(
      currentRoomId: roomId,
      isHost: isHost,
      allowGuestControl: true, // We start with this on by default based on UI flow
    );
    playVideo(
      videoDetails['id'] ?? '',
      videoDetails['title'] ?? 'Unknown',
      videoDetails['uploader'] ?? 'YouTube',
    );
  }

  void joinVideoRoom(String roomId) {
    state = state.copyWith(
      currentRoomId: roomId,
      isHost: false,
      allowGuestControl: true,
    );
    _initGuestRoomSync(roomId);
  }

  Future<void> playVideo(String videoId, String title, String uploader, {String? localPath, String? query, Duration? startPosition, bool isBackgroundHandoff = false}) async {
    if (state.currentVideoId == videoId && state.player != null) {
      state = state.copyWith(isVideoActive: true);
      if (startPosition != null) {
        await state.player!.seek(startPosition);
      }
      await state.player!.play();
      
      
      // Notify UI that video is ready, allowing UI to pause audio perfectly on time
      state.onVideoStarted?.call();
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

    // Handoff logic now lives in the UI (NowPlayingScreen) via onVideoStarted callback,
    // so we do not forcefully kill audio_service here. This enables seamless cross-fades!
    
    ref.read(activeMediaProvider.notifier).setActiveMedia(ActiveMediaType.video);

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

    // Fetch Stream first for instant playback
    final streamData = await BackendApiService.getVideoStreams(videoId, query: query);
    
    // ABORT if the user changed songs while we were fetching the streams!
    if (state.currentVideoId != videoId) return;

    final streamList = List<Map<String, dynamic>>.from(streamData['streams'] ?? []);
    final audioUrl = streamData['audioUrl'] as String? ?? '';

    state = state.copyWith(
      streams: streamList,
      audioUrl: audioUrl,
    );
    
    // Fire off related videos asynchronously so it doesn't block playback
    BackendApiService.getRelatedVideos(videoId, query: query).then((relVideos) {
      if (state.currentVideoId == videoId) {
        state = state.copyWith(
          relatedVideos: List<Map<String, dynamic>>.from(relVideos ?? []),
        );
      }
    });
    
    if (streamList.isNotEmpty) {
      if (isBackgroundHandoff) {
        state = state.copyWith(selectedQuality: '360p');
      }
      _initializeStreamForQuality(state.selectedQuality, startPosition: startPosition, isBackgroundHandoff: isBackgroundHandoff);
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _initPlayerWithFile(String localPath, {Duration? startPosition}) async {
    try {
      await state.player?.dispose();
      
      final settings = ref.read(settingsProvider);
      
      final player = Player(configuration: const PlayerConfiguration(pitch: false, vo: 'gpu', bufferSize: 64 * 1024 * 1024));
      final controller = VideoController(player);
      
      final media = Media(
        localPath,
        extras: {
          'vd-lavc-threads': Platform.numberOfProcessors.toString(),
          'hwdec': Platform.isWindows ? 'auto-copy' : 'auto',
        },
      );
      
      await player.open(media, play: true);
      await player.setRate(state.playbackSpeed);
      
      if (startPosition != null) {
        await player.seek(startPosition);
      }
      state = state.copyWith(player: player, videoController: controller);
    } catch (e) {
      debugPrint('[VideoPlayerNotifier] Error playing offline file: $e');
    }
  }

  Future<void> _initializeStreamForQuality(String targetQuality, {Duration? startPosition, bool isBackgroundHandoff = false}) async {
    if (state.streams.isEmpty) return;

    state = state.copyWith(isLoading: true);

    Duration syncPosition = startPosition ?? state.player?.state.position ?? Duration.zero;
    
    // The fetch might have taken seconds. If this is a handoff, we MUST grab the real-time 
    // audio position right before creating the player to prevent a massive desync!
    if (isBackgroundHandoff) {
      final audioProv = ref.read(audioPlayerProvider);
      if (audioProv.isPlaying) {
        syncPosition = audioProv.position;
      }
    }

    final previousPosition = syncPosition;
    final wasPlaying = state.player?.state.playing ?? true;

    await state.player?.dispose();

    var selectedStream = state.streams.firstWhere(
      (s) => s['quality'] == targetQuality,
      orElse: () {
        int parseQ(String q) => int.tryParse(q.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final target = parseQ(targetQuality);
        var best = state.streams.first;
        var minDiff = 999999;
        for (var stream in state.streams) {
          final diff = (parseQ(stream['quality'] as String? ?? '') - target).abs();
          if (diff < minDiff) {
            minDiff = diff;
            best = stream;
          }
        }
        return best;
      },
    );
    
    final quality = selectedStream['quality'];
    final streamUrl = selectedStream['url'] as String;
    
    final settings = ref.read(settingsProvider);
    
    final player = Player(
      configuration: const PlayerConfiguration(
        pitch: false, 
        vo: 'gpu', 
        bufferSize: 128 * 1024 * 1024, // 128MB for 4K/8K safety
      )
    );
    final controller = VideoController(player);
    
    try {
      final media = Media(
        streamUrl,
        extras: {
          'start': (previousPosition.inMilliseconds / 1000).toString(),
          'demuxer-max-bytes': '128000000',
          'cache-pause': 'no',
          'hwdec': Platform.isWindows ? 'auto-copy' : 'auto', // Force Hardware Decoding via GPU
          'vd-lavc-threads': Platform.numberOfProcessors.toString(), // Utilize all available CPU cores
        },
      );
      
      await player.open(media, play: false);
      
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

    final audioProvider = ref.read(audioPlayerProvider);
    final isSameSong = audioProvider.currentSong != null && 
                       (state.currentVideoId == audioProvider.currentSong!.id || 
                        state.currentVideoId == 'search:${audioProvider.currentSong!.id}');
    final isMutedCanvas = !settings.useVideoAudioSource && isSameSong;

    await player.setVolume((state.isMuted || isMutedCanvas) ? 0.0 : 100.0);
    await player.setRate(state.playbackSpeed);
    
    if (wasPlaying) {
      await player.play();
    }
    
    if (previousPosition != Duration.zero) {
      // Execute the seek immediately after play. Modern media_kit natively queues the seek
      // if the demuxer isn't ready. This removes the catastrophic 4-second blocking delay 
      // that was destroying the audio-video crossfade sync.
      await player.seek(previousPosition);
    }

    state = state.copyWith(
      player: player,
      videoController: controller,
      selectedQuality: quality,
      isLoading: false,
    );
    state.onVideoStarted?.call();
    
    // Initialize room sync if we are in a room
    if (state.currentRoomId != null) {
      _initRoomSync();
    }
  }

  void _initRoomSync() {
    _hostSyncTimer?.cancel();
    _positionSubscription?.cancel();
    
    if (state.isHost) {
      _hostSyncTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (state.player == null) return;
        locator<RoomService>().updateVideoRoomState(
          state.currentRoomId!,
          {
            'id': state.currentVideoId,
            'title': state.currentTitle,
            'uploader': state.currentUploader,
            'thumbnail': '',
          },
          state.player!.state.position,
          state.player!.state.playing,
        );
      });
    } else {
      // If we are a guest but have control, we can also sync up
      _positionSubscription = state.player?.stream.position.listen((pos) {
        // Debounce or send only when user explicitly seeks/pauses? 
        // For audio rooms, guests just listen. Here the user wants "ability to give control to others".
        // Let's implement full control later, for now we will just let guests listen.
      });
    }
  }

  void _initGuestRoomSync(String roomId) {
    _roomSubscription?.cancel();
    _roomSubscription = locator<RoomService>().listenToRoom(roomId).listen((event) {
      if (event.snapshot.value == null) {
        closeVideo(); // Room ended
        return;
      }
      try {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        if (data['type'] == 'video') {
          final isPlaying = data['isPlaying'] ?? false;
          final positionMs = data['positionMs'] ?? 0;
          final videoId = data['videoId'];
          
          if (videoId != null && videoId != state.currentVideoId) {
            playVideo(videoId, data['title'] ?? 'Video', data['uploader'] ?? 'YouTube');
          } else if (state.player != null) {
            final currentPos = state.player!.state.position.inMilliseconds;
            if ((currentPos - positionMs).abs() > 3000) {
              state.player!.seek(Duration(milliseconds: positionMs));
            }
            if (isPlaying && !state.player!.state.playing) {
              state.player!.play();
            } else if (!isPlaying && state.player!.state.playing) {
              state.player!.pause();
            }
          }
        }
      } catch (e) {
        debugPrint("Error syncing video room: $e");
      }
    });
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
    
    // SYNCHRONOUSLY lock state so UI updates immediately (Fixes 2-attempts bug)
    final currentPos = state.player?.state.position ?? Duration.zero;
    state = state.copyWith(selectedQuality: quality, isLoading: true);
    
    await _initializeStreamForQuality(quality, startPosition: currentPos);
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

  void pauseVideo() {
    state.player?.pause();
  }

  void closeVideo() {
    _hostSyncTimer?.cancel();
    _roomSubscription?.cancel();
    _positionSubscription?.cancel();
    if (state.isHost && state.currentRoomId != null) {
      locator<RoomService>().endRoom(state.currentRoomId!);
    }
    state.player?.pause();
    state.player?.dispose();
    state = state.copyWith(
      isVideoActive: false,
      clearVideoController: true,
      clearRoom: true,
    );
  }

  void setMuted(bool mute) {
    state.player?.setVolume(mute ? 0.0 : 100.0);
    state = state.copyWith(isMuted: mute);
  }
}

typedef VideoPlayerProvider = VideoPlayerNotifier;
