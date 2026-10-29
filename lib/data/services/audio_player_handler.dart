import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:io';
import 'dart:async';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:smtc_windows/smtc_windows.dart';
import 'package:it_feels_music/services/storage_service.dart';

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  late final Player _player;
  final IMusicRepository apiService;
  
  VoidCallback? onSkipNext;
  VoidCallback? onSkipPrevious;
  VoidCallback? onTrackCompleted;
  Future<void> Function()? onToggleFavorite;
  bool _isLoadingTrack = false;
  
  SMTCWindows? _smtc;
  StreamSubscription? _smtcSubscription;

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
    
    _player.stream.playing.listen((playing) {
      _broadcastState();
    });
    _player.stream.position.listen((pos) {
      _broadcastState();
    });
    _player.stream.completed.listen((completed) {
      if (completed) {
        _broadcastState(); // Do not emit isCompleted to prevent iOS teardown
        if (onTrackCompleted != null) {
          onTrackCompleted!();
        } else if (onSkipNext != null) {
          onSkipNext!();
        }
      }
    });
    _player.stream.buffering.listen((buffering) {
      _broadcastState(isBuffering: buffering);
    });
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
      _smtc!.setPlaybackStatus(playing ? PlaybackStatus.playing : PlaybackStatus.paused);
      
      try {
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

  void notifyLoading(Song song) {
    _isLoadingTrack = true;
    final item = MediaItem(
      id: song.id,
      album: song.album,
      title: song.title,
      artist: song.artist,
      duration: Duration(seconds: song.duration),
      artUri: song.coverArt.isNotEmpty
          ? (song.coverArt.startsWith('http')
              ? Uri.parse(song.coverArt)
              : Uri.file(song.coverArt))
          : null,
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
    try {
      _isLoadingTrack = false;
      final item = MediaItem(
        id: song.id,
        album: song.album,
        title: song.title,
        artist: song.artist,
        duration: Duration(seconds: song.duration),
        artUri: song.coverArt.isNotEmpty ? (song.coverArt.startsWith('http') ? Uri.parse(song.coverArt) : Uri.file(song.coverArt)) : null,
      );
      mediaItem.add(item);
      
      if (_smtc != null) {
        _smtc!.updateMetadata(MusicMetadata(
          title: song.title,
          artist: song.artist,
          album: song.album ?? '',
          thumbnail: song.coverArt,
        ));
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
      
      if (song.playbackPositionMs != null && song.playbackPositionMs! > 0) {
        await _player.seek(Duration(milliseconds: song.playbackPositionMs!));
      }
    } catch (e) {
      debugPrint('[AudioPlayerHandler] Error setting stream URL: $e');
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {}

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

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
    if (settings['enableAndroidAuto'] != true) return [];

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
      ];
    } else if (parentMediaId == 'favorites' || parentMediaId == 'recently_played') {
      final state = await StorageService.loadPlaybackState();
      if (state != null) {
        final key = parentMediaId == 'favorites' ? 'favorites' : 'recentlyPlayed';
        final List<dynamic> rawList = state[key] ?? [];
        return rawList.map((e) {
          final s = Song.fromJson(Map<String, dynamic>.from(e));
          return MediaItem(
            id: s.id,
            title: s.title,
            artist: s.artist,
            album: s.album,
            duration: Duration(seconds: s.duration),
            artUri: s.coverArt.isNotEmpty ? (s.coverArt.startsWith('http') ? Uri.parse(s.coverArt) : Uri.file(s.coverArt)) : null,
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
      final all = [...rawFavs, ...rawRecent];
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
  Future<MediaItem?> getMediaItem(String mediaId) async {
    return null; // Fallback
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
    await _smtcSubscription?.cancel();
  }
}
