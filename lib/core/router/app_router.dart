import 'package:it_feels_music/main.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/home/home_screen.dart';
import 'package:it_feels_music/features/search/search_screen.dart';
import 'package:it_feels_music/features/library/library_screen.dart';
import 'package:it_feels_music/features/player/video_tab_screen.dart';
import 'package:it_feels_music/features/player/now_playing_screen.dart';
import 'package:it_feels_music/features/player/video_player_screen.dart';
import 'package:it_feels_music/features/social/social_screen.dart';
import 'package:it_feels_music/features/settings/settings_screen.dart';
import 'package:it_feels_music/features/social/room_deep_link_screen.dart';
import 'package:it_feels_music/features/social/song_deep_link_screen.dart';
import 'package:it_feels_music/features/social/download_deep_link_screen.dart';
import 'package:it_feels_music/features/player/desktop_miniplayer_screen.dart';
import 'package:it_feels_music/features/player/fullscreen_music_screen.dart';
import 'package:it_feels_music/features/search/raycast_search_overlay.dart';
import 'package:it_feels_music/features/onboarding/onboarding_screen.dart';
import 'package:it_feels_music/services/storage_service.dart';
import 'main_navigation_wrapper.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorHomeKey = GlobalKey<NavigatorState>(debugLabel: 'shellHome');
final GlobalKey<NavigatorState> _shellNavigatorSearchKey = GlobalKey<NavigatorState>(debugLabel: 'shellSearch');
final GlobalKey<NavigatorState> _shellNavigatorLibraryKey = GlobalKey<NavigatorState>(debugLabel: 'shellLibrary');
final GlobalKey<NavigatorState> _shellNavigatorVideosKey = GlobalKey<NavigatorState>(debugLabel: 'shellVideos');

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) async {
        final hasSeen = await StorageService.getHasSeenOnboarding();
        if (!hasSeen) return '/onboarding';
        return '/home';
      },
    ),
    GoRoute(
      path: '/onboarding',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => const NoTransitionPage(
        child: OnboardingScreen(),
      ),
    ),
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
              pageBuilder: (context, state) {
                final q = state.uri.queryParameters['q'];
                return NoTransitionPage(
                  child: SearchScreen(initialQuery: q),
                );
              },
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
      path: '/fullscreen_music',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          child: const FullscreenMusicScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
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
        final expStr = state.uri.queryParameters['exp'];
        return NoTransitionPage(
          child: RoomDeepLinkScreen(roomId: roomId, expStr: expStr),
        );
      },
    ),
    GoRoute(
      path: '/song/:songId',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) {
        final songId = state.pathParameters['songId'] ?? '';
        return NoTransitionPage(
          child: SongDeepLinkScreen(songId: songId),
        );
      },
    ),
    GoRoute(
      path: '/download/:songId',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) {
        final songId = state.pathParameters['songId'] ?? '';
        return NoTransitionPage(
          child: DownloadDeepLinkScreen(songId: songId),
        );
      },
    ),
    GoRoute(
      path: '/desktop_miniplayer',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          child: const DesktopMiniplayerScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );
      },
    ),
    GoRoute(
      path: '/raycast',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          opaque: false, // Must be transparent for frosted glass overlay
          child: const RaycastSearchOverlay(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );
      },
    ),
  ],
);
