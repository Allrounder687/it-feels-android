import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/bottom_ui_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/settings/profile_screen.dart';
import 'package:it_feels_music/features/social/room_bottom_sheet.dart';
import 'package:it_feels_music/features/radio/radio_screen.dart';
import 'package:it_feels_music/features/settings/settings_screen.dart';
import 'package:it_feels_music/core/widgets/tv_focusable_card.dart';
import 'package:it_feels_music/features/settings/settings_provider.dart';

class PremiumTitleBar extends ConsumerStatefulWidget {
  final bool isWideScreen;
  final bool isSolid;
  const PremiumTitleBar({
    super.key,
    required this.isWideScreen,
    this.isSolid = false,
  });

  @override
  ConsumerState<PremiumTitleBar> createState() => _PremiumTitleBarState();
}

class _PremiumTitleBarState extends ConsumerState<PremiumTitleBar>
    with WindowListener {
  bool _isFocused = true;
  bool _isLogoHovered = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _searchController.dispose();
    _searchFocusNode.dispose();
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

    final isGlass = context.isGlassTheme;
    final surfaceColor = context.themeSurfaceColor;
    final backgroundColor = context.themeBackgroundColor;

    // Simulate Mica with a vertical gradient + blur
    final gradient = isGlass
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x0DFFFFFF), Colors.transparent], // 5% white to transparent
          )
        : (widget.isSolid
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [surfaceColor, backgroundColor],
              )
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  surfaceColor.withValues(alpha: _isFocused ? 0.3 : 0.1),
                  backgroundColor.withValues(alpha: _isFocused ? 0.4 : 0.2),
                ],
              ));

    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: isGlass
            ? const Border(bottom: BorderSide(color: Color(0x1FFFFFFF), width: 1.0))
            : null,
        boxShadow: !isGlass
            ? [
                // Subtle inner bottom shadow to create a glass edge
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.05),
                  offset: const Offset(0, 1),
                  blurRadius: 0,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        child: Consumer(
          builder: (context, ref, child) {
            final settings = ref.watch(settingsProvider);
            double blurAmount = 25.0;
            if (settings.graphicsQuality == GraphicsQuality.medium) {
              blurAmount = 10.0;
            } else if (settings.graphicsQuality == GraphicsQuality.low) {
              blurAmount = 0.0;
            }
            if (widget.isSolid || isGlass) blurAmount = 0.0;

            return BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blurAmount,
                sigmaY: blurAmount,
              ),
              child: child,
            );
          },
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
              MouseRegion(
                onEnter: (_) => setState(() => _isLogoHovered = true),
                onExit: (_) => setState(() => _isLogoHovered = false),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    // We need to import bottom_ui_provider.dart at the top to access sidebarPinnedProvider
                    final current = ref.read(sidebarPinnedProvider);
                    ref.read(sidebarPinnedProvider.notifier).state = !current;
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _isLogoHovered
                          ? context.themeAccentColor.withValues(alpha: 0.2)
                          : const Color(0xFF2A3441),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: _isLogoHovered
                        ? Icon(
                            Icons.menu_rounded,
                            key: const ValueKey('menu_icon'),
                            size: 18,
                            color: context.themeAccentColor,
                          )
                        : Text(
                            "IF",
                            key: const ValueKey('text_icon'),
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: -0.5,
                            ),
                          ),
                  ),
                ),
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/now_playing'),
        child: Stack(
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
            // Aesthetic Audio Visualizer Line (Pulsing)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _PulsingAudioVisualizer(isFocused: _isFocused),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalSearch() {
    if (!widget.isWideScreen) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.center,
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
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: TextStyle(
                  fontSize: 12,
                  color: context.themeTextColor,
                ),
                decoration: InputDecoration(
                  hintText: "Search It Feels...",
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: context.themeTextColor.withValues(alpha: 0.5),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.only(bottom: 14),
                ),
                onChanged: (val) {
                  setState(() {});

                  final uri = GoRouterState.of(context).uri.toString();
                  if (uri != '/search') {
                    context.go('/search');
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (mounted) _searchFocusNode.requestFocus();
                    });
                  }
                  ref.read(searchProvider.notifier).search(val);
                },
              ),
            ),
            if (_searchController.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _searchController.clear();
                  });
                  ref.read(searchProvider.notifier).search('');
                },
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: context.themeTextColor.withValues(alpha: 0.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightControls(BuildContext context) {
    final playerProvider = ref.watch(audioPlayerProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Profile Avatar
        TVFocusableCard(
          focusedScale: 1.1,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ProfileScreen(),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: Consumer(
              builder: (context, ref, _) {
                final profile = ref.watch(profileProvider);
                final hasAvatar = profile.userAvatar.isNotEmpty &&
                    File(profile.userAvatar).existsSync();
                return CircleAvatar(
                  radius: 12,
                  backgroundColor: context.themeAccentColor.withValues(alpha: 0.2),
                  backgroundImage: hasAvatar
                      ? FileImage(File(profile.userAvatar))
                      : null,
                  child: hasAvatar
                      ? null
                      : Icon(
                          Icons.person_outline,
                          color: context.themeTextColor,
                          size: 14,
                        ),
                );
              },
            ),
          ),
        ),
        // Listen Together
        _TitleBarIconButton(
          icon: Icons.cell_tower_rounded,
          color: playerProvider.isInRoom ? Colors.greenAccent : context.themeTextColor,
          onTap: () => RoomBottomSheet.show(context, isHost: false),
          tooltip: 'Listen Together',
        ),
        // Radio Stations
        _TitleBarIconButton(
          icon: Icons.radio,
          color: context.themeTextColor,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RadioScreen()),
          ),
          tooltip: 'Radio Stations',
        ),
        // Settings
        _TitleBarIconButton(
          icon: Icons.settings_outlined,
          color: context.themeTextColor,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          tooltip: 'Settings',
        ),
        const SizedBox(width: 8),
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

class _TitleBarIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final String tooltip;

  const _TitleBarIconButton({
    required this.icon,
    required this.onTap,
    required this.color,
    required this.tooltip,
  });

  @override
  State<_TitleBarIconButton> createState() => _TitleBarIconButtonState();
}

class _TitleBarIconButtonState extends State<_TitleBarIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Tooltip(
          message: widget.tooltip,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            height: 48,
            color: _isHovered ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
            child: Icon(widget.icon, size: 16, color: widget.color),
          ),
        ),
      ),
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
          width: 46,
          height: 48,
          color: _isHovered ? hoverColor : Colors.transparent,
          child: Icon(widget.icon, size: 16, color: iconColor),
        ),
      ),
    );
  }
}

class _PulsingAudioVisualizer extends StatefulWidget {
  final bool isFocused;
  const _PulsingAudioVisualizer({required this.isFocused});

  @override
  State<_PulsingAudioVisualizer> createState() => _PulsingAudioVisualizerState();
}

class _PulsingAudioVisualizerState extends State<_PulsingAudioVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    _opacityAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  context.themeAccentColor.withValues(alpha: widget.isFocused ? 1.0 : 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
