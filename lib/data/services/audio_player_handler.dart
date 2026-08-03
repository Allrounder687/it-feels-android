import 'package:it_feels_music/services/backend_api_service.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'package:it_feels_music/data/models/song_model.dart';
import 'music_api_service.dart';
import 'package:it_feels_music/services/storage_service.dart';

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  late final AudioPlayer _player;
  late final AndroidEqualizer _equalizer;
  late final AndroidLoudnessEnhancer _loudnessEnhancer;
  final MusicApiService apiService;
  
  VoidCallback? onSkipNext;
  VoidCallback? onSkipPrevious;
  Future<void> Function()? onToggleFavorite;

  AudioPlayerHandler({required this.apiService}) {
    _equalizer = AndroidEqualizer();
    _loudnessEnhancer = AndroidLoudnessEnhancer();
    _player = AudioPlayer(
      audioPipeline: (!kIsWeb && Platform.isAndroid)
          ? AudioPipeline(
              androidAudioEffects: [
                _equalizer,
                _loudnessEnhancer,
              ],
            )
          : null,
    );
    _init();
  }

  AudioPlayer get player => _player;
  AndroidEqualizer get equalizer => _equalizer;
  AndroidLoudnessEnhancer get loudnessEnhancer => _loudnessEnhancer;

  void _init() {
    _player.playbackEventStream.listen(_broadcastState);
    _player.playingStream.listen((_) {
      if (_player.playbackEvent != null) {
        _broadcastState(_player.playbackEvent);
      }
    });
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    final pState = _player.processingState;
    AudioProcessingState audioProcessingState;
    switch (pState) {
      case ProcessingState.idle:
        audioProcessingState = AudioProcessingState.idle;
        break;
      case ProcessingState.loading:
        audioProcessingState = AudioProcessingState.loading;
        break;
      case ProcessingState.buffering:
        audioProcessingState = AudioProcessingState.buffering;
        break;
      case ProcessingState.ready:
        audioProcessingState = AudioProcessingState.ready;
        break;
      case ProcessingState.completed:
        audioProcessingState = AudioProcessingState.completed;
        break;
    }

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
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
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  Future<void> playSong(Song song, String streamUrl) async {
    try {
      final item = MediaItem(
        id: song.id,
        album: song.album,
        title: song.title,
        artist: song.artist,
        duration: Duration(seconds: song.duration),
        artUri: song.coverArt.isNotEmpty ? (song.coverArt.startsWith('http') ? Uri.parse(song.coverArt) : Uri.file(song.coverArt)) : null,
      );
      mediaItem.add(item);

      if (streamUrl.startsWith('/') || streamUrl.startsWith('file://')) {
        final path = streamUrl.startsWith('file://') ? streamUrl.replaceFirst('file://', '') : streamUrl;
        await _player.setAudioSource(
          AudioSource.file(path, tag: item),
          initialPosition: Duration.zero,
        );
      } else {
        await _player.setAudioSource(
          LockCachingAudioSource(
            Uri.parse(streamUrl),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': '*/*',
            },
            tag: item,
          ),
          initialPosition: Duration.zero,
        );
      }
      await _player.play();
    } catch (e) {
      debugPrint('[AudioPlayerHandler] Error setting stream URL: $e');
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    // Kept to avoid breaking provider skipToQueueItem calls if any, but provider uses playSong
  }

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

  // --- Android Auto Integration ---
  @override
  Future<List<MediaItem>> getChildren(String parentMediaId, [Map<String, dynamic>? options]) async {
    final settings = await StorageService.loadSettings();
    if (settings['enableAndroidAuto'] != true) {
      return []; // Return empty if Android Auto is disabled
    }

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
          final streamUrl = await BackendApiService.getStreamUrl(song);
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
}
