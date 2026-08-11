import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:go_router/go_router.dart';

import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/services/playlist_import_service.dart';
import 'package:it_feels_music/features/settings/settings_provider.dart';
import 'package:it_feels_music/core/widgets/premium_title_bar.dart';
import 'package:it_feels_music/core/widgets/mini_player.dart';
import 'package:it_feels_music/features/player/video_miniplayer.dart';
import 'package:it_feels_music/features/player/active_media_provider.dart';
import 'package:it_feels_music/core/widgets/import_progress_banner.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/providers/bottom_ui_provider.dart';
import 'package:it_feels_music/features/social/unread_count_provider.dart';
import 'package:it_feels_music/services/config_service.dart';
import 'package:it_feels_music/features/admin/force_update_screen.dart';
import 'package:it_feels_music/core/widgets/tv_focusable_card.dart';

class MainNavigationWrapper extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const MainNavigationWrapper({super.key, required this.navigationShell});

  @override
  ConsumerState<MainNavigationWrapper> createState() =>
      _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends ConsumerState<MainNavigationWrapper>
    with WidgetsBindingObserver {
  Song? _lastLoggedSong;
  StreamSubscription? _intentSubscription;
  String _lastCheckedClipboard = '';
  int _slowFrameCount = 0;
  DateTime? _lastStutterWarning;

  void _onFrameTimings(List<FrameTiming> timings) {
    if (!mounted) return;

    final currentQuality = ref.read(settingsProvider).graphicsQuality;
    // If already at lowest quality, do nothing.
    if (currentQuality == GraphicsQuality.low) {
      _slowFrameCount = 0;
      return;
    }

    for (final timing in timings) {
      // If a frame took more than ~33ms (which means we dropped below 30FPS)
      if (timing.totalSpan.inMilliseconds > 33) {
        _slowFrameCount++;
      } else {
        // Recovering frames resets the counter slowly or completely.
        _slowFrameCount = 0;
      }
    }

    // If we hit 15 consecutive slow frames (severe stutter)
    if (_slowFrameCount > 15) {
      _slowFrameCount = 0;
      final now = DateTime.now();

      // Throttle the auto-detection to at most once per hour so we don't spam the user
      // if they purposefully disable it.
      if (_lastStutterWarning == null ||
          now.difference(_lastStutterWarning!).inHours > 1) {
        _lastStutterWarning = now;

        // Auto-downgrade
        final newQuality = currentQuality == GraphicsQuality.high
            ? GraphicsQuality.medium
            : GraphicsQuality.low;

        ref.read(settingsProvider.notifier).setGraphicsQuality(newQuality);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Heavy stutter detected. Graphics Quality lowered to ${newQuality.name.toUpperCase()} for a smoother experience.',
              ),
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      // Listen to media sharing incoming links while app is in memory
      _intentSubscription = ReceiveSharingIntent.instance
          .getMediaStream()
          .listen(
            (value) {
              if (value.isNotEmpty) {
                _handleSharedText(value.first.path);
              }
            },
            onError: (err) {
              debugPrint("Intent error: $err");
            },
          );

      // Check for sharing intent when app is opened from closed state
      ReceiveSharingIntent.instance.getInitialMedia().then((value) {
        if (value.isNotEmpty) {
          _handleSharedText(value.first.path);
        }
        ReceiveSharingIntent.instance.reset();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = ref.read(audioPlayerProvider);
      final history = ref.read(listeningHistoryProvider);

      // Listening history logging is handled via ref.listen in build()

      // Check clipboard on startup
      _checkClipboardForPlaylist();

      // Check for OTA updates (force or soft)
      _checkUpdateStatus();
    });
  }

  Future<void> _checkUpdateStatus() async {
    // 1. Silent Background Shorebird Patch Check
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        final shorebird = ShorebirdUpdater();
        final status = await shorebird.checkForUpdate();
        if (status == UpdateStatus.outdated) {
          await shorebird.update();
          if (mounted) {
            ref.read(shorebirdUpdatePendingProvider.notifier).state = true;
          }
        }
      } catch (e) {
        debugPrint("Silent Shorebird check failed: $e");
      }
    }

    // 2. Full Version Config Check
    try {
      final config = await ConfigService.fetchRemoteConfig();
      if (config != null && mounted) {
        final isForce = await ConfigService.requiresForceUpdate(config);
        final hasSoft = await ConfigService.hasSoftUpdate(config);
        if ((isForce || hasSoft) && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ForceUpdateScreen(
                latestVersion: config.latestVersion,
                updateUrl: config.updateUrl,
                releaseNotes: config.releaseNotes,
                iosUpdateUrl: config.iosUpdateUrl,
                isSoftUpdate: !isForce,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    _intentSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboardForPlaylist();
    }
  }

  Future<void> _checkClipboardForPlaylist() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text?.trim() ?? '';

      if (text.isNotEmpty && text != _lastCheckedClipboard) {
        _lastCheckedClipboard = text;
        _handleSharedText(text);
      }
    } catch (e) {
      // Ignore clipboard access errors (e.g. Windows locking the clipboard)
    }
  }

  void _handleSharedText(String text) {
    if (text.contains('open.spotify.com/playlist/')) {
      // Extract URL from possible text like "Check out this playlist: https://..."
      final RegExp urlRegExp = RegExp(r'(https?://[^\s]+)');
      final match = urlRegExp.firstMatch(text);
      if (match != null) {
        final url = match.group(0)!;
        _promptImport(url);
      }
    }
  }

  void _promptImport(String url) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.themeSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final bottomUiHeight = ref.watch(bottomUiProvider);
            final bottomPadding = bottomUiHeight > 0
                ? bottomUiHeight + 12.0
                : 24.0;
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: bottomPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.playlist_add,
                    size: 48,
                    color: AppColors.midnightAccent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Import Playlist?',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.themeTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We detected a Spotify playlist link. Would you like to import it to IT-Feels?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: context.themeMutedTextColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              color: context.themeMutedTextColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.midnightAccent,
                            foregroundColor: context.themeBackgroundColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            PlaylistImportService().startBackgroundImport(
                              url,
                              ref.read(customPlaylistProvider),
                              MusicApiService(),
                            );
                          },
                          child: Text(
                            'Import Now',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AudioPlayerState>(audioPlayerProvider, (previous, next) {
      final currentSong = next.currentSong;
      if (currentSong != null && currentSong.id != _lastLoggedSong?.id) {
        _lastLoggedSong = currentSong;
        ref.read(listeningHistoryProvider.notifier).logSong(currentSong);
      }
    });

    final enableVideos = ref.watch(
      settingsProvider.select((s) => s.enableMusicVideos),
    );
    final currentRoute = GoRouterState.of(context).uri.toString();
    final isNarrowScreen = MediaQuery.of(context).size.width < 360;
    final activeMediaType = ref.watch(activeMediaProvider);

    final videoProvider = ref.watch(videoPlayerProvider);
    final audioProvider = ref.watch(audioPlayerProvider);
    final isSameSong =
        audioProvider.currentSong != null &&
        (videoProvider.currentVideoId == audioProvider.currentSong!.id ||
            videoProvider.currentVideoId ==
                'search:${audioProvider.currentSong!.id}');
    final isMutedCanvas =
        !ref.watch(settingsProvider.select((s) => s.useVideoAudioSource)) &&
        isSameSong;

    final isWide = MediaQuery.of(context).size.width > 600;
    final bool showAudioMiniPlayer = isWide 
        ? activeMediaType != ActiveMediaType.none
        : (activeMediaType == ActiveMediaType.audio ||
          (activeMediaType == ActiveMediaType.video && isMutedCanvas));
          
    final bool showVideoPiP =
        activeMediaType == ActiveMediaType.video && !isMutedCanvas;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        // If the shell can pop (there is a nested route), let GoRouter handle it
        if (context.canPop()) {
          context.pop();
          return;
        }

        // TV / 10-foot UI Back Button Discipline
        // Try to move focus up/left towards navigation
        final isWide = MediaQuery.of(context).size.width > 600;
        final moved = FocusScope.of(context).focusInDirection(
          isWide ? TraversalDirection.left : TraversalDirection.up,
        );

        if (!moved) {
          if (widget.navigationShell.currentIndex != 0) {
            // Return to Home tab if not already there
            widget.navigationShell.goBranch(0, initialLocation: true);
          } else {
            // At root of Home tab and top of focus, allow exit
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: context.themeBackgroundColor,
        body: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Consumer(
            builder: (context, ref, _) {
              final isSolid = ref.watch(settingsProvider).useSolidTitleBar;
              final isDesktop =
                  !kIsWeb &&
                  (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
              final titleBar = isDesktop
                  ? PremiumTitleBar(
                      isWideScreen: MediaQuery.of(context).size.width >= 600,
                      isSolid: isSolid,
                    )
                  : const SizedBox.shrink();

              final appContent = LayoutBuilder(
                builder: (context, constraints) {
                  final isWideScreen = constraints.maxWidth >= 600;
                  final isNarrowScreen = !isWideScreen;

                  if (isWideScreen) {
                    return FocusTraversalGroup(
                      policy: ReadingOrderTraversalPolicy(),
                      child: Row(
                        children: [
                          // Floating Side Navigation Pill for Wide Screens
                          SafeArea(
                            right: false,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
                              child: Consumer(
                                builder: (context, ref, child) {
                                  final isSidebarPinned = ref.watch(sidebarPinnedProvider);
                                  
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                    width: isSidebarPinned ? 90 : 0,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
                                      border: Border(
                                        right: BorderSide(
                                          color: context.themeTextColor.withValues(alpha: 0.05),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Center(
                                      child: SingleChildScrollView(
                                        physics: const BouncingScrollPhysics(),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            const SizedBox(height: 24),
                                            _buildNavItem(
                                              0,
                                              Icons.home_rounded,
                                              "Home",
                                              isVertical: true,
                                              hideLabel: true,
                                            ),
                                            const SizedBox(height: 12),
                                            _buildNavItem(
                                              1,
                                              Icons.search_rounded,
                                              "Search",
                                              isVertical: true,
                                              hideLabel: true,
                                            ),
                                            const SizedBox(height: 12),
                                            _buildNavItem(
                                              2,
                                              Icons.library_music_rounded,
                                              "Library",
                                              isVertical: true,
                                              hideLabel: true,
                                            ),
                                            const SizedBox(height: 12),
                                            if (enableVideos) ...[
                                              _buildNavItem(
                                                3,
                                                Icons.video_library_rounded,
                                                "Videos",
                                                isVertical: true,
                                                hideLabel: true,
                                              ),
                                              const SizedBox(height: 12),
                                            ],
                                            _buildNavItem(
                                              4,
                                              Icons.people_rounded,
                                              "Social",
                                              isVertical: true,
                                              hideLabel: true,
                                            ),
                                            const SizedBox(height: 12),
                                            _buildNavItem(
                                              5,
                                              Icons.settings_outlined,
                                              "Settings",
                                              isVertical: true,
                                              hideLabel: true,
                                              hasUpdate: ref.watch(
                                                shorebirdUpdatePendingProvider,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          // Main Content
                          Expanded(
                            child: Stack(
                              children: [
                                // Active Shell Route
                                widget.navigationShell,

                                // Video Miniplayer Overlay (PiP)
                                if (showVideoPiP)
                                  const Positioned(
                                    bottom: 90, // Above the audio MiniPlayer
                                    right: 16,
                                    child: VideoMiniplayer(),
                                  ),

                                // Floating MiniPlayer Overlay
                                if (showAudioMiniPlayer)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: MeasureSize(
                                      onChange: (size) => ref
                                          .read(bottomUiProvider.notifier)
                                          .updateHeight(size.height),
                                      child: SafeArea(
                                        bottom: true,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Import Progress Banner
                                            const ImportProgressBanner(),
                                            // Mini Player Pill
                                            MiniPlayer(
                                              onTap: () =>
                                                  context.push('/now_playing'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Mobile View
                  return Stack(
                    children: [
                      // Active Shell Route
                      widget.navigationShell,

                      // Floating MiniPlayer + Bottom Navigation Bar Overlay
                      if (MediaQuery.of(context).orientation ==
                          Orientation.portrait)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: MeasureSize(
                            onChange: (size) => ref
                                .read(bottomUiProvider.notifier)
                                .updateHeight(size.height),
                            child: SafeArea(
                              bottom: true,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Import Progress Banner
                                  const ImportProgressBanner(),

                                  // Mini Player Pill
                                  if (showAudioMiniPlayer)
                                    MiniPlayer(
                                      onTap: () => context.push('/now_playing'),
                                    ),

                                  // Floating Bottom Navigation Bar Pill Container
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(32),
                                    child: Builder(
                                      builder: (context) {
                                        final child = Container(
                                          height: isNarrowScreen ? 70 : 76,
                                          margin: const EdgeInsets.only(
                                            left: 12,
                                            right: 12,
                                            bottom: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: kDebugMode
                                                ? context.themeSurfaceColor
                                                : context.themeSurfaceColor
                                                      .withValues(alpha: 0.7),
                                            borderRadius: BorderRadius.circular(
                                              32,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: context
                                                    .themeInvertedTextColor
                                                    .withValues(alpha: 0.4),
                                                blurRadius: 20,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceAround,
                                            children: [
                                              Expanded(child: _buildNavItem(
                                                0,
                                                Icons.home_rounded,
                                                "Home",
                                                hideLabel: isNarrowScreen,
                                              )),
                                              Expanded(child: _buildNavItem(
                                                1,
                                                Icons.search_rounded,
                                                "Search",
                                                hideLabel: isNarrowScreen,
                                              )),
                                              Expanded(child: _buildNavItem(
                                                2,
                                                Icons.library_music_rounded,
                                                "Library",
                                                hideLabel: isNarrowScreen,
                                              )),
                                              if (enableVideos)
                                                Expanded(child: _buildNavItem(
                                                  3,
                                                  Icons.video_library_rounded,
                                                  "Videos",
                                                  hideLabel: isNarrowScreen,
                                                )),
                                              Expanded(child: _buildNavItem(
                                                enableVideos ? 4 : 3,
                                                Icons.people_rounded,
                                                "Social",
                                                hideLabel: isNarrowScreen,
                                              )),
                                              Expanded(child: _buildNavItem(
                                                enableVideos ? 5 : 4,
                                                Icons.settings_outlined,
                                                "Settings",
                                                hideLabel: isNarrowScreen,
                                                hasUpdate: ref.watch(
                                                  shorebirdUpdatePendingProvider,
                                                ),
                                              )),
                                            ],
                                          ),
                                        );
                                        return child;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Video Miniplayer PiP Overlay (On top of everything)
                      if (showVideoPiP)
                        Positioned(
                          bottom:
                              MediaQuery.of(context).orientation ==
                                  Orientation.portrait
                              ? ref.watch(bottomUiProvider) + 16
                              : 16,
                          right: 16,
                          child: const VideoMiniplayer(),
                        ),
                    ],
                  );
                },
              );

              if (isSolid) {
                return Column(
                  children: [
                    titleBar,
                    Expanded(child: appContent),
                  ],
                );
              } else {
                return Stack(
                  children: [
                    if (isDesktop)
                      MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          padding: MediaQuery.of(context)
                              .padding
                              .copyWith(top: 48.0),
                        ),
                        child: appContent,
                      )
                    else
                      appContent,
                    if (isDesktop)
                      Positioned(top: 0, left: 0, right: 0, child: titleBar),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label, {
    bool isVertical = false,
    bool hideLabel = false,
    bool hasUpdate = false,
  }) {
    final isSelected = widget.navigationShell.currentIndex == index;
    return Consumer(
      builder: (context, ref, child) {
        final content = _HoverNavItem(
          index: index,
          isSelected: isSelected,
          isVertical: isVertical,
          hideLabel: hideLabel,
          onTap: () {
            widget.navigationShell.goBranch(
              index,
              initialLocation: index == widget.navigationShell.currentIndex,
            );
          },
          child: Stack(
                children: [
                  isVertical
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            label == "Social"
                                ? Consumer(
                                    builder: (context, ref, _) {
                                      final count =
                                          ref
                                              .watch(unreadCountProvider)
                                              .value ??
                                          0;
                                      final iconWidget = Icon(
                                        icon,
                                        color: isSelected
                                            ? context.themeNavPillTextColor
                                            : context.themeMutedTextColor,
                                        size: 28,
                                      );
                                      if (count > 0)
                                        return Badge(
                                          label: Text(count.toString()),
                                          backgroundColor: Colors.redAccent,
                                          child: iconWidget,
                                        );
                                      return iconWidget;
                                    },
                                  )
                                : Icon(
                                    icon,
                                    color: isSelected
                                        ? context.themeNavPillTextColor
                                        : context.themeMutedTextColor,
                                    size: 28,
                                  ),
                            if (isSelected && !hideLabel) ...[
                              const SizedBox(height: 6),
                              Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: context.themeNavPillTextColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        )
                      : Row(
                          children: [
                            label == "Social"
                                ? Consumer(
                                    builder: (context, ref, _) {
                                      final count =
                                          ref
                                              .watch(unreadCountProvider)
                                              .value ??
                                          0;
                                      final iconWidget = Icon(
                                        icon,
                                        color: isSelected
                                            ? context.themeNavPillTextColor
                                            : context.themeMutedTextColor,
                                        size: 26,
                                      );
                                      if (count > 0)
                                        return Badge(
                                          label: Text(count.toString()),
                                          backgroundColor: Colors.redAccent,
                                          child: iconWidget,
                                        );
                                      return iconWidget;
                                    },
                                  )
                                : Icon(
                                    icon,
                                    color: isSelected
                                        ? context.themeNavPillTextColor
                                        : context.themeMutedTextColor,
                                    size: 26,
                                  ),
                            if (!hideLabel) ...[
                              const SizedBox(width: 16),
                              Flexible(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: isSelected
                                        ? context.themeNavPillTextColor
                                        : context.themeMutedTextColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                  // Update Dot Indicator
                  if (hasUpdate)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: context.themeAccentColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.themeBackgroundColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
        );
        return content;
      },
    );
  }
}

class _HoverNavItem extends StatefulWidget {
  final int index;
  final bool isSelected;
  final bool isVertical;
  final bool hideLabel;
  final Widget child;
  final VoidCallback onTap;

  const _HoverNavItem({
    required this.index,
    required this.isSelected,
    required this.isVertical,
    required this.hideLabel,
    required this.child,
    required this.onTap,
  });

  @override
  State<_HoverNavItem> createState() => _HoverNavItemState();
}

class _HoverNavItemState extends State<_HoverNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: TVFocusableCard(
        onTap: widget.onTap,
        borderRadius: 20,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: EdgeInsets.symmetric(
              horizontal: widget.isVertical ? 12 : (widget.hideLabel ? 12 : 14),
              vertical: widget.isVertical ? 16 : 14,
            ),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? context.themeNavPillColor
                  : (_isHovered ? context.themeAccentColor.withValues(alpha: 0.1) : Colors.transparent),
              borderRadius: BorderRadius.circular(20),
              boxShadow: _isHovered || widget.isSelected
                  ? [
                      BoxShadow(
                        color: (widget.isSelected ? context.themeNavPillColor : context.themeAccentColor).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
