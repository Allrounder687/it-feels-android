import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:it_feels_music/views/lyrics/lyrics_screen.dart';
import 'package:it_feels_music/providers/lyrics_provider.dart';
import 'package:it_feels_music/providers/audio_player_provider.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/lyrics_service.dart';

class MockLyricsProvider extends Mock implements LyricsProvider {}
class MockAudioPlayerProvider extends Mock implements AudioPlayerProvider {}
class MockItemScrollController extends Mock implements ItemScrollController {}

class FakeSong extends Fake implements Song {}

void main() {
  late MockLyricsProvider mockLyrics;
  late MockAudioPlayerProvider mockAudio;
  late MockItemScrollController mockScroll;

  setUpAll(() {
    registerFallbackValue(FakeSong());
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    mockLyrics = MockLyricsProvider();
    mockAudio = MockAudioPlayerProvider();
    mockScroll = MockItemScrollController();
  });

  testWidgets('LyricsScreen displays cute apologetic message when no lyrics', (WidgetTester tester) async {
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

    // Setup MockAudioPlayerProvider
    when(() => mockAudio.currentSong).thenReturn(testSong);
    when(() => mockAudio.position).thenReturn(Duration.zero);
    when(() => mockAudio.duration).thenReturn(const Duration(seconds: 100));
    when(() => mockAudio.isPlaying).thenReturn(true);
    when(() => mockAudio.themeBackgroundColor).thenReturn(const Color(0xFF000000));
    when(() => mockAudio.themeTextColor).thenReturn(const Color(0xFFFFFFFF));
    when(() => mockAudio.themeMutedTextColor).thenReturn(const Color(0xFF888888));
    when(() => mockAudio.themeInvertedTextColor).thenReturn(const Color(0xFF000000));
    when(() => mockAudio.themeAccentColor).thenReturn(const Color(0xFFFF0000));
    when(() => mockAudio.themeCardColor).thenReturn(const Color(0xFF111111));
    when(() => mockAudio.themeSurfaceColor).thenReturn(const Color(0xFF222222));

    // Setup MockLyricsProvider
    when(() => mockLyrics.isLoading).thenReturn(false);
    when(() => mockLyrics.lyricsNotFound).thenReturn(true);
    when(() => mockLyrics.mode).thenReturn(LyricsMode.synced);
    when(() => mockLyrics.activeIndex).thenReturn(-1);
    when(() => mockLyrics.activeIndex).thenReturn(-1);
    when(() => mockLyrics.fontFamily).thenReturn('Inter');
    when(() => mockLyrics.syncOffsetMs).thenReturn(0);
    when(() => mockLyrics.result).thenReturn(LyricsResult());
    when(() => mockLyrics.itemScrollController).thenReturn(mockScroll);
    when(() => mockScroll.isAttached).thenReturn(true);
    when(() => mockLyrics.loadLyricsIfNeeded(any(), any())).thenAnswer((_) async {});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LyricsProvider>.value(value: mockLyrics),
          ChangeNotifierProvider<AudioPlayerProvider>.value(value: mockAudio),
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
