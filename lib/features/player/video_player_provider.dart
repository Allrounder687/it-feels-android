import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/features/social/room_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:it_feels_music/features/player/active_media_provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:it_feels_music/services/backend_api_service.dart';
import 'package:it_feels_music/services/storage_service.dart';
import 'package:it_feels_music/services/local_stream_proxy.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

// Testable dependency injection for Player & VideoController
@visibleForTesting
Player Function(PlayerConfiguration config)? customPlayerFactory;

@visibleForTesting
VideoController Function(Player player)? customVideoControllerFactory;

class VideoCandidate {
  final String url;
  final String kind; // 'videoOnly' | 'muxed'
  final String quality;
  final String? audioUrl;
  final Map<String, String> headers;

  VideoCandidate({
    required this.url,
    required this.kind,
    required this.quality,
    this.audioUrl,
    required this.headers,
  });
}

@immutable
class VideoPlayerState {
  final Player? player;
  final VideoController? videoController;
  final bool isVideoActive;
  final bool isLoading;
  final bool videoUnavailable;
  final bool isMuted;
  final String currentVideoId;
  final String originalSongId;
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
    this.videoUnavailable = false,
    this.isMuted = false,
    this.currentVideoId = '',
    this.originalSongId = '',
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
    bool? videoUnavailable,
    bool? isMuted,
    String? currentVideoId,
    String? originalSongId,
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
      videoUnavailable: videoUnavailable ?? this.videoUnavailable,
      isMuted: isMuted ?? this.isMuted,
      currentVideoId: currentVideoId ?? this.currentVideoId,
      originalSongId: originalSongId ?? this.originalSongId,
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

String _redactUrl(String rawUrl, String quality, String kind) {
  try {
    final uri = Uri.parse(rawUrl);
    final itag = uri.queryParameters['itag'] ?? 'unknown';
    return 'host=${uri.host} itag=$itag q=$quality kind=$kind';
  } catch (_) {
    return 'q=$quality kind=$kind';
  }
}

Future<List<VideoCandidate>> resolvePlayableVideo(
  List<Map<String, dynamic>> streams,
  String targetQuality,
  String audioUrl,
) async {
  final androidHeaders = <String, String>{
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://www.jiosaavn.com/',
  };

  final candidates = <VideoCandidate>[];

  int parseRes(String q) {
    final match = RegExp(r'\d+').firstMatch(q);
    return match != null ? int.parse(match.group(0)!) : 0;
  }

  final targetRes = parseRes(targetQuality);

  // 1. MP4 videoOnly <= selected quality (sorted descending)
  final videoOnlyStreams = streams.where((s) => s['videoOnly'] == true).toList();
  videoOnlyStreams.sort((a, b) => parseRes(b['quality'] as String? ?? '').compareTo(parseRes(a['quality'] as String? ?? '')));

  for (final stream in videoOnlyStreams) {
    final res = parseRes(stream['quality'] as String? ?? '');
    if (res <= targetRes || candidates.isEmpty) {
      final rawUrl = stream['url'] as String;
      final q = stream['quality'] as String? ?? '720p';

      candidates.add(VideoCandidate(
        url: rawUrl,
        kind: 'videoOnly',
        quality: q,
        audioUrl: audioUrl.isNotEmpty ? audioUrl : null,
        headers: androidHeaders,
      ));

      try {
        final proxyUrl = await LocalStreamProxy.getProxyUrl(rawUrl);
        candidates.add(VideoCandidate(
          url: proxyUrl,
          kind: 'videoOnly',
          quality: '$q (proxy)',
          audioUrl: audioUrl.isNotEmpty ? audioUrl : null,
          headers: androidHeaders,
        ));
      } catch (_) {}
    }
  }

  // 2. MP4 muxed fallbacks <= 720p
  final muxedStreams = streams.where((s) => s['videoOnly'] == false).toList();
  muxedStreams.sort((a, b) => parseRes(b['quality'] as String? ?? '').compareTo(parseRes(a['quality'] as String? ?? '')));

  for (final stream in muxedStreams) {
    final rawUrl = stream['url'] as String;
    final q = stream['quality'] as String? ?? '360p';

    candidates.add(VideoCandidate(
      url: rawUrl,
      kind: 'muxed',
      quality: q,
      headers: androidHeaders,
    ));

    try {
      final proxyUrl = await LocalStreamProxy.getProxyUrl(rawUrl);
      candidates.add(VideoCandidate(
        url: proxyUrl,
        kind: 'muxed',
        quality: '$q (proxy)',
        headers: androidHeaders,
      ));
    } catch (_) {}
  }

  return candidates;
}

class VideoPlayerNotifier extends Notifier<VideoPlayerState> {
  Timer? _hostSyncTimer;
  StreamSubscription? _roomSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _trackerSubscription;
  int _initStreamGenToken = 0;
  bool _isRecovering = false;
  int _recoveryAttempts = 0;
  final Duration _lastKnownPosition = Duration.zero;

