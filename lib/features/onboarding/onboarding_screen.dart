import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/services/storage_service.dart';
import 'package:it_feels_music/core/widgets/glass_shield_wrapper.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<OnboardingSlide> _slides = [
    OnboardingSlide(
      title: "Feel the Music",
      description: "Experience high-resolution audio with an ad-free, stunning interface.",
      icon: Icons.headphones_rounded,
      color: Colors.blueAccent,
    ),
    OnboardingSlide(
      title: "Listen Together",
      description: "Create synchronized rooms and enjoy music with your friends in real-time.",
      icon: Icons.people_alt_rounded,
      color: Colors.pinkAccent,
    ),
    OnboardingSlide(
      title: "Visual Canvas",
      description: "Immerse yourself in 4K music videos and seamless background playback.",
      icon: Icons.ondemand_video_rounded,
      color: Colors.deepPurpleAccent,
    ),
  ];

  void _finishOnboarding() async {
    await StorageService.setHasSeenOnboarding(true);
    if (mounted) {
      context.go('/home');
    }
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
                    _slides[_currentIndex].color.withValues(alpha: 0.15),
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
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: slide.color.withValues(alpha: 0.1),
                                border: Border.all(
                                  color: slide.color.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                slide.icon,
                                size: 100,
                                color: slide.color,
                              ),
                            ),
                            const SizedBox(height: 64),
                            Text(
                              slide.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: context.themeTextColor,
                                shadows: context.themeTextShadow, // Requires ThemeContext extension
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              slide.description,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                height: 1.5,
                                color: context.themeMutedTextColor,
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      );
                    },
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
                          _slides.length,
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
                        child: _currentIndex == _slides.length - 1
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
    );
    );
  }
}

class OnboardingSlide {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingSlide({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
