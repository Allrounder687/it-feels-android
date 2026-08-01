import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:go_router/go_router.dart';

import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/features/library/listening_history_provider.dart';
import 'package:it_feels_music/features/library/custom_playlist_provider.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/services/playlist_import_service.dart';
import 'package:it_feels_music/features/settings/settings_provider.dart';
import 'package:it_feels_music/core/widgets/mini_player.dart';
import 'package:it_feels_music/core/widgets/import_progress_banner.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/providers/bottom_ui_provider.dart';
import 'package:it_feels_music/features/library/download_provider.dart';
import 'package:it_feels_music/features/social/unread_count_provider.dart';
import 'package:it_feels_music/services/config_service.dart';
import 'package:it_feels_music/features/admin/force_update_screen.dart';

class MainNavigationWrapper extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const MainNavigationWrapper({super.key, required this.navigationShell});

  @override
  ConsumerState<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends ConsumerState<MainNavigationWrapper> with WidgetsBindingObserver {
  Song? _lastLoggedSong;
  late StreamSubscription _intentSubscription;
  String _lastCheckedClipboard = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Listen to media sharing incoming links while app is in memory
    _intentSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) {
        _handleSharedText(value.first.path);
      }
    }, onError: (err) {
      debugPrint("Intent error: $err");
    });

    // Check for sharing intent when app is opened from closed state
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        _handleSharedText(value.first.path);
      }
      ReceiveSharingIntent.instance.reset();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = ref.read(audioPlayerProvider);
      final history = ref.read(listeningHistoryProvider);
      
      // Listening history logging is handled via ref.listen in build()
      
      // Check clipboard on startup
      _checkClipboardForPlaylist();

      // Check for non-forced OTA updates
      _checkSoftUpdate();
    });
  }

  Future<void> _checkSoftUpdate() async {
    try {
      final config = await ConfigService.fetchRemoteConfig();
      if (config != null) {
        final hasSoft = await ConfigService.hasSoftUpdate(config);
        if (hasSoft && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ForceUpdateScreen(
                latestVersion: config.latestVersion,
                updateUrl: config.updateUrl,
                releaseNotes: config.releaseNotes,
                iosUpdateUrl: config.iosUpdateUrl,
                isSoftUpdate: true,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Soft update check failed: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _intentSubscription.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboardForPlaylist();
    }
  }

  Future<void> _checkClipboardForPlaylist() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text?.trim() ?? '';
    
    if (text.isNotEmpty && text != _lastCheckedClipboard) {
      _lastCheckedClipboard = text;
      _handleSharedText(text);
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
        return Consumer(builder: (context, ref, child) {
          final bottomUiHeight = ref.watch(bottomUiProvider);
          final bottomPadding = bottomUiHeight > 0 ? bottomUiHeight + 12.0 : 24.0;
          return Padding(
            padding: EdgeInsets.only(top: 24, left: 24, right: 24, bottom: bottomPadding),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.playlist_add, size: 48, color: AppColors.midnightAccent),
              const SizedBox(height: 16),
              Text(
                'Import Playlist?',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: context.themeTextColor),
              ),
              const SizedBox(height: 8),
              Text(
                'We detected a Spotify playlist link. Would you like to import it to IT-Feels?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: context.themeMutedTextColor),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: GoogleFonts.inter(color: context.themeMutedTextColor)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.midnightAccent,
                        foregroundColor: context.themeBackgroundColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        PlaylistImportService().startBackgroundImport(
                          url, 
                          ref.read(customPlaylistProvider), 
                          MusicApiService()
                        );
                      },
                      child: Text('Import Now', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        });
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
    final settingsProv = ref.watch(settingsProvider);
    final enableVideos = settingsProv.enableMusicVideos;

    return Scaffold(
      backgroundColor: context.themeBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth >= 600;

          if (isWideScreen) {
            return Row(
              children: [
                // Floating Side Navigation Pill for Wide Screens
                SafeArea(
                  right: false,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        width: 96,
                        margin: const EdgeInsets.only(left: 12, top: 12, bottom: 12),
                        decoration: BoxDecoration(
                          color: context.themeSurfaceColor.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: context.themeInvertedTextColor.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(8, 0),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildNavItem(0, Icons.home_rounded, "Home", isVertical: true),
                            const SizedBox(height: 24),
                            _buildNavItem(1, Icons.search_rounded, "Search", isVertical: true),
                            const SizedBox(height: 24),
                            _buildNavItem(2, Icons.library_music_rounded, "Library", isVertical: true),
                            if (enableVideos) ...[
                              const SizedBox(height: 24),
                              _buildNavItem(3, Icons.video_library_rounded, "Videos", isVertical: true),
                            ],
                            const SizedBox(height: 24),
                            _buildNavItem(4, Icons.people_rounded, "Social", isVertical: true),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Main Content
                Expanded(
                  child: Stack(
                    children: [
                      // Active Shell Route
                      widget.navigationShell,
                      
                      // Floating MiniPlayer Overlay
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: MeasureSize(
                          onChange: (size) => ref.read(bottomUiProvider.notifier).updateHeight(size.height),
                          child: SafeArea(
                            bottom: true,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Import Progress Banner
                                const ImportProgressBanner(),
                                // Mini Player Pill
                                MiniPlayer(onTap: () => context.push('/now_playing')),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          // Mobile View
          return Stack(
            children: [
              // Active Shell Route
              widget.navigationShell,

              // Floating MiniPlayer + Bottom Navigation Bar Overlay
              if (MediaQuery.of(context).orientation == Orientation.portrait)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: MeasureSize(
                    onChange: (size) => ref.read(bottomUiProvider.notifier).updateHeight(size.height),
                    child: SafeArea(
                      bottom: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Import Progress Banner
                          const ImportProgressBanner(),
                          
                          // Mini Player Pill
                          MiniPlayer(onTap: () => context.push('/now_playing')),
      
                          // We moved VideoMiniplayer behind the Bottom Nav in the stack
                          // so the tabs are tappable and overlay the transparent part of PiP.
      
                          // Floating Bottom Navigation Bar Pill Container
                          ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Container(
                                height: 76,
                                margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                                decoration: BoxDecoration(
                                  color: context.themeSurfaceColor.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.themeInvertedTextColor.withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildNavItem(0, Icons.home_rounded, "Home"),
                                    _buildNavItem(1, Icons.search_rounded, "Search"),
                                    _buildNavItem(2, Icons.library_music_rounded, "Library"),
                                    if (enableVideos) _buildNavItem(3, Icons.video_library_rounded, "Videos"),
                                    _buildNavItem(4, Icons.people_rounded, "Social"),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {bool isVertical = false}) {
    final isSelected = widget.navigationShell.currentIndex == index;
    return Consumer(builder: (context, ref, child) { final playerProvider = ref.watch(audioPlayerProvider); 
        final content = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            widget.navigationShell.goBranch(
              index,
              initialLocation: index == widget.navigationShell.currentIndex,
            );
          },
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: EdgeInsets.symmetric(
                horizontal: isVertical ? 12 : 20,
                vertical: isVertical ? 16 : 16,
              ),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.midnightPill : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: isVertical
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        label == "Social"
                            ? Consumer(
                                builder: (context, ref, _) {
                                  final count = ref.watch(unreadCountProvider).value ?? 0;
                                  final iconWidget = Icon(icon, color: isSelected ? AppColors.midnightAccent : context.themeMutedTextColor, size: 32);
                                  if (count > 0) return Badge(label: Text(count.toString()), backgroundColor: Colors.redAccent, child: iconWidget);
                                  return iconWidget;
                                },
                              )
                            : Icon(
                                icon,
                                color: isSelected ? AppColors.midnightAccent : context.themeMutedTextColor,
                                size: 32,
                              ),
                        if (isSelected) ...[
                          const SizedBox(height: 6),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: context.themeTextColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        label == "Social"
                            ? Consumer(
                                builder: (context, ref, _) {
                                  final count = ref.watch(unreadCountProvider).value ?? 0;
                                  final iconWidget = Icon(icon, color: isSelected ? AppColors.midnightAccent : context.themeMutedTextColor, size: 32);
                                  if (count > 0) return Badge(label: Text(count.toString()), backgroundColor: Colors.redAccent, child: iconWidget);
                                  return iconWidget;
                                },
                              )
                            : Icon(
                                icon,
                                color: isSelected ? AppColors.midnightAccent : context.themeMutedTextColor,
                                size: 32,
                              ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: context.themeTextColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        );
        return isVertical ? content : Expanded(child: content);
      },
    );
  }
}
