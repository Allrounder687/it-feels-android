import '../models/diagnostic_subsystem.dart';
import '../models/trace_context.dart';
import '../observability_service.dart';

/// Categorization of playback failure roots.
enum PlaybackFailureCategory {
  /// Remote network connection dropped, DNS failure, timeout.
  network,

  /// CDN provider 403, 404, rate-limited, empty payload.
  sourceProvider,

  /// Unsupported codec, corrupt bitstream, native mpv decoder crash.
  decoder,

  /// OS audio endpoint unavailable, WASAPI exclusive lock, device disconnect.
  audioOutput,

  /// Player disposed prematurely, state machine invalid transition.
  playerLifecycle,

  /// UI queue and player queue out-of-sync, invalid index.
  stateSync,
}

/// Dedicated instrumenter for the entire audio playback lifecycle.
///
/// Features:
/// 1. Lifecycle event emission (play request -> source resolution -> stream validation -> buffer -> first audio).
/// 2. Precise millisecond latency measurements (source resolution, first audio, seek latency).
/// 3. Standardized failure taxonomy preventing guesswork.
/// 4. Sanitized stream logging (never records credentials or private signed tokens).
class PlaybackDiagnosticsTracker {
  static final PlaybackDiagnosticsTracker instance = PlaybackDiagnosticsTracker._internal();
  factory PlaybackDiagnosticsTracker() => instance;

  final ObservabilityService _obs = ObservabilityService.instance;

  DateTime? _playRequestTime;
  DateTime? _sourceResolveStartTime;
  DateTime? _sourceResolvedTime;
  DateTime? _playerInitStartTime;
  DateTime? _bufferingStartTime;
  DateTime? _seekStartTime;

  String? _activeTrackId;
  String? _activeTrackTitle;
  String? _activeProvider;
  String? _currentTraceId;

  PlaybackDiagnosticsTracker._internal();

  /// Initiates a new playback trace when the user requests playback.
  TraceContext trackPlayRequested({
    required String songId,
    required String songTitle,
    String? sourceOrigin, // e.g. "search", "daily_mix_1", "custom_playlist"
  }) {
    _activeTrackId = songId;
    _activeTrackTitle = songTitle;
    _playRequestTime = DateTime.now();

    final trace = TraceContext.create(prefix: 'PLBK');
    _currentTraceId = trace.correlationId;

    _obs.info(
      subsystem: DiagnosticSubsystem.playback,
      component: 'AudioPlayerHandler',
      eventName: 'playback_requested',
      correlationId: _currentTraceId,
      metadata: {
        'songId': songId,
        'songTitle': songTitle,
        'origin': sourceOrigin ?? 'unknown',
      },
    );

    return trace;
  }

  /// Records start of source/stream URL resolution.
  void trackSourceResolutionStarted({required String provider}) {
    _activeProvider = provider;
    _sourceResolveStartTime = DateTime.now();

    _obs.debug(
      subsystem: DiagnosticSubsystem.playback,
      component: 'MusicRepository',
      eventName: 'source_resolution_started',
      correlationId: _currentTraceId,
      metadata: {'provider': provider, 'songId': _activeTrackId},
    );
  }

  /// Records successful stream resolution with measured duration.
  void trackSourceResolved({
    required String provider,
    required String streamHost, // e.g. "c.saavncdn.com" (sanitized, host only)
    int? bitrateKbps,
  }) {
    _sourceResolvedTime = DateTime.now();
    final durationMs = _sourceResolveStartTime != null
        ? _sourceResolvedTime!.difference(_sourceResolveStartTime!).inMilliseconds
        : null;

    _obs.info(
      subsystem: DiagnosticSubsystem.playback,
      component: 'MusicRepository',
      eventName: 'source_resolved',
      correlationId: _currentTraceId,
      durationMs: durationMs,
      metadata: {
        'provider': provider,
        'streamHost': streamHost,
        'bitrateKbps': bitrateKbps ?? 320,
        'songId': _activeTrackId,
      },
    );
  }

