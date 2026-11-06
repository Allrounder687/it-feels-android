import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/settings/profile_screen.dart';
import '../theme/new_experience_tokens.dart';

class NewDesktopTitleBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  const NewDesktopTitleBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  ConsumerState<NewDesktopTitleBar> createState() => _NewDesktopTitleBarState();
}

class _NewDesktopTitleBarState extends ConsumerState<NewDesktopTitleBar> with WindowListener {
  bool _isFocused = true;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      windowManager.removeListener(this);
    }
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
    if (kIsWeb || (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux)) return;
    final isMaximized = await windowManager.isMaximized();
    if (isMaximized) {
      windowManager.unmaximize();
    } else {
      windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux)) {
      return const SizedBox.shrink();
    }

    final user = ref.watch(authProvider).currentUser;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: NewExperienceTokens.obsidianBackground,
        border: Border(
          bottom: BorderSide(
            color: NewExperienceTokens.specularBorder.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Drag area covering the left and center
          Expanded(
            child: DragToMoveArea(
              child: GestureDetector(
                onDoubleTap: _maximizeOrRestore,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              NewExperienceTokens.accentViolet,
                              NewExperienceTokens.accentCyan,
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.headphones_rounded, color: Colors.white, size: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'IT FEELS',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: _isFocused
                              ? NewExperienceTokens.textPrimary
                              : NewExperienceTokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Right Controls: Profile Avatar & Caption Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: NewExperienceTokens.midnightSurface,
                    backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                    child: user?.photoURL == null
                        ? const Icon(Icons.person_rounded, size: 14, color: NewExperienceTokens.textSecondary)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _NewCaptionButton(
                icon: Icons.remove_rounded,
                onTap: () => windowManager.minimize(),
                tooltip: 'Minimize',
              ),
              _NewCaptionButton(
                icon: Icons.crop_square_rounded,
                onTap: _maximizeOrRestore,
                tooltip: 'Maximize',
              ),
              _NewCaptionButton(
                icon: Icons.close_rounded,
                onTap: () => windowManager.close(),
                isClose: true,
                tooltip: 'Close',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NewCaptionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isClose;
  final String tooltip;

  const _NewCaptionButton({
    required this.icon,
    required this.onTap,
    this.isClose = false,
    required this.tooltip,
  });

  @override
  State<_NewCaptionButton> createState() => _NewCaptionButtonState();
}

class _NewCaptionButtonState extends State<_NewCaptionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    Color iconColor = NewExperienceTokens.textSecondary;

    if (_isHovered) {
      if (widget.isClose) {
        bg = const Color(0xFFE81123);
        iconColor = Colors.white;
      } else {
        bg = Colors.white.withValues(alpha: 0.1);
        iconColor = Colors.white;
      }
    }

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 46,
            height: 40,
            color: bg,
            alignment: Alignment.center,
            child: Icon(widget.icon, size: 16, color: iconColor),
          ),
        ),
      ),
    );
  }
}