  void setOnVideoStarted(VoidCallback? callback) {
    state = state.copyWith(onVideoStarted: callback);
  }

  @override
  VideoPlayerState build() {
    _initSystemControls();
    final config = const PlayerConfiguration(pitch: true, vo: 'gpu');
    final player = customPlayerFactory?.call(config) ?? Player(configuration: config);
    final controller = customVideoControllerFactory?.call(player) ?? VideoController(player);

    ref.onDispose(() {
      _hostSyncTimer?.cancel();
      _roomSubscription?.cancel();
      _positionSubscription?.cancel();
      _trackerSubscription?.cancel();
      player.dispose();
    });

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
                          state.originalSongId == current.currentSong!.id ||
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
      
      // Sync on Seek: If position jumps by more than 2 seconds, the user manually scrubbed
      if (isSynced && state.isVideoActive && state.player != null && current.isPlaying && previous != null) {
        final diff = (current.position - previous.position).inMilliseconds.abs();
        if (diff > 2000) {
          // Only seek video if it didn't already get seeked by the UI (drift > 1000ms)
          final drift = (state.player!.state.position - current.position).inMilliseconds.abs();
          if (drift > 1000) {
            state.player!.seek(current.position);
            state.player!.play();
          }
        } else {
          // Continuous Drift Correction
          final videoPosition = state.player!.state.position;
          final audioPosition = current.position;
          final drift = (videoPosition - audioPosition).inMilliseconds;
          
          if (drift.abs() > 800) {
            // Aggressive correction for huge random drifts not caught by diff > 2000
            // DO NOT seek here if diff is small, just let it drift correct, or only seek if drift is VERY large
            if (drift.abs() > 2000) {
              state.player!.seek(audioPosition);
            }
          } else if (drift > 100) {
            // Video is ahead, slow down
            if (state.player!.state.rate != 0.95) state.player!.setRate(0.95);
          } else if (drift < -100) {
            // Video is behind, speed up
            if (state.player!.state.rate != 1.05) state.player!.setRate(1.05);
          } else {
            // In sync
            if (state.player!.state.rate != 1.0) state.player!.setRate(1.0);
          }
        }
      }
    });

    final defaultQuality = ref.read(settingsProvider).defaultVideoQuality;
    return VideoPlayerState(
      player: player, 
      videoController: controller, 
      selectedQuality: defaultQuality
    );
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

