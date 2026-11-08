import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart' hide AudioDevice;
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:io';
import 'dart:async';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:smtc_windows/smtc_windows.dart';
import 'package:it_feels_music/services/storage_service.dart';
import 'package:it_feels_music/data/services/equalizer_service.dart';
import 'package:it_feels_music/core/diagnostics/trackers/playback_diagnostics_tracker.dart';

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  late final Player _player;
  final IMusicRepository apiService;
  
  VoidCallback? onSkipNext;
  VoidCallback? onSkipPrevious;
  VoidCallback? onTrackCompleted;
  Future<void> Function()? onToggleFavorite;
  void Function(String error)? onPlaybackError;
  bool _isLoadingTrack = false;
  
  SMTCWindows? _smtc;
  StreamSubscription? _smtcSubscription;

  StreamSubscription? _playerPlayingSub;
  StreamSubscription? _playerPositionSub;
  StreamSubscription? _playerCompletedSub;
  StreamSubscription? _playerBufferingSub;
  StreamSubscription? _playerErrorSub;
  StreamSubscription? _audioDevicesSubscription;
  StreamSubscription? _audioDeviceSubscription;
  StreamSubscription? _becomingNoisySubscription;
  StreamSubscription? _devicesChangedSubscription;
  StreamSubscription? _interruptionSubscription;
  List<AudioDevice> _lastAudioDevices = [];
  AudioDevice? _currentAudioDevice;
  bool _isFirstAudioDevicesEmission = true;
  bool _isFirstAudioDeviceEmission = true;

  bool _isDisposed = false;
  bool _isDisposing = false;
  bool get isDisposed => _isDisposed;

  AudioPlayerHandler({
    required this.apiService,
    @visibleForTesting Player? customPlayer,
  }) {
    _player = customPlayer ?? Player(configuration: const PlayerConfiguration(pitch: true));
    _init();
  }

  Player get player => _player;

  void _init() {
    if (!kIsWeb && Platform.isWindows) {
      try {
        _smtc = SMTCWindows(
          config: const SMTCConfig(
            fastForwardEnabled: false,
            nextEnabled: true,
            pauseEnabled: true,
            playEnabled: true,
            rewindEnabled: false,
            prevEnabled: true,
            stopEnabled: true,
          ),
        );
        _smtcSubscription = _smtc?.buttonPressStream.listen((event) {
          switch (event) {
            case PressedButton.play:
              play();
              break;
            case PressedButton.pause:
              pause();
              break;
            case PressedButton.next:
              skipToNext();
              break;
            case PressedButton.previous:
              skipToPrevious();
              break;
            case PressedButton.stop:
              stop();
              break;
            default:
              break;
          }
        });
      } catch (e) {
        debugPrint('[AudioPlayerHandler] Failed to initialize SMTC: $e');
      }
    }
    
    _playerPlayingSub = _player.stream.playing.listen((playing) {
      if (!_isDisposed) _broadcastState();
    });
    _playerPositionSub = _player.stream.position.listen((pos) {
      if (!_isDisposed) _broadcastState();
    });
    _playerCompletedSub = _player.stream.completed.listen((completed) {
      if (_isDisposed) return;
      if (completed) {
        _broadcastState(); // Do not emit isCompleted to prevent iOS teardown
        if (onTrackCompleted != null) {
          onTrackCompleted!();
        } else if (onSkipNext != null) {
          onSkipNext!();
        }
      }
    });
    _playerBufferingSub = _player.stream.buffering.listen((buffering) {
      if (_isDisposed) return;
      if (buffering) {
        PlaybackDiagnosticsTracker.instance.trackBufferingStarted();
      } else {
        PlaybackDiagnosticsTracker.instance.trackBufferingCompleted(isFirstAudio: true);
      }
      _broadcastState(isBuffering: buffering);
    });

    _playerErrorSub = _player.stream.error.listen((error) {
      debugPrint('[AudioPlayerHandler] Player emitted stream error: $error');
      PlaybackDiagnosticsTracker.instance.trackPlaybackError(
        category: PlaybackFailureCategory.decoder,
        errorCode: 'ERR-DEC-STREAM',
        errorMessage: error.toString(),
      );
      if (onPlaybackError != null) {
        onPlaybackError!(error.toString());
      }
    });

    _setupAudioDeviceDisconnectionListeners();
  }

  void _setupAudioDeviceDisconnectionListeners() {
    // 1. Desktop & Cross-Platform (media_kit stream)
    try {
      _audioDevicesSubscription = _player.stream.audioDevices.listen((devices) {
        if (_isFirstAudioDevicesEmission) {
          _isFirstAudioDevicesEmission = false;
          _lastAudioDevices = devices;
          return;
        }

        // Compare non-auto physical/OS devices
        final previousNames = _lastAudioDevices
            .map((d) => d.name)
            .where((n) => n.isNotEmpty && n != 'auto')
            .toSet();
        final currentNames = devices
            .map((d) => d.name)
            .where((n) => n.isNotEmpty && n != 'auto')
            .toSet();

        final removedDevices = previousNames.difference(currentNames);
        _lastAudioDevices = devices;

        if (removedDevices.isNotEmpty) {
          debugPrint('[AudioPlayerHandler] Output audio device(s) disconnected: $removedDevices');
          if (_player.state.playing || _isLoadingTrack) {
            debugPrint('[AudioPlayerHandler] Auto-pausing playback due to audio device disconnection.');
            pause();
          }
        }
      }, onError: (e) {
        debugPrint('[AudioPlayerHandler] Error in audioDevices stream: $e');
      });

      _audioDeviceSubscription = _player.stream.audioDevice.listen((device) {
        if (_isFirstAudioDeviceEmission) {
          _isFirstAudioDeviceEmission = false;
          _currentAudioDevice = device;
          return;
        }

        final previousDevice = _currentAudioDevice;
        _currentAudioDevice = device;

        // If the active output device was non-auto and switched away
        if (previousDevice != null &&
            previousDevice.name.isNotEmpty &&
            previousDevice.name != 'auto' &&
            device.name != previousDevice.name) {
          debugPrint('[AudioPlayerHandler] Active device changed from ${previousDevice.name} to ${device.name}');
          if (_player.state.playing || _isLoadingTrack) {
            debugPrint('[AudioPlayerHandler] Auto-pausing playback due to active device route loss.');
            pause();
          }
        }
      }, onError: (e) {
        debugPrint('[AudioPlayerHandler] Error in audioDevice stream: $e');
      });
    } catch (e) {
      debugPrint('[AudioPlayerHandler] Failed to initialize media_kit device listeners: $e');
    }

    // 2. Mobile platforms (Android / iOS / macOS) via AudioSession
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      try {
        AudioSession.instance.then((session) {
          _becomingNoisySubscription = session.becomingNoisyEventStream.listen((_) {
            debugPrint('[AudioPlayerHandler] Audio becoming noisy (unplugged headphones/BT). Auto-pausing.');
            if (_player.state.playing || _isLoadingTrack) {
              pause();
            }
          }, onError: (e) {
            debugPrint('[AudioPlayerHandler] Error in becomingNoisyEventStream: $e');
          });

          _devicesChangedSubscription = session.devicesChangedEventStream.listen((event) {
            if (event.devicesRemoved.isNotEmpty) {
              debugPrint('[AudioPlayerHandler] Audio device(s) removed from AudioSession: ${event.devicesRemoved.map((d) => d.name).toList()}');
              if (_player.state.playing || _isLoadingTrack) {
                pause();
              }
            }
          }, onError: (e) {
            debugPrint('[AudioPlayerHandler] Error in devicesChangedEventStream: $e');
          });

          _interruptionSubscription = session.interruptionEventStream.listen((event) {
            if (event.begin) {
              debugPrint('[AudioPlayerHandler] Audio interruption began: ${event.type}');
              if (event.type == AudioInterruptionType.duck) {
                // Smooth transient volume ducking for navigation/notifications
                _player.setVolume((_player.state.volume * 0.35).clamp(5.0, 100.0));
              } else {
                if (_player.state.playing || _isLoadingTrack) {
                  pause();
                }
              }
            } else {
              if (event.type == AudioInterruptionType.duck) {
                _player.setVolume(100.0);
              }
            }
          }, onError: (e) {
            debugPrint('[AudioPlayerHandler] Error in interruptionEventStream: $e');
          });
        }).catchError((e) {
          debugPrint('[AudioPlayerHandler] Failed to hook AudioSession listeners: $e');
        });
      } catch (e) {
        debugPrint('[AudioPlayerHandler] Error initializing AudioSession listeners: $e');
      }
    }
  }

  void _broadcastState({bool isBuffering = false}) {
    final playing = _player.state.playing;
    
    AudioProcessingState audioProcessingState = AudioProcessingState.ready;
    if (_isLoadingTrack) {
      audioProcessingState = AudioProcessingState.loading;
    } else if (isBuffering) {
      audioProcessingState = AudioProcessingState.buffering;
    } else if (playing) {
      audioProcessingState = AudioProcessingState.ready;
    }

    final effectivePlaying = _isLoadingTrack ? true : playing;

    playbackState.add(playbackState.value.copyWith(
      controls: [
        const MediaControl(androidIcon: 'mipmap/ic_launcher', label: 'Previous', action: MediaAction.skipToPrevious),
        if (effectivePlaying) const MediaControl(androidIcon: 'mipmap/ic_launcher', label: 'Pause', action: MediaAction.pause) else const MediaControl(androidIcon: 'mipmap/ic_launcher', label: 'Play', action: MediaAction.play),
        const MediaControl(androidIcon: 'mipmap/ic_launcher', label: 'Next', action: MediaAction.skipToNext),
        const MediaControl(androidIcon: 'mipmap/ic_launcher', label: 'Stop', action: MediaAction.stop),
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        MediaAction.stop,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: audioProcessingState,
      playing: effectivePlaying,
      updatePosition: _isLoadingTrack ? Duration.zero : _player.state.position,
      bufferedPosition: _player.state.buffer,
      speed: _player.state.rate,
      queueIndex: 0,
    ));

    if (_smtc != null) {
      try {
        _smtc!.setPlaybackStatus(playing ? PlaybackStatus.playing : PlaybackStatus.paused);
        _smtc!.updateTimeline(PlaybackTimeline(
          startTimeMs: 0,
          endTimeMs: _player.state.duration.inMilliseconds,
          positionMs: _player.state.position.inMilliseconds,
        ));
      } catch (e) {
        // Ignored: SMTC update error on unsupported state
      }
    }
  }

    Uri? _resolveArtUri(String coverArt) {
    if (coverArt.isEmpty) return null;
    if (coverArt.startsWith('http://') || coverArt.startsWith('https://')) {
      return Uri.parse(coverArt);
    }
    try {
      final file = File(coverArt);
      if (file.existsSync()) {
        return Uri.file(coverArt);
      }
    } catch (_) {}
    return null;
  }

  void notifyLoading(Song song) {
    _isLoadingTrack = true;
    final item = MediaItem(
      id: song.id,
      album: song.album,
      title: song.title,
      artist: song.artist,
      duration: Duration(seconds: song.duration),
      artUri: _resolveArtUri(song.coverArt),
    );
    mediaItem.add(item);
    if (_smtc != null) {
      try {
        _smtc!.updateMetadata(MusicMetadata(
          title: song.title,
          artist: song.artist,
          album: song.album ?? '',
          thumbnail: song.coverArt,
        ));
      } catch (_) {}
    }
    _broadcastState(isBuffering: true);
  }

  void cancelLoading() {
    _isLoadingTrack = false;
    _broadcastState();
  }

  Future<void> playSong(Song song, String streamUrl) async {
    if (_isDisposed) return;
    try {
      _isLoadingTrack = false;
      final host = Uri.tryParse(streamUrl)?.host ?? 'local';
      PlaybackDiagnosticsTracker.instance.trackSourceResolved(
        provider: 'jiosaavn_or_addon',
        streamHost: host,
        bitrateKbps: 320,
      );
      PlaybackDiagnosticsTracker.instance.trackPlayerInitStarted();

      final item = MediaItem(
        id: song.id,
        album: song.album,
        title: song.title,
        artist: song.artist,
        duration: Duration(seconds: song.duration),
        artUri: _resolveArtUri(song.coverArt),
      );
      mediaItem.add(item);
      
      if (_smtc != null) {
        try {
          _smtc!.updateMetadata(MusicMetadata(
            title: song.title,
            artist: song.artist,
            album: song.album ?? '',
            thumbnail: song.coverArt,
          ));
        } catch (_) {}
      }
      
      await _player.stop();

      final Media media = Media(
        streamUrl,
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Referer': 'https://www.jiosaavn.com/',
          'Accept': '*/*',
        },
      );
      
      await _player.open(media, play: true);

      try {
        await locator<EqualizerService>().syncWithPlayer(_player);
      } catch (_) {}
      
      if (song.playbackPositionMs != null && song.playbackPositionMs! > 0) {
        await _player.seek(Duration(milliseconds: song.playbackPositionMs!));
      }
    } catch (e) {
      debugPrint('[AudioPlayerHandler] Error setting stream URL: $e');
      if (onPlaybackError != null) {
        onPlaybackError!(e.toString());
      }
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {}

  @override
  Future<void> play() {
    if (_isDisposed) return Future.value();
    return _player.play();
  }

  @override
  Future<void> pause() async {
    if (_isDisposed) return;
    _isLoadingTrack = false;
    return _player.pause();
  }

  @override
  Future<void> stop() async {
    if (_isDisposed) return;
    _isLoadingTrack = false;
    return _player.stop();
  }

  @override
  Future<void> seek(Duration position) {
    if (_isDisposed) return Future.value();
    final dur = _player.state.duration;
    Duration target = position;
    if (target < Duration.zero) {
      target = Duration.zero;
    } else if (dur > Duration.zero && target > dur) {
      target = dur;
    }
    PlaybackDiagnosticsTracker.instance.trackSeekStarted(targetPosition: target);
    return _player.seek(target).then((_) {
      PlaybackDiagnosticsTracker.instance.trackSeekCompleted(resultingPosition: target);
    });
  }

  @override
  Future<void> skipToNext() async {
    if (onSkipNext != null) onSkipNext!();
  }

  @override
  Future<void> skipToPrevious() async {
    if (onSkipPrevious != null) onSkipPrevious!();
  }

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId, [Map<String, dynamic>? options]) async {
    final settings = await StorageService.loadSettings();
    if (settings['enableAndroidAuto'] == false) return [];

    if (parentMediaId == AudioService.browsableRootId) {
      return [
        const MediaItem(
          id: 'recently_played',
          title: 'Recently Played',
          playable: false,
        ),
        const MediaItem(
          id: 'favorites',
          title: 'Favorites',
          playable: false,
        ),
        const MediaItem(
          id: 'downloads',
          title: 'Downloaded Songs',
          playable: false,
        ),
      ];
    } else if (parentMediaId == AudioService.recentRootId) {
      final state = await StorageService.loadPlaybackState();
      if (state != null) {
        final List<dynamic> rawList = state['recentlyPlayed'] ?? [];
        if (rawList.isNotEmpty) {
          final s = Song.fromJson(Map<String, dynamic>.from(rawList.first));
          return [
            MediaItem(
              id: s.id,
              title: s.title,
              artist: s.artist,
              album: s.album,
              duration: Duration(seconds: s.duration),
              artUri: _resolveArtUri(s.coverArt),
              playable: true,
            )
          ];
        }
      }
      return [];
    } else if (parentMediaId == 'favorites' || parentMediaId == 'recently_played' || parentMediaId == 'downloads') {
      final state = await StorageService.loadPlaybackState();
      if (state != null) {
        final key = parentMediaId == 'favorites'
            ? 'favorites'
            : (parentMediaId == 'downloads' ? 'downloads' : 'recentlyPlayed');
        final List<dynamic> rawList = state[key] ?? [];
        return rawList.map((e) {
          final s = Song.fromJson(Map<String, dynamic>.from(e));
          return MediaItem(
            id: s.id,
            title: s.title,
            artist: s.artist,
            album: s.album,
            duration: Duration(seconds: s.duration),
            artUri: _resolveArtUri(s.coverArt),
            playable: true,
          );
        }).toList();
      }
    }
    return [];
  }

  @override
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) async {
    final state = await StorageService.loadPlaybackState();
    if (state != null) {
      final List<dynamic> rawFavs = state['favorites'] ?? [];
      final List<dynamic> rawRecent = state['recentlyPlayed'] ?? [];
      final List<dynamic> rawDown = state['downloads'] ?? [];
      final all = [...rawFavs, ...rawRecent, ...rawDown];
      for (final e in all) {
        final song = Song.fromJson(Map<String, dynamic>.from(e));
        if (song.id == mediaId) {
          final streamUrl = await locator<IMusicRepository>().getStreamUrl(song);
          if (streamUrl != null && streamUrl.isNotEmpty) {
            await playSong(song, streamUrl);
          }
          return;
        }
      }
    }
  }

  @override
  Future<void> playFromSearch(String query, [Map<String, dynamic>? extras]) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return play();
    }
    try {
      final results = await locator<IMusicRepository>().search(cleanQuery);
      if (results.isNotEmpty) {
        final song = results.first;
        final streamUrl = await locator<IMusicRepository>().getStreamUrl(song);
        if (streamUrl != null && streamUrl.isNotEmpty) {
          await playSong(song, streamUrl);
        }
      }
    } catch (e) {
      debugPrint('[AudioPlayerHandler] playFromSearch failed: $e');
    }
  }

  @override
  Future<void> playFromUri(Uri uri, [Map<String, dynamic>? extras]) async {
    return play();
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    if (mediaItem.value?.id == mediaId) {
      return mediaItem.value;
    }
    final state = await StorageService.loadPlaybackState();
    if (state != null) {
      final List<dynamic> rawFavs = state['favorites'] ?? [];
      final List<dynamic> rawRecent = state['recentlyPlayed'] ?? [];
      final List<dynamic> rawDown = state['downloads'] ?? [];
      final all = [...rawFavs, ...rawRecent, ...rawDown];
      for (final e in all) {
        final s = Song.fromJson(Map<String, dynamic>.from(e));
        if (s.id == mediaId) {
          return MediaItem(
            id: s.id,
            title: s.title,
            artist: s.artist,
            album: s.album,
            duration: Duration(seconds: s.duration),
            artUri: _resolveArtUri(s.coverArt),
            playable: true,
          );
        }
      }
    }
    return null;
  }

  // --- Smart Lockscreen Action ---
  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'like_song') {
      if (onToggleFavorite != null) {
        await onToggleFavorite!();
      }
    }
    return super.customAction(name, extras);
  }

  Future<void> disposeSubscriptions() async {
    await _playerPlayingSub?.cancel();
    _playerPlayingSub = null;
    await _playerPositionSub?.cancel();
    _playerPositionSub = null;
    await _playerCompletedSub?.cancel();
    _playerCompletedSub = null;
    await _playerBufferingSub?.cancel();
    _playerBufferingSub = null;
    await _smtcSubscription?.cancel();
    _smtcSubscription = null;
    await _playerErrorSub?.cancel();
    _playerErrorSub = null;
    await _audioDevicesSubscription?.cancel();
    _audioDevicesSubscription = null;
    await _audioDeviceSubscription?.cancel();
    _audioDeviceSubscription = null;
    await _becomingNoisySubscription?.cancel();
    _becomingNoisySubscription = null;
    await _devicesChangedSubscription?.cancel();
    _devicesChangedSubscription = null;
    await _interruptionSubscription?.cancel();
    _interruptionSubscription = null;
  }

  /// Deterministic shutdown and teardown of AudioPlayerHandler and underlying libmpv player.
  /// Guarantees that all callbacks and audio filter graphs are flushed before Dart isolate destruction.
  Future<void> dispose() async {
    if (_isDisposed || _isDisposing) return;
    _isDisposing = true;
    try {
      // 1. Immediately detach EqualizerService to prevent late filter applications
      try {
        if (locator.isRegistered<EqualizerService>()) {
          await locator<EqualizerService>().detachPlayer(_player);
        }
      } catch (e) {
        debugPrint('[AudioPlayerHandler] Error detaching EqualizerService during disposal: $e');
      }

      // 2. Mute player volume to avoid audio pops/stutters during teardown
      try {
        await _player.setVolume(0.0);
      } catch (_) {}

      // 3. Stop playback engine
      try {
        await _player.stop();
      } catch (_) {}

      // 4. Cancel all stream subscriptions
      await disposeSubscriptions();

      // 5. Clean up Windows SMTC
      try {
        _smtc?.dispose();
        _smtc = null;
      } catch (_) {}

      // 6. Clear external closures/callbacks to release references
      onSkipNext = null;
      onSkipPrevious = null;
      onTrackCompleted = null;
      onToggleFavorite = null;
      onPlaybackError = null;

      // 7. Dispose native player and release underlying libmpv handle
      try {
        await _player.dispose();
      } catch (e) {
        debugPrint('[AudioPlayerHandler] Error disposing media_kit player: $e');
      }
    } finally {
      _isDisposed = true;
      _isDisposing = false;
    }
  }
}
