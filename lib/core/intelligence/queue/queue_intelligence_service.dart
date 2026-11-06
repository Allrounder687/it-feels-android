import 'package:flutter/foundation.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/intelligence/taste/user_taste_profile.dart';
import 'package:it_feels_music/core/intelligence/recommendations/recommendation_pipeline.dart';

/// Intelligent queue manager separating explicit user enqueued tracks from
/// automated continuation / autoplay tracks, with generation token race protection.
class QueueIntelligenceService {
  static final QueueIntelligenceService _instance = QueueIntelligenceService._internal();
  factory QueueIntelligenceService() => _instance;
  static QueueIntelligenceService get instance => _instance;

  QueueIntelligenceService._internal({RecommendationPipeline? pipeline})
      : _pipeline = pipeline ?? RecommendationPipeline();

  final RecommendationPipeline _pipeline;

  final List<Song> _explicitUserQueue = [];
  final List<Song> _continuationQueue = [];
  final Set<String> _sessionPlayedSongIds = {};

  int _generationToken = 0;
  bool _isPrefetching = false;

  /// High-priority queue holding tracks explicitly queued by user ("Play Next" or "Add to Queue").
  List<Song> get explicitQueue => List.unmodifiable(_explicitUserQueue);

  /// Low-priority queue holding automatically replenished continuation tracks.
  List<Song> get continuationQueue => List.unmodifiable(_continuationQueue);

  /// Combined queue presenting explicit tracks first, followed by continuation discovery tracks.
  List<Song> get mergedQueue => [..._explicitUserQueue, ..._continuationQueue];

  /// Enqueues a track explicitly by user action.
  void enqueueExplicit(Song song, {bool playNext = false}) {
    // Prevent duplicate entries within explicit queue
    _explicitUserQueue.removeWhere((s) => s.id == song.id);
    if (playNext) {
      _explicitUserQueue.insert(0, song);
    } else {
      _explicitUserQueue.add(song);
    }
  }

  /// Removes a song from the explicit queue.
  void removeFromExplicitQueue(String songId) {
    _explicitUserQueue.removeWhere((s) => s.id == songId);
  }

  /// Reorders explicit user queue.
  void reorderExplicitQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _explicitUserQueue.length) return;
    if (newIndex < 0 || newIndex > _explicitUserQueue.length) return;

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = _explicitUserQueue.removeAt(oldIndex);
    _explicitUserQueue.insert(newIndex, item);
  }

  /// Fetches next song for playback:
  /// Explicit user tracks ALWAYS take strict precedence over continuation recommendations.
  Song? popNextTrack() {
    if (_explicitUserQueue.isNotEmpty) {
      final next = _explicitUserQueue.removeAt(0);
      _sessionPlayedSongIds.add(next.id);
      return next;
    }

    if (_continuationQueue.isNotEmpty) {
      final next = _continuationQueue.removeAt(0);
      _sessionPlayedSongIds.add(next.id);
      return next;
    }

    return null;
  }

  /// Records that a song has played to avoid duplicate plays within the session.
  void recordPlayed(String songId) {
    _sessionPlayedSongIds.add(songId);
  }

  /// Checks if prefetching is needed (e.g. continuation queue has <= 2 tracks).
  bool shouldPrefetch() => _continuationQueue.length <= 2 && !_isPrefetching;

  /// Asynchronously replenishes continuation queue using recommendation pipeline and token guards.
  Future<void> replenishContinuation({
    required Song anchorSong,
    required UserTasteProfile profile,
    int count = 10,
  }) async {
    if (_isPrefetching) return;
    _isPrefetching = true;
    final currentToken = ++_generationToken;

    try {
      final candidates = await _pipeline.execute(
        anchorSong: anchorSong,
        profile: profile,
        existingQueue: [..._sessionPlayedSongIds.map((id) => Song(id: id, saavnId: id, title: '', artist: '', album: '', duration: 0, coverArt: '', addedAt: DateTime.now())), ...mergedQueue],
        targetCount: count,
      );

      // Verify token to prevent async race conditions if user skipped rapidly
      if (currentToken != _generationToken) {
        debugPrint('[QueueIntelligence] Discarding stale prefetch for token $currentToken');
        return;
      }

      final seenIds = <String>{
        ..._sessionPlayedSongIds,
        ..._explicitUserQueue.map((s) => s.id),
        ..._continuationQueue.map((s) => s.id),
      };

      for (final scored in candidates) {
        if (seenIds.add(scored.song.id)) {
          _continuationQueue.add(scored.song);
        }
      }
    } catch (e) {
      debugPrint('[QueueIntelligence] Continuation replenishment failed: $e');
    } finally {
      _isPrefetching = false;
    }
  }

  /// Clears queue state for a fresh listening session.
  void clear() {
    _generationToken++;
    _explicitUserQueue.clear();
    _continuationQueue.clear();
    _sessionPlayedSongIds.clear();
    _isPrefetching = false;
  }
}
