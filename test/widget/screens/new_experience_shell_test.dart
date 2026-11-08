import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/main.dart';
import 'package:it_feels_music/features/new_experience/shell/new_experience_shell.dart';
import 'package:it_feels_music/features/new_experience/shell/new_desktop_sidebar.dart';
import 'package:it_feels_music/features/new_experience/shell/new_mobile_nav_dock.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/home/home_provider.dart';
import 'package:it_feels_music/features/auth/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockMusicRepository extends Mock implements IMusicRepository {}

class FakeAudioPlayerNotifier extends AudioPlayerNotifier {
  final Song? testSong;
  FakeAudioPlayerNotifier({this.testSong});

  @override
  AudioPlayerState build() => AudioPlayerState(
        isLoading: false,
        currentSong: testSong,
      );
}

class FakeHomeNotifier extends HomeNotifier {
  @override
  HomeState build() => const HomeState();
}

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState();
  @override
  User? get currentUser => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    if (!locator.isRegistered<IMusicRepository>()) {
      locator.registerSingleton<IMusicRepository>(MockMusicRepository());
    }
  });

  testWidgets('NewExperienceShell renders Desktop layout on desktop screen size',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final container = ProviderContainer(
      overrides: [
        audioPlayerProvider.overrideWith(FakeAudioPlayerNotifier.new),
        homeProvider.overrideWith(FakeHomeNotifier.new),
        authProvider.overrideWith(FakeAuthNotifier.new),
      ],
    );
    appProviderContainer = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: NewExperienceShell(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify desktop sidebar is present
    expect(find.byType(NewDesktopSidebar), findsOneWidget);
    // Verify mobile dock is not present
    expect(find.byType(NewMobileNavDock), findsNothing);
  });

  testWidgets('NewExperienceShell renders Mobile layout on mobile screen size',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final container = ProviderContainer(
      overrides: [
        audioPlayerProvider.overrideWith(FakeAudioPlayerNotifier.new),
        homeProvider.overrideWith(FakeHomeNotifier.new),
        authProvider.overrideWith(FakeAuthNotifier.new),
      ],
    );
    appProviderContainer = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: NewExperienceShell(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify mobile dock is present
    expect(find.byType(NewMobileNavDock), findsOneWidget);
    // Verify desktop sidebar is not present
    expect(find.byType(NewDesktopSidebar), findsNothing);
  });
}
