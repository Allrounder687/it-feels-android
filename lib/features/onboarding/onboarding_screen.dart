import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/services/storage_service.dart';
import 'package:it_feels_music/core/widgets/glass_shield_wrapper.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/widgets/wavy_seek_bar.dart';

import 'package:it_feels_music/features/onboarding/widgets/welcome_permissions_sheet.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  
  // State for Vibe Check
  String _selectedVibe = "Upbeat";
  final Map<String, Color> _vibes = {
    "Late Night Drive": Colors.deepPurpleAccent,
    "Focus": Colors.tealAccent,
    "Upbeat": Colors.amber,
    "Chill": Colors.blueAccent,
  };

  // State for Sound Check
  Duration _sliderPosition = const Duration(seconds: 30);
  final Duration _sliderDuration = const Duration(seconds: 120);

  void _finishOnboarding() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => WelcomePermissionsSheet(
        onComplete: () {
          StorageService.setHasSeenOnboarding(true);
          context.go('/home');
        },
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassShieldWrapper(
      isGlassMode: context.isGlassTheme,
      child: Scaffold(
        backgroundColor: context.themeBackgroundColor,
        body: Stack(
          children: [
            // Background Gradient Element
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 1.5,
                    colors: [
                      _vibes[_selectedVibe]!.withValues(alpha: 0.15),
                      context.themeBackgroundColor,
                    ],
                  ),
                ),
              ),
            ),
            
            SafeArea(
              child: Column(
                children: [
                  // Top Bar with Skip
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _finishOnboarding,
                          child: Text(
                            "Skip",
                            style: TextStyle(
                              color: context.themeMutedTextColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // PageView
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                      children: [
                        _buildVibeCheckSlide(),
                        _buildThemePreviewSlide(),
                        _buildSoundCheckSlide(),
                      ],
                    ),
                  ),
                  
                  // Bottom Controls
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Dot Indicators
                        Row(
                          children: List.generate(
                            3,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(right: 8),
                              height: 8,
                              width: _currentIndex == index ? 24 : 8,
                              decoration: BoxDecoration(
                                color: _currentIndex == index 
                                    ? context.themeTextColor 
                                    : context.themeTextColor24,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        
                        // Next/Start Button
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _currentIndex == 2
                              ? ElevatedButton(
                                  key: const ValueKey("start"),
                                  onPressed: _finishOnboarding,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: context.themeTextColor,
                                    foregroundColor: context.themeInvertedTextColor,
                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    "Get Started",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                )
                              : IconButton(
                                  key: const ValueKey("next"),
                                  onPressed: () {
                                    _pageController.nextPage(
                                      duration: const Duration(milliseconds: 400),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  style: IconButton.styleFrom(
                                    backgroundColor: context.themeCardColor,
                                    padding: const EdgeInsets.all(16),
                                  ),
                                  icon: Icon(Icons.arrow_forward_rounded, color: context.themeTextColor),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVibeCheckSlide() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _vibes[_selectedVibe]!.withValues(alpha: 0.1),
              border: Border.all(
                color: _vibes[_selectedVibe]!.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 80,
              color: _vibes[_selectedVibe],
            ),
          ),
          const SizedBox(height: 48),
          Text(
            "What's your vibe?",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: context.themeTextColor,
              shadows: context.themeTextShadow,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Tap a mood below and watch the AI engine adapt the interface in real-time.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: context.themeMutedTextColor,
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: _vibes.keys.map((vibe) {
              final isSelected = _selectedVibe == vibe;
              return ChoiceChip(
                label: Text(vibe),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedVibe = vibe;
                    });
                  }
                },
                selectedColor: _vibes[vibe]!.withValues(alpha: 0.2),
                backgroundColor: context.themeCardColor,
                labelStyle: TextStyle(
                  color: isSelected ? _vibes[vibe] : context.themeTextColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? _vibes[vibe]! : Colors.transparent,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildThemePreviewSlide() {
    final currentTheme = ref.watch(audioPlayerProvider).appThemeMode;
    final isGlass = currentTheme == AppThemeMode.glass;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.pinkAccent.withValues(alpha: 0.1),
              border: Border.all(
                color: Colors.pinkAccent.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.format_paint_rounded,
              size: 80,
              color: Colors.pinkAccent,
            ),
          ),
          const SizedBox(height: 48),
          Text(
            "Theme Preview",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: context.themeTextColor,
              shadows: context.themeTextShadow,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Toggle between the immersive Glass Mode and deep Midnight Blue.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: context.themeMutedTextColor,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.themeCardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.themeTextColor10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isGlass ? Icons.blur_on_rounded : Icons.dark_mode_rounded,
                      color: context.themeTextColor,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      isGlass ? "Glass Mode" : "Midnight Blue",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: context.themeTextColor,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: isGlass,
                  onChanged: (value) {
                    ref.read(audioPlayerProvider.notifier).setAppThemeMode(
                      value ? AppThemeMode.glass : AppThemeMode.midnight,
                    );
                  },
                  activeThumbColor: Colors.pinkAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundCheckSlide() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blueAccent.withValues(alpha: 0.1),
              border: Border.all(
                color: Colors.blueAccent.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.graphic_eq_rounded,
              size: 80,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 48),
          Text(
            "Feel the Music",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: context.themeTextColor,
              shadows: context.themeTextShadow,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Drag the squiggly slider below to experience premium haptics and precise scrubbing.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: context.themeMutedTextColor,
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            height: 60,
            child: WavySeekBar(
              position: _sliderPosition,
              duration: _sliderDuration,
              activeColor: context.themeTextColor,
              inactiveColor: context.themeTextColor24,
              onSeek: (value) {
                setState(() {
                  _sliderPosition = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
