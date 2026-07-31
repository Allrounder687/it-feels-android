import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:it_feels_music/features/player/lyrics_screen.dart';
import 'package:it_feels_music/features/player/lyrics_provider.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/lyrics_service.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

class MockLyricsNotifier extends LyricsNotifier {
  @override
  LyricsState build() {
    return LyricsState(
      isLoading: false,
      lyricsNotFound: true,
      mode: LyricsMode.synced,
      activeIndex: -1,
      fontFamily: 'Inter',
      syncOffsetMs: 0,
      lyricsResult: LyricsResult(),
    );
  }
}

class MockAudioPlayerNotifier extends AudioPlayerNotifier {
  @override
  AudioPlayerState build() {
    final testSong = Song(
      id: '1',
      saavnId: '1',
      title: 'Test Song',
      artist: 'Test Artist',
      album: 'Test Album',
      duration: 100,
      coverArt: '',
      addedAt: DateTime.now(),
    );
    return AudioPlayerState(
      currentSong: testSong,
      position: Duration.zero,
      duration: const Duration(seconds: 100),
      isPlaying: true,
    );
  }
}

class FakeSong extends Fake implements Song {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeSong());
    registerFallbackValue(Duration.zero);
  });

  testWidgets('LyricsScreen displays cute apologetic message when no lyrics', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerProvider.overrideWith(() => MockAudioPlayerNotifier()),
          lyricsProvider.overrideWith(() => MockLyricsNotifier()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: LyricsScreen()),
        ),
      ),
    );

    await tester.pump();

    try {
      expect(find.textContaining("Oopsies!"), findsOneWidget);
    } catch (e) {
      debugDumpApp();
      rethrow;
    }
  });
}
