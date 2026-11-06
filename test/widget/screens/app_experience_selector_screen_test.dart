import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/main.dart';
import 'package:it_feels_music/core/appearance/app_experience.dart';
import 'package:it_feels_music/core/appearance/app_experience_provider.dart';
import 'package:it_feels_music/features/settings/app_experience_selector_screen.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

class FakeAudioPlayerNotifier extends AudioPlayerNotifier {
  @override
  AudioPlayerState build() => const AudioPlayerState(isLoading: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AppExperienceSelectorScreen renders both experiences and allows switching',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final container = ProviderContainer(
      overrides: [
        audioPlayerProvider.overrideWith(FakeAudioPlayerNotifier.new),
      ],
    );
    appProviderContainer = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AppExperienceSelectorScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify title and descriptions are visible
    expect(find.text('Choose Your Visual Experience'), findsOneWidget);
    expect(find.text('Classic Experience'), findsOneWidget);
    expect(find.text('New Experience (2026)'), findsOneWidget);

    // Initial state is Classic
    expect(container.read(appExperienceProvider), AppExperience.classic);
    expect(find.text('Currently Active'), findsOneWidget);
    expect(find.text('Switch to New Experience (2026)'), findsOneWidget);

    // Tap switch to New Experience
    await tester.tap(find.text('Switch to New Experience (2026)'));
    await tester.pumpAndSettle();

    // Verify state transitioned
    expect(container.read(appExperienceProvider), AppExperience.newExperience);
  });
}