  Future<void> playVideo(String videoId, String title, String uploader, {String? localPath, String? query, Duration? startPosition, bool isBackgroundHandoff = false, void Function(String)? onToastMessage, bool forceReload = false, bool? forceMute}) async {
    final String originalId = videoId;
    // Check for custom overridden YouTube ID for this song
    final customVideoId = await StorageService.getCustomVideoLink(videoId);
    final effectiveVideoId = customVideoId ?? videoId;
    videoId = effectiveVideoId;

    if (!forceReload && state.currentVideoId == effectiveVideoId && state.player != null) {
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
    // always start with audio enabled, unless explicitly overridden.
    state = state.copyWith(isMuted: forceMute ?? false);

    // STOP OLD VIDEO TO PREVENT OVERLAP
    await state.player?.pause();

    // Handoff logic now lives in the UI (NowPlayingScreen) via onVideoStarted callback,
    // so we do not forcefully kill audio_service here. This enables seamless cross-fades!
    
    ref.read(activeMediaProvider.notifier).setActiveMedia(ActiveMediaType.video);

    state = state.copyWith(
      isLoading: true,
      isVideoActive: true,
      currentVideoId: videoId,
      originalSongId: originalId, // the passed-in ID before override is the actual song ID
      currentTitle: title,
      currentUploader: uploader,
      streams: const [],
      audioUrl: '',
      relatedVideos: const [],
    );

    if (localPath != null && localPath.isNotEmpty) {
      await _initPlayerWithFile(localPath, startPosition: startPosition);
      final results = await Future.wait([
        BackendApiService.getRelatedVideos(videoId),
      ]);
      state = state.copyWith(
        relatedVideos: List<Map<String, dynamic>>.from(results[0]),
        isLoading: false,
      );
      return;
    }

    // 1. Mark session token to prevent async overlap
    final currentToken = ++_initStreamGenToken;

    // Fetch Stream first for instant playback
    final streamData = await BackendApiService.getVideoStreams(videoId, query: query);
    
    // ABORT if the user changed songs or closed the video while we were fetching!
    if (currentToken != _initStreamGenToken || !state.isVideoActive || state.currentVideoId != videoId) {
      debugPrint('[VideoPlayerNotifier] playVideo aborted due to stale request or closed video.');
      return;
    }

    final streamList = List<Map<String, dynamic>>.from(streamData['streams'] ?? []);
    final audioUrl = streamData['audioUrl'] as String? ?? '';
    final durationMs = streamData['durationMs'] as int? ?? 0;

    state = state.copyWith(
      streams: streamList,
      audioUrl: audioUrl,
    );
    
    // Fire off related videos asynchronously so it doesn't block playback
    BackendApiService.getRelatedVideos(videoId, query: query).then((relVideos) {
      if (state.currentVideoId == videoId) {
        state = state.copyWith(
          relatedVideos: List<Map<String, dynamic>>.from(relVideos),
        );
      }
    });
    
    if (streamList.isNotEmpty) {
      _initializeStreamForQuality(
        state.selectedQuality, 
        startPosition: startPosition, 
        isBackgroundHandoff: isBackgroundHandoff,
        targetDurationMs: durationMs,
        onToastMessage: onToastMessage,
      );
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _initPlayerWithFile(String localPath, {Duration? startPosition}) async {
    try {
      await state.player?.pause();
      
      final media = Media(
        localPath,
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        },
        extras: {
          'vd-lavc-threads': Platform.numberOfProcessors.toString(),
          'hwdec': Platform.isWindows ? 'auto-copy' : 'auto',
        },
      );
      
      
      await state.player!.open(media, play: true);
      await state.player!.setRate(state.playbackSpeed);
      
      if (startPosition != null) {
        await state.player!.seek(startPosition);
      }
    } catch (e) {
      debugPrint('[VideoPlayerNotifier] Error playing offline file: $e');
    }
  }

  int _bufferSizeForQuality(String quality) {
    final q = quality.toLowerCase();
    if (q.contains('360') || q.contains('240') || q.contains('144')) return 16 * 1024 * 1024;
    if (q.contains('480')) return 24 * 1024 * 1024;
    if (q.contains('720')) return 32 * 1024 * 1024;
    if (q.contains('1080')) return 64 * 1024 * 1024;
    return 128 * 1024 * 1024; // 4K/8K/HLS safety
  }

  Future<void> _initializeStreamForQuality(
    String qualityPreference, {
    Duration? startPosition,
    bool isBackgroundHandoff = false,
    int targetDurationMs = 0,
    void Function(String)? onToastMessage,
  }) async {
    final myToken = ++_initStreamGenToken;

    state = state.copyWith(isLoading: true);

    if (state.streams.isEmpty) {
      debugPrint('[Video] audio-only fallback');
      state = state.copyWith(isLoading: false, videoUnavailable: true);
      return;
    }

    final candidates = await resolvePlayableVideo(state.streams, qualityPreference, state.audioUrl);
    if (candidates.isEmpty) {
      debugPrint('[Video] audio-only fallback');
      state = state.copyWith(isLoading: false, videoUnavailable: true);
      return;
    }

    Player player = state.player!;
    VideoController controller = state.videoController!;

    bool probeSuccess = false;
    VideoCandidate? successfulCandidate;

    for (final candidate in candidates) {
      if (_initStreamGenToken != myToken) {
        debugPrint('[Video] Session aborted for token $myToken');
        return;
      }

      debugPrint('[Video] candidate kind=${candidate.kind} q=${candidate.quality} info=${_redactUrl(candidate.url, candidate.quality, candidate.kind)}');

      try {
        final completer = Completer<bool>();
        StreamSubscription? subDuration;
        StreamSubscription? subParams;
        StreamSubscription? subError;

        subDuration = player.stream.duration.listen((dur) {
          if (dur > Duration.zero && !completer.isCompleted) {
            final w = player.state.width;
            final h = player.state.height;
            debugPrint('[Video] opened/probed duration=$dur params=${w}x$h');
            completer.complete(true);
          }
        });

        subParams = player.stream.videoParams.listen((params) {
          final w = params.w ?? 0;
          final h = params.h ?? 0;
          if (w > 0 && h > 0 && !completer.isCompleted) {
            final dur = player.state.duration;
            debugPrint('[Video] opened/probed duration=$dur params=${w}x$h');
            completer.complete(true);
          }
        });

        subError = player.stream.error.listen((err) {
          if (!completer.isCompleted) {
            debugPrint('[Video] failure type=$err candidate=${_redactUrl(candidate.url, candidate.quality, candidate.kind)}');
            completer.complete(false);
          }
        });

        // Probe with proper mpv extras for reliable decoding on Windows
        final extras = <String, String>{
          'hwdec': 'auto-safe',
          'cache-pause': 'no',
          'demuxer-max-bytes': _bufferSizeForQuality(candidate.quality).toString(),
          'vd-lavc-threads': Platform.numberOfProcessors.clamp(1, 16).toString(),
        };
        // For videoOnly streams, tell mpv not to look for audio tracks
        if (candidate.kind == 'videoOnly') {
          extras['aid'] = 'no';
        }
        final media = Media(candidate.url, httpHeaders: candidate.headers, extras: extras);
        await player.open(media, play: false);

        final result = await completer.future.timeout(
          const Duration(seconds: 12),
          onTimeout: () {
            debugPrint('[Video] failure type=timeout candidate=${_redactUrl(candidate.url, candidate.quality, candidate.kind)}');
            return false;
          },
        );

        await subDuration.cancel();
        await subParams.cancel();
        await subError.cancel();

        if (_initStreamGenToken != myToken) return;

        if (result) {
          probeSuccess = true;
          successfulCandidate = candidate;
          break;
        } else {
          debugPrint('[Video] fallback=>advancing to next candidate');
          try { await player.stop(); } catch (_) {}
        }
      } catch (e) {
        debugPrint('[Video] failure type=$e candidate=${_redactUrl(candidate.url, candidate.quality, candidate.kind)}');
        debugPrint('[Video] fallback=>advancing to next candidate');
        try { await player.stop(); } catch (_) {}
      }
    }

    if (_initStreamGenToken != myToken) return;

    if (!probeSuccess || successfulCandidate == null) {
      debugPrint('[Video] audio-only fallback');
      state = state.copyWith(
        isLoading: false,
        videoUnavailable: true,
      );
      return;
    }

    final candidate = successfulCandidate;
    state = state.copyWith(
      selectedQuality: candidate.quality,
      isLoading: false,
      videoUnavailable: false,
    );

    // Ensure videoOnly streams and explicitly muted streams are muted to prevent dual-audio
    if (candidate.kind == 'videoOnly' || state.isMuted) {
      await player.setVolume(0.0);
    } else {
      await player.setVolume(100.0);
    }

    await player.play();

    // Apply resume position clamped against duration
    final resumePos = startPosition ?? _lastKnownPosition;
    final dur = player.state.duration;
    if (resumePos > Duration.zero && dur > Duration.zero) {
      final clampedPos = resumePos > dur ? dur : resumePos;
      await player.seek(clampedPos);
    }

    if (candidate.kind == 'muxed' && !state.isMuted) {
      try {
        final audioNotifier = ref.read(audioPlayerProvider.notifier);
        audioNotifier.pause();
      } catch (_) {}
    } else {
      _setupDriftCorrection(player);
    }

    state.onVideoStarted?.call();

    if (state.currentRoomId != null) {
      _initRoomSync();
    }
  }

  void _setupDriftCorrection(Player player) {
    _positionSubscription?.cancel();
    _positionSubscription = player.stream.position.listen((vPos) {
      if (!state.isVideoActive || state.isLoading) return;
      try {
        final audioPos = ref.read(audioPlayerProvider).position;
        final diff = (vPos - audioPos).inMilliseconds.abs();
        if (diff > 350 && !player.state.buffering) {
          player.seek(audioPos);
        }
      } catch (_) {}
    });
  }

  @visibleForTesting
  Future<void> testDebugPlayback(String testUrl, {required String kind, String quality = '720p'}) async {
    final candidate = VideoCandidate(
      url: testUrl,
      kind: kind,
      quality: quality,
      headers: <String, String>{},
    );
    debugPrint('[Video] DEBUG TEST PATH: candidate info=${_redactUrl(candidate.url, candidate.quality, candidate.kind)}');
    state = state.copyWith(streams: [
      {
        'quality': quality,
        'url': testUrl,
        'videoOnly': kind == 'videoOnly',
      }
    ]);
    await _initializeStreamForQuality(quality);
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
    if (state.player == null || state.isLoading) return;
    final currentPos = state.player!.state.position;
    var targetPos = currentPos + duration;
    var maxDur = state.player!.state.duration;
    if (targetPos < Duration.zero) targetPos = Duration.zero;
    if (maxDur.inMilliseconds > 0 && targetPos > maxDur) targetPos = maxDur;
    state.player!.seek(targetPos);
  }

  void seekTo(Duration position) {
    if (state.player == null || state.isLoading) return;
    var targetPos = position;
    var maxDur = state.player!.state.duration;
    if (targetPos < Duration.zero) targetPos = Duration.zero;
    if (maxDur.inMilliseconds > 0 && targetPos > maxDur) targetPos = maxDur;
    state.player!.seek(targetPos);
  }

  void pauseVideo() {
    state.player?.pause();
  }

  void closeVideo() {
    _hostSyncTimer?.cancel();
    _roomSubscription?.cancel();
    _positionSubscription?.cancel();
    _trackerSubscription?.cancel();
    
    // Invalidate any pending network requests by incrementing the token
    _initStreamGenToken++;
    
    if (state.isHost && state.currentRoomId != null) {
      locator<RoomService>().endRoom(state.currentRoomId!);
    }
    state.player?.stop();
    // Do NOT dispose the player or clear the controller, as they are singletons tied to this Notifier
    state = state.copyWith(
      isVideoActive: false,
      clearRoom: true,
      currentVideoId: '', // Explicitly clear the ID to prevent lingering state
    );
  }

  void setMuted(bool mute) {
    state.player?.setVolume(mute ? 0.0 : 100.0);
    state = state.copyWith(isMuted: mute);
  }

}

typedef VideoPlayerProvider = VideoPlayerNotifier;
