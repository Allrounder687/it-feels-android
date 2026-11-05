import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/models/keyboard_shortcut_models.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/features/settings/keyboard_shortcuts_screen.dart';
import 'package:it_feels_music/main.dart';
import 'package:it_feels_music/services/keyboard_shortcut_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAudioPlayerNotifier extends AudioPlayerNotifier {
  @override
  AudioPlayerState build() => AudioPlayerState(isLoading: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    appProviderContainer = ProviderContainer(
      overrides: [
        audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier()),
      ],
    );
    await KeyboardShortcutService().resetAllToDefaults();
  });

  Widget createWidgetUnderTest() {
    return UncontrolledProviderScope(
      container: appProviderContainer,
      child: const MaterialApp(
        home: KeyboardShortcutsScreen(),
      ),
    );
  }

  testWidgets('KeyboardShortcutsScreen renders all categories and action tiles', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Verify screen title
    expect(find.text("Keyboard Shortcuts"), findsWidgets);

    // Verify category headers
    expect(find.text(PlayerActionCategory.playback.label.toUpperCase()), findsOneWidget);
    expect(find.text(PlayerActionCategory.volume.label.toUpperCase()), findsOneWidget);
    expect(find.text(PlayerActionCategory.navigation.label.toUpperCase()), findsOneWidget);

    // Verify action labels
    expect(find.text("Play / Pause"), findsOneWidget);
    expect(find.text("Next Track"), findsOneWidget);
    expect(find.text("Volume Up (+5%)"), findsOneWidget);
    expect(find.text("Mute / Unmute"), findsOneWidget);
    expect(find.text("Like / Favorite Song"), findsOneWidget);
  });

  testWidgets('KeyboardShortcutsScreen opens remap dialog when edit button is tapped', (tester) async {
    tester.view.physicalSize = const Size(800, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Find first edit button
    final editButtons = find.byTooltip("Remap shortcut");
    expect(editButtons, findsWidgets);

    await tester.tap(editButtons.first);
    await tester.pumpAndSettle();

    // Verify remap dialog opened
    expect(find.text("Remap Shortcut"), findsOneWidget);
    expect(find.text("Press any key combination on your keyboard"), findsOneWidget);
    expect(find.text("Save Shortcut"), findsOneWidget);
    expect(find.text("Cancel"), findsOneWidget);

    // Close dialog
    await tester.tap(find.text("Cancel"));
    await tester.pumpAndSettle();

    expect(find.text("Remap Shortcut"), findsNothing);
  });

  testWidgets('KeyboardShortcutsScreen shows Reset All confirmation dialog', (tester) async {
    tester.view.physicalSize = const Size(800, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final resetAllBtn = find.text("Reset All");
    expect(resetAllBtn, findsOneWidget);

    await tester.tap(resetAllBtn);
    await tester.pumpAndSettle();

    expect(find.text("Reset All Shortcuts?"), findsOneWidget);

    // Cancel reset
    await tester.tap(find.text("Cancel"));
    await tester.pumpAndSettle();

    expect(find.text("Reset All Shortcuts?"), findsNothing);
  });
}
