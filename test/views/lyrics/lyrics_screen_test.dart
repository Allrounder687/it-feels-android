import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/features/player/lyrics_provider.dart';

void main() {
  test('LyricsState defaults correctly when no lyrics', () {
    final state = const LyricsState(
      isLoading: false,
      lyricsNotFound: true,
      mode: LyricsMode.synced,
      activeIndex: -1,
      fontFamily: 'Inter',
      syncOffsetMs: 0,
    );

    expect(state.isLoading, false);
    expect(state.lyricsNotFound, true);
    expect(state.mode, LyricsMode.synced);
  });
}
