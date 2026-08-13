import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:it_feels_music/features/cast/cast_bottom_sheet.dart';

class NowPlayingHeader extends ConsumerWidget {
  final bool isVideoMode;
  final bool hasViewedVideoForCurrentSong;
  final Color surfaceColor;
  final Color accentColor;
  final void Function(bool) onToggleMode;
  final VoidCallback onOptionsTap;

  const NowPlayingHeader({
    super.key,
    required this.isVideoMode,
    required this.hasViewedVideoForCurrentSong,
    required this.surfaceColor,
    required this.accentColor,
    required this.onToggleMode,
    required this.onOptionsTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoProvider = ref.watch(videoPlayerProvider);
    
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.themeTextColor, size: 30),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Close Player',
        ),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: surfaceColor.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => onToggleMode(false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: !isVideoMode ? accentColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Song',
                    style: GoogleFonts.inter(
                      color: !isVideoMode ? context.themeInvertedTextColor : context.themeMutedTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => onToggleMode(true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isVideoMode ? accentColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: (!isVideoMode && !hasViewedVideoForCurrentSong && videoProvider.videoController != null)
                        ? [BoxShadow(color: accentColor.withValues(alpha: 0.8), blurRadius: 10, spreadRadius: 2)]
                        : null,
                  ),
                  child: Text(
                    'Video',
                    style: GoogleFonts.inter(
                      color: isVideoMode || (videoProvider.videoController != null) 
                          ? context.themeInvertedTextColor : context.themeMutedTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) ...[
              IconButton(
                icon: Icon(Icons.fullscreen_rounded, color: context.themeTextColor, size: 28),
                onPressed: () {
                  context.push('/fullscreen_music');
                },
                tooltip: 'Full Screen Player',
              ),
              IconButton(
                icon: Icon(Icons.picture_in_picture_alt, color: context.themeTextColor, size: 24),
                onPressed: () async {
                  context.push('/desktop_miniplayer');
                  await windowManager.setMinimumSize(const Size(300, 150));
                  await windowManager.setSize(const Size(350, 200));
                  await windowManager.setAlwaysOnTop(true);
                  await windowManager.setResizable(true);
                  
                  // Use screen_retriever to respect the Windows Taskbar bounds (workArea)
                  try {
                    final display = await screenRetriever.getPrimaryDisplay();
                    final visibleSize = display.visibleSize;
                    final visiblePos = display.visiblePosition;
                    if (visibleSize != null && visiblePos != null) {
                      await windowManager.setPosition(
                        Offset(visiblePos.dx + visibleSize.width - 350, visiblePos.dy + visibleSize.height - 200),
                      );
                    } else {
                      await windowManager.setAlignment(Alignment.bottomRight);
                    }
                  } catch (_) {
                    await windowManager.setAlignment(Alignment.bottomRight);
                  }
                },
                tooltip: 'Miniplayer',
              ),
            ],
            IconButton(
              icon: Icon(Icons.cast_rounded, color: context.themeTextColor, size: 24),
              onPressed: () {
                CastBottomSheet.show(context);
              },
              tooltip: 'Cast',
            ),
            IconButton(
              icon: Icon(Icons.graphic_eq_rounded, color: context.themeTextColor, size: 24),
              onPressed: () {
                context.push('/audio_settings');
              },
              tooltip: 'Equalizer',
            ),
            IconButton(
              icon: Icon(Icons.more_vert_rounded, color: context.themeTextColor, size: 26),
              onPressed: onOptionsTap,
              tooltip: 'Options',
            ),
            if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.remove, color: context.themeTextColor, size: 24),
                onPressed: () => windowManager.minimize(),
                tooltip: 'Minimize App',
              ),
              IconButton(
                icon: Icon(Icons.close, color: context.themeTextColor, size: 24),
                onPressed: () => windowManager.close(),
                tooltip: 'Close App',
                hoverColor: Colors.red.withValues(alpha: 0.8), // subtle red hover for aesthetic
              ),
            ],
          ],
        ),
            ),
          ),
        ),
      ],
    );

    if (kIsWeb || (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux)) {
      return content;
    }
    
    return DragToMoveArea(child: content);
  }
}
