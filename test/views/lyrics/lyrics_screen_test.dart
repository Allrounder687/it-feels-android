import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/features/player/lyrics_provider.dart';
import 'package:it_feels_music/core/utils/hinglish_transliterator.dart';
import 'package:it_feels_music/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    expect(state.showRomanized, true);
  });

  test('Lyrics Romanized defaults to true and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final initial = await StorageService.getLyricsRomanized();
    expect(initial, true);

    await StorageService.saveLyricsRomanized(false);
    final updated = await StorageService.getLyricsRomanized();
    expect(updated, false);
  });

  test('HinglishTransliterator transliterates Hindi to Roman English', () {
    expect(HinglishTransliterator.transliterate('तुम ही हो'), 'tum hee ho');
    expect(HinglishTransliterator.hasDevanagari('तुम ही हो'), true);
    expect(HinglishTransliterator.hasDevanagari('English Title'), false);
  });
}
