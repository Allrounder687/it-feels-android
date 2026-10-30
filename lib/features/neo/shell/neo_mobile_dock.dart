import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/providers/bottom_ui_provider.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:it_feels_music/features/social/unread_count_provider.dart';
import 'package:it_feels_music/features/neo/theme/neo_glass.dart';

class NeoMobileDock extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const NeoMobileDock({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerProvider);
    final videoState = ref.watch(videoPlayerProvider);
    final settings = ref.watch(settingsProvider);
    final currentSong = playerState.currentSong;

    final isSameSong = currentSong != null &&
        (videoState.currentVideoId == currentSong.id ||
            videoState.currentVideoId == 'search:${currentSong.id}');
    final isMutedCanvas = !settings.useVideoAudioSource && isSameSong;
    final showAudioMini = currentSong != null && (!videoState.isVideoActive || isMutedCanvas);

    final enableVideos = settings.enableMusicVideos;
    final currentIndex = navigationShell.currentIndex;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final bottomUiHeight = isKeyboardOpen ? 0.0 : ref.watch(bottomUiProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Active Navigation Tab View ──
          MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: MediaQuery.of(context).padding.copyWith(
                    bottom: math.max(MediaQuery.of(context).padding.bottom, bottomUiHeight),
                  ),
              viewPadding: MediaQuery.of(context).viewPadding.copyWith(
                    bottom: math.max(MediaQuery.of(context).viewPadding.bottom, bottomUiHeight),
                  ),
            ),
            child: navigationShell,
          ),

          // ── Unified Frosted Island Dock Overlay ──
          if (!isKeyboardOpen && MediaQuery.of(context).orientation == Orientation.portrait)
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. Floating MiniPlayer Island
                        if (showAudioMini) ...[
                          _NeoMiniPlayerIsland(
                            song: currentSong,
                            isPlaying: playerState.isPlaying,
                            accentColor: playerState.themeAccentColor,
                            onTap: () => context.push('/now_playing'),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // 2. Floating Frosted Navigation Island
                        _NeoNavBarIsland(
                          currentIndex: currentIndex,
                          enableVideos: enableVideos,
                          accentColor: playerState.themeAccentColor,
                          onTabSelected: (index) {
                            HapticFeedback.selectionClick();
                            navigationShell.goBranch(
                              index,
                              initialLocation: index == currentIndex,
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NeoMiniPlayerIsland extends ConsumerWidget {
  final dynamic song;
  final bool isPlaying;
  final Color accentColor;
  final VoidCallback onTap;

  const _NeoMiniPlayerIsland({
    required this.song,
    required this.isPlaying,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerProvider);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -180) {
            HapticFeedback.lightImpact();
            ref.read(audioPlayerProvider.notifier).skipToNext();
          } else if (details.primaryVelocity! > 180) {
            HapticFeedback.lightImpact();
            ref.read(audioPlayerProvider.notifier).skipToPrevious();
          }
        }
      },
      child: NeoGlassContainer(
        height: NeoTokens.dockMiniPlayerHeight,
        borderRadius: 18,
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              // Top 2.5px Micro-Progress Bar
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: RepaintBoundary(
                  child: StreamBuilder<Duration>(
                    stream: ref.read(audioPlayerProvider.notifier).audioHandler.player.stream.position,
                    initialData: playerState.position,
                    builder: (context, snapshot) {
                      final pos = snapshot.data ?? playerState.position;
                      final totalMs = playerState.duration.inMilliseconds;
                      final progress = (totalMs > 0)
                          ? (pos.inMilliseconds / totalMs).clamp(0.0, 1.0)
                          : 0.0;

                      return LinearProgressIndicator(
                        value: progress,
                        minHeight: 2.5,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      );
                    },
                  ),
                ),
              ),

              // Content Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Row(
                  children: [
                    // Squircle Album Art Thumbnail with Hero
                    Hero(
                      tag: 'cover_${song.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: song.coverArt.isNotEmpty
                              ? CustomImageWidget(
                                  imageUrl: song.coverArt,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => Container(
                                    color: const Color(0xFF1E2433),
                                    child: const Icon(
                                      Icons.music_note_rounded,
                                      size: 20,
                                      color: Colors.white54,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: const Color(0xFF1E2433),
                                  child: const Icon(
                                    Icons.music_note_rounded,
                                    size: 20,
                                    color: Colors.white54,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title & Artist
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Quick Play/Pause Action
                    IconButton(
                      iconSize: 28,
                      icon: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ref.read(audioPlayerProvider.notifier).togglePlayPause();
                      },
                      tooltip: isPlaying ? 'Pause' : 'Play',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeoNavBarIsland extends StatelessWidget {
  final int currentIndex;
  final bool enableVideos;
  final Color accentColor;
  final ValueChanged<int> onTabSelected;

  const _NeoNavBarIsland({
    required this.currentIndex,
    required this.enableVideos,
    required this.accentColor,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return NeoGlassContainer(
      height: NeoTokens.dockNavBarHeight,
      borderRadius: 28,
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildItem(index: 0, icon: Icons.home_rounded, label: "Home"),
          _buildItem(index: 1, icon: Icons.search_rounded, label: "Search"),
          _buildItem(index: 2, icon: Icons.library_music_rounded, label: "Library"),
          if (enableVideos)
            _buildItem(index: 3, icon: Icons.video_library_rounded, label: "Videos"),
          _buildItem(
            index: 4,
            icon: Icons.people_rounded,
            label: "Social",
            isSocial: true,
          ),
          _buildItem(index: 5, icon: Icons.settings_rounded, label: "Settings"),
        ],
      ),
    );
  }

  Widget _buildItem({
    required int index,
    required IconData icon,
    required String label,
    bool isSocial = false,
  }) {
    final isSelected = index == currentIndex;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTabSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: isSocial
                ? Consumer(
                    builder: (context, ref, _) {
                      final unread = ref.watch(unreadCountProvider).value ?? 0;
                      return Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            icon,
                            size: 24,
                            color: isSelected ? accentColor : Colors.white60,
                          ),
                          if (unread > 0)
                            Positioned(
                              top: -2,
                              right: -4,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF3B30),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  )
                : Icon(
                    icon,
                    size: 24,
                    color: isSelected ? accentColor : Colors.white60,
                  ),
          ),
        ),
      ),
    );
  }
}
