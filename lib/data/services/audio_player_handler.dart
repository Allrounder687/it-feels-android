/// `AudioPlayerHandler` extends [BaseAudioHandler] from the `audio_service` package
/// and integrates with the `just_audio` package to provide robust background audio playback
/// capabilities. It serves as the primary interface for managing audio playback,
/// interacting with system media controls (notifications, lock screen, Bluetooth),
/// and handling audio focus.
///
/// This class is responsible for:
/// - Initializing and managing the [AudioPlayer] instance.
/// - Broadcasting playback state changes to the Android system to update notifications
///   and lock screen controls.
/// - Implementing core media playback actions: play, pause, stop, seek.
/// - Translating `audio_service`'s shuffle and repeat modes to `just_audio`'s [LoopMode].
/// - Handling potential errors during audio source setting.
class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  /// The underlying [AudioPlayer] instance from `just_audio` that handles
  /// the actual audio playback.
  final AudioPlayer _player = AudioPlayer();

  /// Constructs an [AudioPlayerHandler] and initializes its internal listeners.
  AudioPlayerHandler() {
    _init();
  }

  /// Returns the internal `just_audio` player instance.
  /// This is used by [AudioPlayerProvider] to listen to streams like position, duration, etc.
  AudioPlayer get player => _player;

  /// Initializes the audio handler by setting up listeners for `just_audio`'s
  /// playback events. These events are then transformed and broadcasted to the
  /// `audio_service`'s [playbackState] stream, which the Android system uses
  /// to update media notifications and controls.
  ///
  /// The `playbackState` includes information like:
  /// - `controls`: Available media controls (play, pause, next, previous).
  /// - `systemActions`: Actions supported by the system (seek).
  /// - `androidCompactActionIndices`: Indices of controls to show in compact notification view.
  /// - `processingState`: Current state of audio processing (loading, buffering, ready, completed).
  /// - `playing`: Boolean indicating if audio is actively playing.
  /// - `updatePosition`: Current playback position.
  /// - `bufferedPosition`: Current buffered position.
  /// - `queueIndex`: Index of the current item in the playback queue.
  void _init() {
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ));
    });
  }

  /// Loads and plays a [song] from a given [streamUrl].
  ///
  /// This method constructs a [MediaItem] from the [Song] object and adds it
  /// to `audio_service`'s `mediaItem` stream, making the song's metadata available
  /// to system media controls.
  ///
  /// Data Flow:
  /// 1. Creates a [MediaItem] with song details (id, album, title, artist, duration, coverArt).
  /// 2. Updates `audio_service`'s [mediaItem] with this new item.
  /// 3. Attempts to set the [streamUrl] to the `just_audio` player.
  /// 4. If successful, starts playback using `_player.play()`.
  /// 5. Catches and logs any errors during the process of setting the audio source.
  Future<void> playSong(Song song, String streamUrl) async {
    final mediaItem = MediaItem(
      id: song.id,
      album: song.album,
      title: song.title,
      artist: song.artist,
      duration: Duration(seconds: song.duration),
      artUri: song.coverArt.isNotEmpty ? Uri.tryParse(song.coverArt) : null,
    );

    this.mediaItem.add(mediaItem); // Update system media controls with new song info

    try {
      await _player.setUrl(streamUrl); // Set the audio source
      await _player.play(); // Start playback
    } catch (e) {
      debugPrint('[AudioPlayerHandler] Error setting audio source for ${song.title}: $e');
      // Additional error handling could include showing a user-facing error message,
      // skipping to the next song, or retrying.
    }
  }

  @override
  /// Implements the `play` action for `audio_service`, delegating to `just_audio`.
  Future<void> play() => _player.play();

  @override
  /// Implements the `pause` action for `audio_service`, delegating to `just_audio`.
  Future<void> pause() => _player.pause();

  @override
  /// Implements the `stop` action for `audio_service`, delegating to `just_audio`.
  Future<void> stop() => _player.stop();

  @override
  /// Implements the `seek` action for `audio_service`, delegating to `just_audio`.
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  /// Sets the shuffle mode for the `just_audio` player based on `audio_service`'s [shuffleMode].
  ///
  /// Note: The actual reordering of the playback queue is typically handled
  /// by the [AudioPlayerProvider] or similar higher-level logic, with this
  /// method primarily enabling/disabling the shuffle behavior of the underlying player.
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    await _player.setShuffleModeEnabled(enabled);
  }

  @override
  /// Sets the repeat mode for the `just_audio` player based on `audio_service`'s [repeatMode].
  ///
  /// It maps `AudioServiceRepeatMode` values to `just_audio`'s [LoopMode].
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    LoopMode loopMode;
    switch (repeatMode) {
      case AudioServiceRepeatMode.one:
        loopMode = LoopMode.one;
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group: // Group repeat treated as all
        loopMode = LoopMode.all;
        break;
      case AudioServiceRepeatMode.none:
        loopMode = LoopMode.off;
        break;
    }
    await _player.setLoopMode(loopMode);
  }
}
