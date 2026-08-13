import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:it_feels_music/main.dart';
import 'package:it_feels_music/core/router/app_router.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/settings/settings_provider.dart';

class MockBuildContext extends Mock implements BuildContext {}
class MockGoRouterState extends Mock implements GoRouterState {}

class MutableSettingsNotifier extends SettingsNotifier {
  SettingsState _state = const SettingsState();

  @override
  SettingsState build() => _state;

  void updateState(SettingsState newState) {
    state = newState;
  }
}

void main() {
  late MutableSettingsNotifier mutableSettingsNotifier;
  late MockBuildContext mockContext;
  late MockGoRouterState mockGoRouterState;

  setUpAll(() {
    mutableSettingsNotifier = MutableSettingsNotifier();
    
    // Safely initialize the late final appProviderContainer exactly once
    try {
      appProviderContainer;
    } catch (_) {
      appProviderContainer = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(() => mutableSettingsNotifier),
        ],
      );
    }

    // Read the provider once to initialize its element link and prevent LateInitializationError
    appProviderContainer.read(settingsProvider);

    mockContext = MockBuildContext();
    mockGoRouterState = MockGoRouterState();
  });

  group('appRouter configuration checks', () {
    test('contains all expected paths and routes', () {
      final routes = appRouter.configuration.routes;
      final paths = <String>{};

      void collectPaths(List<RouteBase> routeList) {
        for (final route in routeList) {
          if (route is GoRoute) {
            paths.add(route.path);
          } else if (route is StatefulShellRoute) {
            for (final branch in route.branches) {
              collectPaths(branch.routes);
            }
          }
        }
      }

      collectPaths(routes);

      expect(paths.contains('/'), isTrue);
      expect(paths.contains('/onboarding'), isTrue);
      expect(paths.contains('/home'), isTrue);
      expect(paths.contains('/search'), isTrue);
      expect(paths.contains('/library'), isTrue);
      expect(paths.contains('/videos'), isTrue);
      expect(paths.contains('/social'), isTrue);
      expect(paths.contains('/settings'), isTrue);
      expect(paths.contains('/now_playing'), isTrue);
      expect(paths.contains('/fullscreen_music'), isTrue);
      expect(paths.contains('/video_player'), isTrue);
      expect(paths.contains('/room/:roomId'), isTrue);
      expect(paths.contains('/song/:songId'), isTrue);
      expect(paths.contains('/download/:songId'), isTrue);
      expect(paths.contains('/desktop_miniplayer'), isTrue);
      expect(paths.contains('/raycast'), isTrue);
    });
  });

  group('appRouter Redirect: Root (/)', () {
    test('redirects to /onboarding if user has not seen onboarding', () async {
      SharedPreferences.setMockInitialValues({
        'has_seen_onboarding_v1': false,
      });

      final rootRoute = appRouter.configuration.routes[0] as GoRoute;
      final redirect = rootRoute.redirect;

      final result = await redirect!(mockContext, mockGoRouterState);
      expect(result, '/onboarding');
    });

    test('redirects to /home if user has seen onboarding', () async {
      SharedPreferences.setMockInitialValues({
        'has_seen_onboarding_v1': true,
      });

      final rootRoute = appRouter.configuration.routes[0] as GoRoute;
      final redirect = rootRoute.redirect;

      final result = await redirect!(mockContext, mockGoRouterState);
      expect(result, '/home');
    });
  });

  group('appRouter Redirect: Videos (/videos)', () {
    late GoRoute videosRoute;

    setUp(() {
      final routes = appRouter.configuration.routes;
      final shellRoute = routes[2] as StatefulShellRoute;
      final videosBranch = shellRoute.branches[3];
      videosRoute = videosBranch.routes[0] as GoRoute;
    });

    test('redirects to /home if enableMusicVideos setting is false', () async {
      mutableSettingsNotifier.updateState(const SettingsState(enableMusicVideos: false));

      final redirect = videosRoute.redirect;
      final result = await redirect!(mockContext, mockGoRouterState);
      expect(result, '/home');
    });

    test('allows access (returns null) if enableMusicVideos setting is true', () async {
      mutableSettingsNotifier.updateState(const SettingsState(enableMusicVideos: true));

      final redirect = videosRoute.redirect;
      final result = await redirect!(mockContext, mockGoRouterState);
      expect(result, isNull);
    });
  });
}
