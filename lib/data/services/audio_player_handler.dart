import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';
import 'music_api_service.dart';
import '../../services/storage_service.dart';

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
      audioPipeline: AudioPipeline(
        androidAudioEffects: [
          _equalizer,
          _loudnessEnhancer,
        ],
      ),
    );
    _init();
  }

  AudioPlayer get player => _player;
  AndroidEqualizer get equalizer => _equalizer;
  AndroidLoudnessEnhancer get loudnessEnhancer => _loudnessEnhancer;

  void _init() {
    _player.playbackEventStream.listen((PlaybackEvent event) {
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
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: audioProcessingState,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ));
    });
  }

  Future<void> playSong(Song song, String streamUrl) async {
    try {
      mediaItem.add(MediaItem(
        id: song.id,
        album: song.album,
        title: song.title,
        artist: song.artist,
        duration: Duration(seconds: song.duration),
        artUri: song.coverArt.isNotEmpty ? (song.coverArt.startsWith('http') ? Uri.parse(song.coverArt) : Uri.file(song.coverArt)) : null,
      ));

      await _player.setUrl(streamUrl);
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
          id: 'favorites',
          title: 'Favorites',
          playable: false,
        ),
      ];
    } else if (parentMediaId == 'favorites') {
      final state = await StorageService.loadPlaybackState();
      if (state != null && state['favorites'] != null) {
        final List<dynamic> rawFavs = state['favorites'];
        return rawFavs.map((e) {
          final s = Song.fromJson(Map<String, dynamic>.from(e));
          return MediaItem(
            id: s.id,
            title: s.title,
            artist: s.artist,
            album: s.album,
            duration: Duration(seconds: s.duration),
            artUri: s.coverArt.isNotEmpty ? Uri.parse(s.coverArt) : null,
          );
        }).toList();
      }
    }
    return [];
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
