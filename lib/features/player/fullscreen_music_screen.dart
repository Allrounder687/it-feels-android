import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/services.dart';

import 'package:it_feels_music/core/widgets/glass_shield_wrapper.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/features/player/widgets/now_playing_art.dart';
import 'package:it_feels_music/features/player/widgets/now_playing_info.dart';
import 'package:it_feels_music/features/player/widgets/now_playing_controls.dart';
import 'package:it_feels_music/features/player/widgets/now_playing_progress.dart';

class FullscreenMusicScreen extends ConsumerStatefulWidget {
  const FullscreenMusicScreen({super.key});

  @override
  ConsumerState<FullscreenMusicScreen> createState() => _FullscreenMusicScreenState();
}

class _FullscreenMusicScreenState extends ConsumerState<FullscreenMusicScreen> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      windowManager.ensureInitialized().then((_) {
        windowManager.setFullScreen(true);
      });
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      windowManager.setFullScreen(false);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = ref.watch(audioPlayerProvider);
    final currentSong = playerProvider.currentSong;

    if (currentSong == null) {
      return GlassShieldWrapper(
        isGlassMode: context.isGlassTheme,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Text(
              "No song selected",
              style: GoogleFonts.inter(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    final accentColor = playerProvider.themeAccentColor;
    final surfaceColor = playerProvider.themeSurfaceColor;
    final bgColor = playerProvider.themeBackgroundColor;

    return GlassShieldWrapper(
      isGlassMode: context.isGlassTheme,
      child: Scaffold(
        backgroundColor: bgColor,
        body: Stack(
          children: [
            // Hardware-accelerated Glowing Background
            Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return Stack(
                  children: [
                    // Base background
                    Container(color: bgColor),
                    
                    // Top Left Glow
                    Positioned(
                      top: -200 + (_glowController.value * 50),
                      left: -200 - (_glowController.value * 50),
                      child: Container(
                        width: 800,
                        height: 800,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              surfaceColor.withValues(alpha: 0.6),
                              surfaceColor.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Bottom Right Glow
                    Positioned(
                      bottom: -300 - (_glowController.value * 50),
                      right: -200 + (_glowController.value * 50),
                      child: Container(
                        width: 1000,
                        height: 1000,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              accentColor.withValues(alpha: 0.5),
                              accentColor.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          // Noise overlay for texture
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.1),
            ),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Header (Window Controls)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    children: [
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white, size: 32),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Exit Full Screen',
                      ),
                    ],
                  ),
                ),

                // Expanded Center Content
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 800;
                      // Massive scale for full screen
                      final artSize = (constraints.maxHeight * 0.55).clamp(200.0, 600.0);

                      return Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: isWide ? 800 : 600),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Massive Centered Art
                                Container(
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        blurRadius: 40,
                                        spreadRadius: 5,
                                        offset: const Offset(0, 20),
                                      ),
                                    ],
                                  ),
                                  child: NowPlayingArt(
                                    isVideoMode: false,
                                    isWide: isWide,
                                    artSize: artSize,
                                    currentSong: currentSong,
                                    isPlaying: playerProvider.isPlaying,
                                    surfaceColor: surfaceColor,
                                    accentColor: accentColor,
                                    onQualityPickerTap: () {}, // No video mode in this music-only fullscreen
                                  ),
                                ),
                                const SizedBox(height: 48),

                                // Title and Info
                                NowPlayingInfo(
                                  currentSong: currentSong,
                                  isWide: false, // Forces centered layout size (actually isWide=true makes font 46, we might want that)
                                ),
                                const SizedBox(height: 32),

                                // Progress
                                NowPlayingProgress(
                                  isVideoMode: false,
                                  accentColor: accentColor,
                                ),
                                const SizedBox(height: 24),

                                // Primary Controls
                                NowPlayingPrimaryControls(
                                  isWide: false, // Prevents row alignment from blowing up, forces centered layout
                                  isVideoMode: false,
                                  surfaceColor: surfaceColor,
                                  accentColor: accentColor,
                                ),
                                const SizedBox(height: 16),
                                
                                // Secondary Controls (Lyrics, Volume, etc)
                                NowPlayingSecondaryControls(
                                  isWide: false,
                                  accentColor: accentColor,
                                ),
                                
                                const SizedBox(height: 48), // Bottom padding
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}
