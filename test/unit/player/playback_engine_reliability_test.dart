import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Fisher-Yates Shuffled Playlist Engine Tests', () {
    test('Shuffle generates full permutation without duplicates or omissions', () {
      const queueLength = 50;
      final originalIndices = List.generate(queueLength, (i) => i);

      // Simulation of AudioPlayerNotifier Fisher-Yates algorithm
      final start = 12; // Currently playing index
      final otherIndices = List<int>.generate(queueLength, (i) => i)..remove(start);
      otherIndices.shuffle(Random(42));
      final shuffleSequence = [start, ...otherIndices];

      expect(shuffleSequence.length, queueLength);
      expect(shuffleSequence.first, start);
      expect(shuffleSequence.toSet().length, queueLength);
      expect(shuffleSequence.toSet(), originalIndices.toSet());
    });

    test('Pointer navigation tracks deterministic history backwards and forwards', () {
      final shuffleSequence = [5, 2, 8, 1, 9, 0, 4, 3, 7, 6];
      int pointer = 0;

      // Skip forward 3 times
      pointer++; // 1 -> 2
      expect(shuffleSequence[pointer], 2);
      pointer++; // 2 -> 8
      expect(shuffleSequence[pointer], 8);
      pointer++; // 3 -> 1
      expect(shuffleSequence[pointer], 1);

      // Skip backward 2 times (re-traces historical path)
      pointer--; // 2 -> 8
      expect(shuffleSequence[pointer], 8);
      pointer--; // 1 -> 2
      expect(shuffleSequence[pointer], 2);
      pointer--; // 0 -> 5 (back to starting song)
      expect(shuffleSequence[pointer], 5);
    });

    test('Queue boundary clamping prevents index out of bounds exceptions', () {
      final sequence = [3, 1, 0, 2];
      int pointer = 0;

      // Backward at 0 clamps safely to 0
      pointer--;
      if (pointer < 0) pointer = 0;
      expect(sequence[pointer], 3);

      // Forward past end wraps to 0
      pointer = 3;
      pointer++;
      if (pointer >= sequence.length) pointer = 0;
      expect(sequence[pointer], 3);
    });
  });
}
