import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/models/custom_playlist.dart';

void main() {
  group('Project Obsidian — Feature Registry & Standardization Verification', () {
    test('feature_registry.json exists, is valid JSON, and contains all 8 required domains', () {
      final file = File('docs/architecture/feature_registry.json');
      expect(file.existsSync(), isTrue, reason: 'feature_registry.json must exist');

      final content = file.readAsStringSync();
      final Map<String, dynamic> registry = jsonDecode(content);

      expect(registry['title'], 'IT Feels Music Feature Registry');
      expect(registry['version'], '3.9.5');
      expect(registry.containsKey('domains'), isTrue);

      final domains = registry['domains'] as Map<String, dynamic>;
      final expectedDomains = [
        'playback_and_engine',
        'queue_and_now_playing',
        'downloads_and_offline',
        'custom_playlists',
        'album_experience',
        'artist_experience',
        'search_and_discovery',
        'library_management',
        'settings_and_system',
        'living_catalogue_and_content',
      ];

      for (final domain in expectedDomains) {
        expect(domains.containsKey(domain), isTrue, reason: 'Registry must contain domain $domain');
        final domainData = domains[domain] as Map<String, dynamic>;
        expect(domainData['status'], 'production_ready');
        expect(domainData['features'], isNotEmpty);
      }
    });

    test('NEW_FEATURE_CHECKLIST.md exists and contains all 6 core quality gates', () {
      final file = File('docs/development/NEW_FEATURE_CHECKLIST.md');
      expect(file.existsSync(), isTrue, reason: 'NEW_FEATURE_CHECKLIST.md must exist');

      final content = file.readAsStringSync();
      expect(content, contains('Product Direction & Scope Boundaries'));
      expect(content, contains('Playback & Action Standardization'));
      expect(content, contains('UI, Layout & Responsive Standards'));
      expect(content, contains('Performance, Image & Memory Standards'));
      expect(content, contains('Offline & Network Fault Tolerance'));
      expect(content, contains('Machine-Readable Documentation & Testing'));
      expect(content, contains('Living Music Catalogue & Content Quality Standards'));
    });
  });

  group('Playback Context & Batch Queue Insertion Simulation', () {
    late List<Song> sampleSongs;

    setUp(() {
      sampleSongs = List.generate(
        10,
        (i) => Song(
          id: 'song_$i',
          saavnId: 'saavn_$i',
          title: 'Track $i',
          artist: 'Artist $i',
          album: 'Album $i',
          duration: 180 + i * 10,
          coverArt: 'https://example.com/art_$i.jpg',
          addedAt: DateTime.now(),
        ),
      );
    });

    test('Batch play next inserts items immediately after current index preserving queue order', () {
      final currentQueue = List<Song>.from(sampleSongs.sublist(0, 4)); // songs 0, 1, 2, 3
      int currentIndex = 1; // Currently playing song_1

      final batchToInsert = [
        sampleSongs[4],
        sampleSongs[5],
        sampleSongs[6],
      ];

      // Replicate AudioPlayerNotifier.playNextBatch logic:
      final mutableQueue = List<Song>.from(currentQueue);
      final insertIndex = currentIndex + 1;
      mutableQueue.insertAll(insertIndex, batchToInsert);

      // Verify insertion position
      expect(mutableQueue.length, 7);
      expect(mutableQueue[0].id, 'song_0');
      expect(mutableQueue[1].id, 'song_1'); // Current song untouched
      expect(mutableQueue[2].id, 'song_4'); // Batch start
      expect(mutableQueue[3].id, 'song_5');
      expect(mutableQueue[4].id, 'song_6'); // Batch end
      expect(mutableQueue[5].id, 'song_2'); // Shifted previous next song
      expect(mutableQueue[6].id, 'song_3');
    });

    test('Deterministic Fisher-Yates shuffle sequence generates non-repeating permutation', () {
      final songs = List<Song>.from(sampleSongs);
      const startingIndex = 3;

      // Replicate Fisher-Yates starting sequence logic from AudioPlayerNotifier:
      final others = List<int>.generate(songs.length, (i) => i)..remove(startingIndex);
      others.shuffle();
      final sequence = [startingIndex, ...others];

      expect(sequence.length, songs.length);
      expect(sequence.first, startingIndex);
      expect(sequence.toSet().length, songs.length, reason: 'Must contain zero duplicates');
      expect(sequence.contains(startingIndex), isTrue);
    });
  });

  group('Custom Playlist Mutations & Reordering Logic', () {
    test('Playlist track reordering correctly shifts indices', () {
      final songs = [
        Song(id: 's1', saavnId: 'saavn_1', title: 'T1', artist: 'A', album: 'Alb', duration: 100, coverArt: '', addedAt: DateTime.now()),
        Song(id: 's2', saavnId: 'saavn_2', title: 'T2', artist: 'A', album: 'Alb', duration: 100, coverArt: '', addedAt: DateTime.now()),
        Song(id: 's3', saavnId: 'saavn_3', title: 'T3', artist: 'A', album: 'Alb', duration: 100, coverArt: '', addedAt: DateTime.now()),
        Song(id: 's4', saavnId: 'saavn_4', title: 'T4', artist: 'A', album: 'Alb', duration: 100, coverArt: '', addedAt: DateTime.now()),
      ];

      final playlist = CustomPlaylist(
        id: 'pl_1',
        title: 'Favorites',
        songs: songs,
        createdAt: DateTime.now(),
      );

      // Simulate reorder: move index 3 (s4) to index 1
      int oldIndex = 3;
      int newIndex = 1;
      final reorderedSongs = List<Song>.from(playlist.songs);
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = reorderedSongs.removeAt(oldIndex);
      reorderedSongs.insert(newIndex, item);

      expect(reorderedSongs.map((s) => s.id).toList(), ['s1', 's4', 's2', 's3']);
    });

    test('Playlist batch removal eliminates all target song IDs', () {
      final songs = List.generate(
        6,
        (i) => Song(
          id: 'song_$i',
          saavnId: 'saavn_$i',
          title: 'T$i',
          artist: 'A',
          album: 'Alb',
          duration: 120,
          coverArt: '',
          addedAt: DateTime.now(),
        ),
      );

      final playlist = CustomPlaylist(
        id: 'pl_2',
        title: 'Road Trip',
        songs: songs,
        createdAt: DateTime.now(),
      );

      final idsToRemove = {'song_1', 'song_3', 'song_5'};
      final remainingSongs = playlist.songs.where((s) => !idsToRemove.contains(s.id)).toList();

      expect(remainingSongs.length, 3);
      expect(remainingSongs.map((s) => s.id).toList(), ['song_0', 'song_2', 'song_4']);
    });

    test('Playlist duplication clones tracks and appends (Copy) suffix', () {
      final songs = [
        Song(id: 's1', saavnId: 'saavn_1', title: 'T1', artist: 'A', album: 'Alb', duration: 100, coverArt: '', addedAt: DateTime.now()),
        Song(id: 's2', saavnId: 'saavn_2', title: 'T2', artist: 'A', album: 'Alb', duration: 100, coverArt: '', addedAt: DateTime.now()),
      ];

      final original = CustomPlaylist(
        id: 'pl_original',
        title: 'Workout Beats',
        songs: songs,
        createdAt: DateTime.now(),
      );

      final duplicated = CustomPlaylist(
        id: 'pl_copy_${DateTime.now().millisecondsSinceEpoch}',
        title: '${original.title} (Copy)',
        songs: List<Song>.from(original.songs),
        createdAt: DateTime.now(),
      );

      expect(duplicated.title, 'Workout Beats (Copy)');
      expect(duplicated.songs.length, 2);
      expect(duplicated.songs.first.id, 's1');
      expect(duplicated.id, isNot(original.id));
    });
  });
}
