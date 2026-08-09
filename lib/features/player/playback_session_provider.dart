import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/stream_resolver.dart';
import 'package:it_feels_music/core/utils/device_utils.dart';

enum PlaybackMode { audio, video }
enum PlaybackSessionStatus { idle, resolving, buffering, playing, paused, switchingMode, failed, disposed }

@immutable
class PlaybackSessionState {
  final PlaybackMode mode;
  final PlaybackSessionStatus status;
  final Song? currentSong;
  final List<Song> queue;
  final int currentIndex;
  
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  
  final String selectedVideoQuality;
  final bool useMediaKitForAudio; // Feature flag for migration
  final String? currentError;
  final DateTime? streamExpiry;
  
  const PlaybackSessionState({
    this.mode = PlaybackMode.audio,
    this.status = PlaybackSessionStatus.idle,
    this.currentSong,
    this.queue = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.selectedVideoQuality = '720p',
    this.useMediaKitForAudio = false, 
    this.currentError,
    this.streamExpiry,
  });
  
  PlaybackSessionState copyWith({
    PlaybackMode? mode,
    PlaybackSessionStatus? status,
    Song? currentSong,
    bool clearCurrentSong = false,
    List<Song>? queue,
    int? currentIndex,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? duration,
    String? selectedVideoQuality,
    bool? useMediaKitForAudio,
    String? currentError,
    DateTime? streamExpiry,
  }) {
    return PlaybackSessionState(
      mode: mode ?? this.mode,
      status: status ?? this.status,
      currentSong: clearCurrentSong ? null : (currentSong ?? this.currentSong),
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      selectedVideoQuality: selectedVideoQuality ?? this.selectedVideoQuality,
      useMediaKitForAudio: useMediaKitForAudio ?? this.useMediaKitForAudio,
      currentError: currentError ?? this.currentError,
      streamExpiry: streamExpiry ?? this.streamExpiry,
    );
  }
}

class PlaybackSessionNotifier extends Notifier<PlaybackSessionState> {
  final StreamResolver _resolver = StreamResolver();
  int _generationToken = 0;
  
  // These will be injected/set by the UI adapters to allow coordination
  Future<void> Function(Song song, Duration startPosition)? onPlayAudio;
  Future<void> Function(Song song, Duration startPosition)? onPlayVideo;
  VoidCallback? onPauseAudio;
  VoidCallback? onPauseVideo;
  Future<void> Function(Duration position)? onSeekAudio;
  Future<void> Function(Duration position)? onSeekVideo;

  @override
  PlaybackSessionState build() {
    return const PlaybackSessionState();
  }

  void updatePosition(Duration position) {
    state = state.copyWith(position: position);
  }

  void updateDuration(Duration duration) {
    state = state.copyWith(duration: duration);
  }

  void updatePlayingState(bool isPlaying) {
    state = state.copyWith(isPlaying: isPlaying);
  }

  Future<void> playSong(Song song, {List<Song>? queue, int index = 0, Duration startPosition = Duration.zero}) async {
    state = state.copyWith(
      currentSong: song,
      isLoading: true,
      queue: queue ?? state.queue,
      currentIndex: index,
    );
    
    final videoId = song.id.contains(':') ? song.id : 'search:${song.id}';
    final query = '${song.title} ${song.artist}';
    
    final currentToken = ++_generationToken;
    state = state.copyWith(status: PlaybackSessionStatus.resolving);
    
    // Resolve stream
    await _resolver.resolveStream(videoId, query: query, song: song, isVideoMode: state.mode == PlaybackMode.video);
    
    if (currentToken != _generationToken) return;
    state = state.copyWith(status: PlaybackSessionStatus.buffering);
    
    if (state.mode == PlaybackMode.audio) {
      if (onPlayAudio != null) {
        await onPlayAudio!(song, startPosition);
      }
    } else {
      if (onPlayVideo != null) {
        await onPlayVideo!(song, startPosition);
      }
    }
    
    state = state.copyWith(isLoading: false);
    
    // Pre-resolve next track if not low RAM
    if (!await DeviceUtils.isLowRamDevice() && state.currentIndex + 1 < state.queue.length) {
      final nextSong = state.queue[state.currentIndex + 1];
      final nextVideoId = nextSong.id.contains(':') ? nextSong.id : 'search:${nextSong.id}';
      _resolver.preResolve(nextVideoId, query: '${nextSong.title} ${nextSong.artist}', song: nextSong, isVideoMode: state.mode == PlaybackMode.video);
    }
  }

  Future<void> toggleMode() async {
    final newMode = state.mode == PlaybackMode.audio ? PlaybackMode.video : PlaybackMode.audio;
    final currentToken = ++_generationToken;
    
    state = state.copyWith(mode: newMode, isLoading: true, status: PlaybackSessionStatus.switchingMode);
    
    if (state.currentSong != null) {
      if (newMode == PlaybackMode.video) {
        // Handoff to video
        if (onPlayVideo != null) {
          await onPlayVideo!(state.currentSong!, state.position);
        }
        if (currentToken != _generationToken) return;
        if (onPauseAudio != null) {
          onPauseAudio!(); // Pause audio after video starts
        }
      } else {
        // Handoff to audio
        if (onPauseVideo != null) {
          onPauseVideo!(); // Pause video immediately
        }
        if (onPlayAudio != null) {
          await onPlayAudio!(state.currentSong!, state.position);
        }
        if (currentToken != _generationToken) return;
      }
    }
    
    if (currentToken != _generationToken) return;
    state = state.copyWith(isLoading: false, status: PlaybackSessionStatus.playing);
  }
}

final playbackSessionProvider = NotifierProvider<PlaybackSessionNotifier, PlaybackSessionState>(() {
  return PlaybackSessionNotifier();
});
