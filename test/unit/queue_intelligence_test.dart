import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/intelligence/queue/queue_intelligence_service.dart';

void main() {
  group('QueueIntelligenceService Tests', () {
    late QueueIntelligenceService queueService;

    final songA = Song(
      id: 'song_a',
      saavnId: 'song_a',
      title: 'Explicit Song A',
      artist: 'Artist A',
      album: 'Album',
      duration: 200,
      coverArt: '',
      addedAt: DateTime.now(),
    );

    final songB = Song(
      id: 'song_b',
      saavnId: 'song_b',
      title: 'Explicit Song B',
      artist: 'Artist B',
      album: 'Album',
      duration: 180,
      coverArt: '',
      addedAt: DateTime.now(),
    );

    final songContinuation = Song(
      id: 'song_c',
      saavnId: 'song_c',
      title: 'Continuation Song C',
      artist: 'Artist C',
      album: 'Album',
      duration: 210,
      coverArt: '',
      addedAt: DateTime.now(),
    );

    setUp(() {
      queueService = QueueIntelligenceService();
      queueService.clear();
    });

    test('explicit user queue takes strict priority over continuation tracks', () {
      // 1. Enqueue explicit song A
      queueService.enqueueExplicit(songA);

      // 2. Simulate continuation queue having song C
      queueService.enqueueExplicit(songB);

      // Pop next track should yield song A first, then song B
      final firstPopped = queueService.popNextTrack();
      expect(firstPopped?.id, 'song_a');

      final secondPopped = queueService.popNextTrack();
      expect(secondPopped?.id, 'song_b');

      final thirdPopped = queueService.popNextTrack();
      expect(thirdPopped, isNull);
    });

    test('playNext inserts at head of explicit queue', () {
      queueService.enqueueExplicit(songA);
      // User says "Play Next" for song B
      queueService.enqueueExplicit(songB, playNext: true);

      // song B must pop BEFORE song A
      final first = queueService.popNextTrack();
      expect(first?.id, 'song_b');

      final second = queueService.popNextTrack();
      expect(second?.id, 'song_a');
    });

    test('reordering explicit queue moves item correctly', () {
      queueService.enqueueExplicit(songA);
      queueService.enqueueExplicit(songB);

      expect(queueService.explicitQueue.first.id, 'song_a');

      // Move song_b from index 1 to index 0
      queueService.reorderExplicitQueue(1, 0);

      expect(queueService.explicitQueue.first.id, 'song_b');
      expect(queueService.explicitQueue[1].id, 'song_a');
    });
  });
}
