import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/features/player/lyrics_provider.dart';
import 'package:it_feels_music/data/services/lyrics_service.dart';
import 'package:it_feels_music/data/services/audio_engine_service.dart';
import 'package:it_feels_music/features/new_experience/shell/new_desktop_player_bar.dart';
import 'package:it_feels_music/features/new_experience/shell/new_contextual_panel.dart';
import 'package:it_feels_music/features/new_experience/player/new_mini_player.dart';
import 'package:it_feels_music/features/player/queue_bottom_sheet.dart';
import 'package:it_feels_music/features/social/windows_safe_rtdb.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:it_feels_music/main.dart';

class MockMusicRepo extends Mock implements IMusicRepository {}
class MockDataSnapshot extends Mock implements DataSnapshot {}
class MockAudioEngineService extends Mock implements AudioEngineService {}

Song createTestSong(String id, String title, int duration) {
  return Song(
    id: id,
    saavnId: id,
    title: title,
    artist: 'Test Artist',
    album: 'Test Album',
    duration: duration,
    coverArt: 'https://example.com/art.jpg',
    addedAt: DateTime.now(),
  );
}

class TestAudioPlayerNotifier extends AudioPlayerNotifier {
  final AudioPlayerState _initial;
  TestAudioPlayerNotifier([AudioPlayerState? initial]) : _initial = initial ?? AudioPlayerState();

  @override
  AudioPlayerState build() => _initial;

  void updateState(AudioPlayerState newState) {
    state = newState;
  }
}

class TestLyricsNotifier extends LyricsNotifier {
  final LyricsState _initial;
  TestLyricsNotifier(this._initial);

  @override
  LyricsState build() => _initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Song testSong1;
  late Song testSong2;
  late List<LyricLine> testLines;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    if (!locator.isRegistered<IMusicRepository>()) {
      locator.registerSingleton<IMusicRepository>(MockMusicRepo());
    }
    if (!locator.isRegistered<LyricsService>()) {
      locator.registerSingleton<LyricsService>(LyricsService());
    }
    if (!locator.isRegistered<AudioEngineService>()) {
      final mockEngine = MockAudioEngineService();
      when(() => mockEngine.positionStream).thenAnswer((_) => Stream.value(const Duration(seconds: 45)));
      locator.registerSingleton<AudioEngineService>(mockEngine);
    }

    testSong1 = createTestSong('song_1', 'Track 1', 180);
    testSong2 = createTestSong('song_2', 'Track 2', 240);

