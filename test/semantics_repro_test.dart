import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/core/widgets/premium_title_bar.dart';
import 'package:it_feels_music/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/data/models/song_model.dart';

class TestAudioPlayerNotifier extends AudioPlayerNotifier {
  @override
  AudioPlayerState build() {
    return AudioPlayerState();
  }

  void setSong(Song? song) {
    state = state.copyWith(currentSong: song);
  }
}

void main() {
  late TestAudioPlayerNotifier testNotifier;

  setUp(() {
    testNotifier = TestAudioPlayerNotifier();
    appProviderContainer = ProviderContainer(
      overrides: [
        audioPlayerProvider.overrideWith(() => testNotifier),
      ],
    );
  });

  tearDown(() {
    appProviderContainer.dispose();
  });

  testWidgets('PremiumTitleBar semantics test with hover and song transitions', (WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: appProviderContainer,
        child: const MaterialApp(
          home: Scaffold(
            body: PremiumTitleBar(isWideScreen: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Simulate mouse hover over title bar buttons
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    final iconFinder = find.byIcon(Icons.settings_outlined);
    expect(iconFinder, findsOneWidget);
    await gesture.moveTo(tester.getCenter(iconFinder));
    await tester.pumpAndSettle();

    // Move away
    await gesture.moveTo(const Offset(10, 10));
    await tester.pumpAndSettle();

    // 2. Simulate song transition triggering AnimatedSwitcher with active Semantics
    testNotifier.setSong(
      Song(
        id: 'song_123',
        saavnId: 'song_123',
        title: 'Semantics Test Song',
        artist: 'Test Artist',
        album: 'Test Album',
        duration: 200,
        coverArt: 'https://example.com/cover.jpg',
        addedAt: DateTime.now(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Semantics Test Song'), findsOneWidget);

    // Switch back to no song
    testNotifier.setSong(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    handle.dispose();
  });
}
