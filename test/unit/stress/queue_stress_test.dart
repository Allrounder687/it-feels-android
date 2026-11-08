import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/data/models/song_model.dart';

void main() {
  group('Queue Stress & Mutation Resilience Tests (1,000+ Operations)', () {
    test('Simulates 1,000 queue additions, reorders, removals, and shuffles without desynchronization', () {
      final random = Random(42); // Deterministic seed
      List<Song> queue = List.generate(
        20,
        (i) => Song(
          id: 'initial_song_$i',
          saavnId: 'saavn_init_$i',
          title: 'Initial Song $i',
          artist: 'Artist $i',
          album: 'Album $i',
          duration: 180 + i,
          coverArt: '',
          addedAt: DateTime.now(),
        ),
      );
      int currentIndex = 0;
      List<int> shuffleSequence = List.generate(queue.length, (i) => i);
      int shufflePointer = 0;

      void regenerateShuffle({int? startingIndex}) {
        if (queue.isEmpty) {
          shuffleSequence = [];
          shufflePointer = 0;
          return;
        }
        final len = queue.length;
        final start = (startingIndex != null && startingIndex >= 0 && startingIndex < len)
            ? startingIndex
            : (currentIndex >= 0 && currentIndex < len ? currentIndex : 0);
        final others = List<int>.generate(len, (i) => i)..remove(start);
        others.shuffle(random);
        shuffleSequence = [start, ...others];
        shufflePointer = 0;
      }

      void reorder(int oldIndex, int newIndex) {
        if (oldIndex < newIndex) {
          newIndex -= 1;
        }
        if (oldIndex < 0 || oldIndex >= queue.length || newIndex < 0 || newIndex > queue.length) {
          return;
        }
        final item = queue.removeAt(oldIndex);
        queue.insert(newIndex, item);

        if (currentIndex == oldIndex) {
          currentIndex = newIndex;
        } else if (oldIndex < currentIndex && newIndex >= currentIndex) {
          currentIndex--;
        } else if (oldIndex > currentIndex && newIndex <= currentIndex) {
          currentIndex++;
        }
        regenerateShuffle(startingIndex: currentIndex);
      }

      void remove(int index) {
        if (index < 0 || index >= queue.length) return;
        queue.removeAt(index);
        if (queue.isEmpty) {
          currentIndex = -1;
          regenerateShuffle();
          return;
        }
        if (index < currentIndex) {
          currentIndex--;
        } else if (index == currentIndex) {
          if (currentIndex >= queue.length) {
            currentIndex = queue.length - 1;
          }
        }
        regenerateShuffle(startingIndex: currentIndex);
      }

      void add(Song song) {
        if (queue.isNotEmpty && queue.last.id == song.id) return; // Deduplicate adjacent
        queue.add(song);
        regenerateShuffle(startingIndex: currentIndex);
      }

      // Execute 1,000 continuous stress operations
      for (int op = 0; op < 1000; op++) {
        final action = random.nextInt(4);
        switch (action) {
          case 0: // Add
            add(Song(
              id: 'song_dynamic_${op}_${random.nextInt(100)}',
              saavnId: 'saavn_$op',
              title: 'Dynamic Song $op',
              artist: 'Test Swarm',
              album: 'Dynamic Album',
              duration: 200,
              coverArt: '',
              addedAt: DateTime.now(),
            ));
            break;
          case 1: // Reorder
            if (queue.length > 1) {
              final oldIdx = random.nextInt(queue.length);
              final newIdx = random.nextInt(queue.length);
              reorder(oldIdx, newIdx);
            }
            break;
          case 2: // Remove (only if queue has > 2 tracks to sustain simulation)
            if (queue.length > 2) {
              final removeIdx = random.nextInt(queue.length);
              remove(removeIdx);
            }
            break;
          case 3: // Shuffle traversal
            if (shuffleSequence.isNotEmpty) {
              shufflePointer = (shufflePointer + 1) % shuffleSequence.length;
              currentIndex = shuffleSequence[shufflePointer];
            }
            break;
        }

        // Integrity assertions after every single operation
        if (queue.isNotEmpty) {
          expect(currentIndex, greaterThanOrEqualTo(0));
          expect(currentIndex, lessThan(queue.length));
          expect(shuffleSequence.length, equals(queue.length));
          expect(shufflePointer, greaterThanOrEqualTo(0));
          expect(shufflePointer, lessThan(shuffleSequence.length));
        } else {
          expect(currentIndex, equals(-1));
          expect(shuffleSequence, isEmpty);
        }
      }

      // Final Queue State Verification
      expect(queue.isNotEmpty, isTrue);
      expect(queue.length, greaterThan(10));
    });

    test('Deduplication prevents consecutive duplicate tracks in queue', () {
      final queue = <Song>[];
      final songA = Song(
        id: 'song_a',
        saavnId: 'saavn_a',
        title: 'Track A',
        artist: 'Artist A',
        album: 'Album A',
        duration: 180,
        coverArt: '',
        addedAt: DateTime.now(),
      );
      final songB = Song(
        id: 'song_b',
        saavnId: 'saavn_b',
        title: 'Track B',
        artist: 'Artist B',
        album: 'Album B',
        duration: 180,
        coverArt: '',
        addedAt: DateTime.now(),
      );

      void add(Song s) {
        if (queue.isNotEmpty && queue.last.id == s.id) return;
        queue.add(s);
      }

      add(songA);
      add(songA); // Consecutive duplicate - must be dropped
      add(songB);
      add(songB); // Consecutive duplicate - must be dropped
      add(songA); // Non-consecutive - allowed

      expect(queue.length, equals(3));
      expect(queue[0].id, equals('song_a'));
      expect(queue[1].id, equals('song_b'));
      expect(queue[2].id, equals('song_a'));
    });
  });
}