    testLines = [
      LyricLine(time: const Duration(seconds: 0), text: 'Line 1: Hello World'),
      LyricLine(time: const Duration(seconds: 2), text: 'Line 2: Testing Semantics'),
      LyricLine(time: const Duration(seconds: 4), text: 'Line 3: Second verse'),
      LyricLine(time: const Duration(seconds: 6), text: 'Line 4: Chorus starts now'),
      LyricLine(time: const Duration(seconds: 8), text: 'Line 5: Fade out'),
    ];
  });

  group('Matrix Test Suite: Windows Crash & Semantics Tree Investigation', () {
    testWidgets('Test Matrix E1: NewDesktopPlayerBar scrubber and song transitions with active semantics', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final handle = tester.ensureSemantics();

      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentSong: testSong1,
          isPlaying: true,
          queue: [testSong1, testSong2],
        ),
      );

      final container = ProviderContainer(
        overrides: [
          audioPlayerProvider.overrideWith(() => notifier),
        ],
      );
      appProviderContainer = container;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: NewDesktopPlayerBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Track 1'), findsOneWidget);

      // Transition to song 2
      notifier.updateState(
        AudioPlayerState(
          currentSong: testSong2,
          isPlaying: true,
          queue: [testSong1, testSong2],
          currentIndex: 1,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Track 2'), findsOneWidget);

      handle.dispose();
      container.dispose();
    });

    testWidgets('Test Matrix E2: NewContextualPanel Queue Reordering with active semantics', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final handle = tester.ensureSemantics();

      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentSong: testSong1,
          isPlaying: true,
          queue: [testSong1, testSong2],
          currentIndex: 0,
        ),
      );

      final lyricsResult = LyricsResult(
        syncedLyrics: testLines,
        source: 'Test',
      );

      final lyricsState = LyricsState(
        mode: LyricsMode.synced,
        availableLyrics: {'Test': lyricsResult},
        activeProvider: 'Test',
        loadedSongId: testSong1.id,
        activeIndex: 0,
      );

      final container = ProviderContainer(
        overrides: [
          audioPlayerProvider.overrideWith(() => notifier),
          lyricsProvider.overrideWith(() => TestLyricsNotifier(lyricsState)),
        ],
      );
      appProviderContainer = container;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 380,
                height: 700,
                child: NewContextualPanel(
                  initialTab: ContextualPanelTab.queue,
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 Tracks In Queue'), findsOneWidget);

      // Simulate reorder: swap items in queue
      notifier.updateState(
        AudioPlayerState(
          currentSong: testSong1,
          isPlaying: true,
          queue: [testSong2, testSong1],
          currentIndex: 1,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      handle.dispose();
      container.dispose();
    });

    testWidgets('Test Matrix E3: NewContextualPanel Lyrics scroll with active semantics', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final handle = tester.ensureSemantics();

      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentSong: testSong1,
          isPlaying: true,
          queue: [testSong1],
        ),
      );

      final lyricsResult = LyricsResult(
        syncedLyrics: testLines,
        source: 'Test',
      );

      final lyricsState = LyricsState(
        mode: LyricsMode.synced,
        availableLyrics: {'Test': lyricsResult},
        activeProvider: 'Test',
        loadedSongId: testSong1.id,
        activeIndex: 0,
      );

      final container = ProviderContainer(
        overrides: [
          audioPlayerProvider.overrideWith(() => audioNotifier),
          lyricsProvider.overrideWith(() => TestLyricsNotifier(lyricsState)),
        ],
      );
      appProviderContainer = container;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 380,
                height: 700,
                child: NewContextualPanel(
                  initialTab: ContextualPanelTab.lyrics,
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Line 1: Hello World'), findsOneWidget);

      handle.dispose();
      container.dispose();
    });

    test('Test Matrix A: PolledDatabaseEvent conforms to DatabaseEvent contract with value type', () {
      final mockSnapshot = MockDataSnapshot();
      final event = PolledDatabaseEvent(mockSnapshot, type: DatabaseEventType.value);

      expect(event, isA<DatabaseEvent>());
      expect(event.snapshot, equals(mockSnapshot));
      expect(event.type, equals(DatabaseEventType.value));
      expect(event.previousChildKey, isNull);
    });

    testWidgets('Test Matrix E4: NewMiniPlayer with active Semantics and micro progress bar updates', (tester) async {
      final handle = tester.ensureSemantics();

      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentSong: testSong1,
          isPlaying: true,
          queue: [testSong1],
        ),
      );

      final container = ProviderContainer(
        overrides: [
          audioPlayerProvider.overrideWith(() => notifier),
        ],
      );
      appProviderContainer = container;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: NewMiniPlayer(onTap: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Track 1'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      handle.dispose();
      container.dispose();
    });

    testWidgets('Test Matrix E5: QueueBottomSheet with active Semantics and stable effectiveQueueKey', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final handle = tester.ensureSemantics();

      final songA = testSong1.copyWith(queueKey: 'q_key_1');
      final songB = testSong2.copyWith(queueKey: 'q_key_2');

      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentSong: songA,
          isPlaying: true,
          queue: [songA, songB],
          currentIndex: 0,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          audioPlayerProvider.overrideWith(() => notifier),
        ],
      );
      appProviderContainer = container;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: QueueBottomSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('queue_sheet_${songA.effectiveQueueKey}')), findsOneWidget);
      expect(find.byKey(ValueKey('queue_sheet_${songB.effectiveQueueKey}')), findsOneWidget);

      handle.dispose();
      container.dispose();
    });

    test('Test Matrix S1: Song model effectiveQueueKey assigns unique stable identity', () {
      final songNoKey = testSong1;
      expect(songNoKey.effectiveQueueKey, equals('${songNoKey.id}_${songNoKey.isarId}'));

      final songWithKey = testSong1.copyWith(queueKey: 'custom_queue_uuid');
      expect(songWithKey.effectiveQueueKey, equals('custom_queue_uuid'));
    });
  });
}
