import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/features/library/collection_download_queue.dart';
import 'discovery_and_mix_test.dart' show track;

void main() {
  test(
    'retry refreshes an expired source before trying the failed file again',
    () async {
      var attempts = 0, refreshes = 0;
      final queue = CollectionDownloadQueue(
        save: (_) async => ++attempts > 1,
        isSaved: (_) => false,
        prepareRetry: (_) async {
          refreshes++;
        },
      );
      addTearDown(queue.dispose);
      await queue.start('mix', 'Mix', () async => [track('song')]);
      expect(queue.job('mix')!.phase, CollectionDownloadPhase.failed);
      await queue.start('mix', 'Mix', () async => [track('song')]);
      expect(refreshes, 1);
      expect(queue.job('mix')!.phase, CollectionDownloadPhase.complete);
    },
  );
  test(
    'download actions deduplicate files, skip offline tracks and retain failure counts',
    () async {
      final calls = <String>[];
      final queue = CollectionDownloadQueue(
        save: (s) async {
          calls.add(s.id);
          return s.id != 'bad';
        },
        isSaved: (id) => id == 'offline',
      );
      addTearDown(queue.dispose);
      await queue.start(
        'mix',
        'Mix',
        () async => [
          track('offline'),
          track('one'),
          track('one'),
          track('bad'),
        ],
      );
      expect(calls, ['one', 'bad']);
      expect(queue.job('mix')!.total, 3);
      expect(queue.job('mix')!.saved, 2);
      expect(queue.job('mix')!.failed, 1);
      expect(queue.job('mix')!.phase, CollectionDownloadPhase.partial);
    },
  );
  test(
    'repeated taps share one job and different collections execute serially',
    () async {
      final gate = Completer<bool>();
      var active = 0, maximum = 0;
      final queue = CollectionDownloadQueue(
        save: (s) async {
          active++;
          if (active > maximum) maximum = active;
          final r = await gate.future;
          active--;
          return r;
        },
        isSaved: (_) => false,
      );
      addTearDown(queue.dispose);
      var loads = 0;
      Future<List<dynamic>> unused() async => [];
      final a = queue.start('a', 'A', () async {
        loads++;
        return [track('one')];
      });
      final duplicate = queue.start('a', 'A', () async {
        loads++;
        return [track('one')];
      });
      final b = queue.start('b', 'B', () async => [track('two')]);
      await Future<void>.delayed(Duration.zero);
      expect(queue.job('b')!.phase, CollectionDownloadPhase.queued);
      gate.complete(true);
      await Future.wait([a, duplicate, b]);
      expect(loads, 1);
      expect(maximum, 1);
    },
  );
  test(
    'cancel stops scheduling further songs and a later resume skips saved files',
    () async {
      final gate = Completer<bool>(), saved = <String>{}, calls = <String>[];
      final queue = CollectionDownloadQueue(
        save: (s) async {
          calls.add(s.id);
          if (s.id == 'one') await gate.future;
          saved.add(s.id);
          return true;
        },
        isSaved: saved.contains,
      );
      addTearDown(queue.dispose);
      final operation = queue.start(
        'mix',
        'Mix',
        () async => [track('one'), track('two')],
      );
      await Future<void>.delayed(Duration.zero);
      queue.cancel('mix');
      gate.complete(true);
      await operation;
      expect(calls, ['one']);
      expect(queue.job('mix')!.phase, CollectionDownloadPhase.canceled);
      await queue.start('mix', 'Mix', () async => [track('one'), track('two')]);
      expect(calls, ['one', 'two']);
    },
  );
  test(
    'an incomplete remote loader never downloads just its first page',
    () async {
      var calls = 0;
      final queue = CollectionDownloadQueue(
        save: (_) async {
          calls++;
          return true;
        },
        isSaved: (_) => false,
      );
      addTearDown(queue.dispose);
      await queue.start(
        'remote',
        'Remote',
        () async => throw const FormatException('incomplete'),
      );
      expect(calls, 0);
      expect(queue.job('remote')!.phase, CollectionDownloadPhase.failed);
    },
  );
  test(
    'one failed track does not abandon the remaining tracks or later jobs',
    () async {
      final calls = <String>[];
      final queue = CollectionDownloadQueue(
        save: (s) async {
          calls.add(s.id);
          if (s.id == 'bad') throw Exception('provider unavailable');
          return true;
        },
        isSaved: (_) => false,
      );
      addTearDown(queue.dispose);
      await queue.start(
        'one',
        'One',
        () async => [track('bad'), track('good')],
      );
      await queue.start('two', 'Two', () async => [track('later')]);
      expect(calls, ['bad', 'good', 'later']);
      expect(queue.job('two')!.phase, CollectionDownloadPhase.complete);
    },
  );
}
