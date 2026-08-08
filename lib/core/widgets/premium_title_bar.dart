import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';

class PremiumTitleBar extends ConsumerStatefulWidget {
  final bool isWideScreen;
  const PremiumTitleBar({super.key, required this.isWideScreen});

  @override
  ConsumerState<PremiumTitleBar> createState() => _PremiumTitleBarState();
}

class _PremiumTitleBarState extends ConsumerState<PremiumTitleBar>
    with WindowListener {
  bool _isFocused = true;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowFocus() {
    if (mounted) setState(() => _isFocused = true);
  }

  @override
  void onWindowBlur() {
    if (mounted) setState(() => _isFocused = false);
  }

  void _maximizeOrRestore() async {
    final isMaximized = await windowManager.isMaximized();
    if (isMaximized) {
      windowManager.unmaximize();
    } else {
      windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      return const SizedBox.shrink();
    }

    final surfaceColor = context.themeSurfaceColor;
    final backgroundColor = context.themeBackgroundColor;

    // Simulate Mica with a vertical gradient + blur
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        surfaceColor.withValues(alpha: _isFocused ? 0.7 : 0.4),
        backgroundColor.withValues(alpha: _isFocused ? 0.9 : 0.6),
      ],
    );

    return Container(
      height: 48,
      decoration: BoxDecoration(
        boxShadow: [
          // Subtle inner bottom shadow to create a glass edge
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.05),
            offset: const Offset(0, 1),
            blurRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(gradient: gradient),
            child: Row(
              children: [
                // 1. Branding (Left)
                _buildBranding(),

                // 2. Center Context (Search or Now Playing)
                Expanded(
                  child: DragToMoveArea(
                    child: GestureDetector(
                      onDoubleTap: _maximizeOrRestore,
                      child: Container(
                        color: Colors
                            .transparent, // Ensures it captures drag events
                        child: _buildCenterContent(),
                      ),
                    ),
                  ),
                ),

                // 3. Status & Controls (Right)
                _buildRightControls(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBranding() {
    return DragToMoveArea(
      child: GestureDetector(
        onDoubleTap: _maximizeOrRestore,
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/icon.png',
                width: 20,
                height: 20,
                color: _isFocused ? null : Colors.grey.withValues(alpha: 0.5),
                colorBlendMode: _isFocused
                    ? BlendMode.dst
                    : BlendMode.saturation,
              ),
              const SizedBox(width: 12),
              Text(
                "It Feels",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.themeTextColor.withValues(
                    alpha: _isFocused ? 1.0 : 0.5,
                  ),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterContent() {
    final playerProv = ref.watch(audioPlayerProvider);
    final song = playerProv.currentSong;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: song != null
          ? _buildNowPlayingIndicator(song)
          : _buildGlobalSearch(),
    );
  }

  Widget _buildNowPlayingIndicator(song) {
    return Stack(
      children: [
        Align(
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.graphic_eq_rounded,
                size: 14,
                color: context.themeAccentColor.withValues(
                  alpha: _isFocused ? 0.8 : 0.4,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  "${song.title} • ${song.artist}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.themeTextColor.withValues(
                      alpha: _isFocused ? 0.9 : 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Progress Sliver
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: StreamBuilder<Duration>(
            stream: ref
                .read(audioPlayerProvider.notifier)
                .engine
                .positionStream,
            builder: (context, snapshot) {
              final pos = snapshot.data?.inMilliseconds ?? 0;
              final dur = ref.read(audioPlayerProvider).duration.inMilliseconds;
              final progress = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: context.themeAccentColor.withValues(
                      alpha: _isFocused ? 0.8 : 0.3,
                    ),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(3),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGlobalSearch() {
    if (!widget.isWideScreen) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.center,
      child: InkWell(
        onTap: () => context.push('/search'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 32,
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.themeBackgroundColor.withValues(
              alpha: _isFocused ? 0.3 : 0.1,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.themeTextColor.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 16,
                color: context.themeTextColor.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 8),
              Text(
                "Search It Feels...",
                style: TextStyle(
                  fontSize: 12,
                  color: context.themeTextColor.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightControls(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dummy Status Chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
          ),
          child: const Text(
            "Hi-Fi",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.amber,
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Window Controls
        _CaptionButton(
          icon: Icons.remove,
          onTap: () => windowManager.minimize(),
          isFocused: _isFocused,
        ),
        _CaptionButton(
          icon: Icons.crop_square_rounded,
          onTap: _maximizeOrRestore,
          isFocused: _isFocused,
        ),
        _CaptionButton(
          icon: Icons.close_rounded,
          onTap: () => windowManager.close(),
          isFocused: _isFocused,
          isClose: true,
        ),
      ],
    );
  }
}

class _CaptionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isFocused;
  final bool isClose;

  const _CaptionButton({
    required this.icon,
    required this.onTap,
    required this.isFocused,
    this.isClose = false,
  });

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color hoverColor = widget.isClose
        ? Colors.red
        : (isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.1));

    Color iconColor = widget.isFocused
        ? (widget.isClose && _isHovered
              ? Colors.white
              : theme.iconTheme.color ?? Colors.white)
        : (theme.iconTheme.color?.withValues(alpha: 0.5) ?? Colors.grey);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 48,
          height: 48,
          color: _isHovered ? hoverColor : Colors.transparent,
          child: Icon(widget.icon, size: 16, color: iconColor),
        ),
      ),
    );
  }
}
