import 'package:it_feels_music/main.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/home/home_screen.dart';
import 'package:it_feels_music/features/search/search_screen.dart';
import 'package:it_feels_music/features/library/library_screen.dart';
import 'package:it_feels_music/features/player/video_tab_screen.dart';
import 'package:it_feels_music/features/player/now_playing_screen.dart';
import 'package:it_feels_music/features/player/video_player_screen.dart';
import 'package:it_feels_music/features/settings/settings_provider.dart';
import 'package:it_feels_music/features/social/social_screen.dart';
import 'package:it_feels_music/features/settings/settings_screen.dart';
import 'package:it_feels_music/features/social/room_deep_link_screen.dart';
import 'main_navigation_wrapper.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorHomeKey = GlobalKey<NavigatorState>(debugLabel: 'shellHome');
final GlobalKey<NavigatorState> _shellNavigatorSearchKey = GlobalKey<NavigatorState>(debugLabel: 'shellSearch');
final GlobalKey<NavigatorState> _shellNavigatorLibraryKey = GlobalKey<NavigatorState>(debugLabel: 'shellLibrary');
final GlobalKey<NavigatorState> _shellNavigatorVideosKey = GlobalKey<NavigatorState>(debugLabel: 'shellVideos');

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainNavigationWrapper(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          navigatorKey: _shellNavigatorHomeKey,
          routes: [
            GoRoute(
              path: '/home',
              pageBuilder: (context, state) => NoTransitionPage(
                child: HomeScreen(openFullPlayer: () => context.push('/now_playing')),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorSearchKey,
          routes: [
            GoRoute(
              path: '/search',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: SearchScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorLibraryKey,
          routes: [
            GoRoute(
              path: '/library',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: LibraryScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorVideosKey,
          routes: [
            GoRoute(
              path: '/videos',
              redirect: (context, state) {
                final settings = appProviderContainer.read(settingsProvider);
                if (!settings.enableMusicVideos) {
                  return '/home';
                }
                return null;
              },
              pageBuilder: (context, state) => const NoTransitionPage(
                child: VideoTabScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/social',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: SocialScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: SettingsScreen(),
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/now_playing',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          child: const NowPlayingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/video_player',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          child: const VideoPlayerScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/room/:roomId',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) {
        final roomId = state.pathParameters['roomId'] ?? '';
        return NoTransitionPage(
          child: RoomDeepLinkScreen(roomId: roomId),
        );
      },
    ),
  ],
);
