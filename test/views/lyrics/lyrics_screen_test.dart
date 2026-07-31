import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/features/player/lyrics_provider.dart';
import 'package:it_feels_music/data/services/lyrics_service.dart';

void main() {
  test('LyricsState defaults correctly when no lyrics', () {
    final state = LyricsState(
      isLoading: false,
      lyricsNotFound: true,
      mode: LyricsMode.synced,
      activeIndex: -1,
      fontFamily: 'Inter',
      syncOffsetMs: 0,
      lyricsResult: LyricsResult(),
    );

    expect(state.isLoading, false);
    expect(state.lyricsNotFound, true);
    expect(state.mode, LyricsMode.synced);
  });
}