  /// Records player engine initialization start.
  void trackPlayerInitStarted() {
    _playerInitStartTime = DateTime.now();
    _obs.debug(
      subsystem: DiagnosticSubsystem.playback,
      component: 'AudioEngineService',
      eventName: 'player_init_started',
      correlationId: _currentTraceId,
    );
  }

  /// Records start of media buffering.
  void trackBufferingStarted() {
    _bufferingStartTime = DateTime.now();
    _obs.debug(
      subsystem: DiagnosticSubsystem.playback,
      component: 'AudioPlayerHandler',
      eventName: 'buffering_started',
      correlationId: _currentTraceId,
    );
  }

  /// Records completion of buffering and first audible audio output.
  void trackBufferingCompleted({bool isFirstAudio = false}) {
    final now = DateTime.now();
    final bufferDurationMs = _bufferingStartTime != null
        ? now.difference(_bufferingStartTime!).inMilliseconds
        : null;

    int? timeToFirstAudioMs;
    if (isFirstAudio && _playRequestTime != null) {
      timeToFirstAudioMs = now.difference(_playRequestTime!).inMilliseconds;
    }

    final playerInitDurationMs = _playerInitStartTime != null
        ? now.difference(_playerInitStartTime!).inMilliseconds
        : null;

    _obs.info(
      subsystem: DiagnosticSubsystem.playback,
      component: 'AudioPlayerHandler',
      eventName: isFirstAudio ? 'first_audio_rendered' : 'buffering_completed',
      correlationId: _currentTraceId,
      durationMs: bufferDurationMs,
      metadata: {
        'songId': _activeTrackId,
        'timeToFirstAudioMs': timeToFirstAudioMs,
        'bufferDurationMs': bufferDurationMs,
        'playerInitDurationMs': ?playerInitDurationMs,
      },
    );

    _bufferingStartTime = null;
    _playerInitStartTime = null;
  }

  /// Records seek initiation.
  void trackSeekStarted({required Duration targetPosition}) {
    _seekStartTime = DateTime.now();
    _obs.debug(
      subsystem: DiagnosticSubsystem.playback,
      component: 'AudioPlayerHandler',
      eventName: 'seek_requested',
      correlationId: _currentTraceId,
      metadata: {'targetMs': targetPosition.inMilliseconds},
    );
  }

  /// Records seek completion.
  void trackSeekCompleted({required Duration resultingPosition}) {
    final durationMs = _seekStartTime != null
        ? DateTime.now().difference(_seekStartTime!).inMilliseconds
        : null;

    _obs.debug(
      subsystem: DiagnosticSubsystem.playback,
      component: 'AudioPlayerHandler',
      eventName: 'seek_completed',
      correlationId: _currentTraceId,
      durationMs: durationMs,
      metadata: {'resultingMs': resultingPosition.inMilliseconds},
    );
    _seekStartTime = null;
  }

  /// Records track transition (next/previous).
  void trackTransition({
    required String fromSongId,
    required String toSongId,
    required String direction, // "forward", "backward", "auto"
  }) {
    _activeTrackId = toSongId;
    _obs.info(
      subsystem: DiagnosticSubsystem.playback,
      component: 'AudioPlayerNotifier',
      eventName: 'track_transition',
      correlationId: _currentTraceId,
      metadata: {
        'fromSongId': fromSongId,
        'toSongId': toSongId,
        'direction': direction,
      },
    );
  }

  /// Records categorized playback failure with full diagnostics.
  void trackPlaybackError({
    required PlaybackFailureCategory category,
    required String errorCode,
    required String errorMessage,
    dynamic stackTrace,
    int? retryCount,
    bool didRecover = false,
  }) {
    _obs.error(
      subsystem: DiagnosticSubsystem.playback,
      component: 'AudioPlayerHandler',
      eventName: 'playback_error',
      correlationId: _currentTraceId,
      errorCode: errorCode,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      metadata: {
        'failureCategory': category.name,
        'songId': _activeTrackId,
        'songTitle': _activeTrackTitle,
        'provider': _activeProvider,
        'retryCount': retryCount ?? 0,
        'didRecover': didRecover,
      },
    );
  }

  String? get activeTrackId => _activeTrackId;
  String? get currentCorrelationId => _currentTraceId;
}
