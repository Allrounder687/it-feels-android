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
import 'package:it_feels_music/features/home/home_provider.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/data/services/audio_engine_service.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  int _visibleArtistCount = 20;
  
  // Animation for Wiggly Skip
  late AnimationController _wiggleController;
  late Animation<double> _wiggleAnimation;
  bool _isSkipping = false;

  // State for Artist Selection
  final List<String> _selectedArtists = [];
  final List<String> _popularArtists = [
    "Arijit Singh", "The Weeknd", "Taylor Swift", "Shreya Ghoshal", 
    "Travis Scott", "Post Malone", "Kendrick Lamar", "Pritam", 
    "A.R. Rahman", "Billie Eilish", "Drake", "Ed Sheeran",
    "Diljit Dosanjh", "Karan Aujla", "Dua Lipa", "Vishal-Shekhar",
    "Justin Bieber", "Badshah", "Neha Kakkar", "Ariana Grande",
    "Bruno Mars", "Anirudh Ravichander", "Eminem", "KK",
    "Imagine Dragons", "Atif Aslam", "Lana Del Rey", "Sonu Nigam",
    "Coldplay", "AP Dhillon", "Shawn Mendes", "Darshan Raval",
    "Udit Narayan", "Alka Yagnik", "Kishore Kumar", "Kumar Sanu",
    "Harry Styles", "Olivia Rodrigo", "Sid Sriram", "Anuv Jain",
    "Doja Cat", "Rihanna", "Beyonce", "Kanye West", "J. Cole",
    "SZA", "Future", "21 Savage", "The Chainsmokers", "Marshmello",
    "Akon", "Pitbull", "Armaan Malik", "Jubin Nautiyal", "B Praak"
  ];

  // State for Sound Check
  Duration _sliderPosition = const Duration(seconds: 30);
  final Duration _sliderDuration = const Duration(seconds: 120);
  
  // State for Name Input
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _wiggleAnimation = Tween<double>(begin: -0.015, end: 0.015).animate(
      CurvedAnimation(parent: _wiggleController, curve: Curves.easeInOut)
    );
    // Auto-wiggle effect
    _wiggleController.repeat(reverse: true);
  }

  void _finishOnboarding() async {
    // Save data
    if (_selectedArtists.isNotEmpty) {
      await StorageService.setFavoriteArtists(_selectedArtists);
    }
    if (_nameController.text.trim().isNotEmpty) {
      ref.read(profileProvider.notifier).updateProfile(name: _nameController.text.trim(), avatar: '');
    }

    if (!mounted) return;

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
  
  void _wigglySkip() async {
    if (_isSkipping) return;
    setState(() {
      _isSkipping = true;
    });
    
    // Rapidly scroll through remaining pages
    for (int i = _currentIndex + 1; i <= 4; i++) {
      await _pageController.animateToPage(
        i,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeIn,
      );
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    _finishOnboarding();
  }

  void _playPreviewSong() async {
    final engine = locator<AudioEngineService>();
    if (engine.isPlaying) return;

    final api = locator<MusicApiService>();
    final targetArtist = _selectedArtists.isNotEmpty ? _selectedArtists.first : "Arijit Singh";
    try {
      final songs = await api.searchSongs(targetArtist, count: 5);
      if (songs.isNotEmpty) {
        if (!mounted) return;
        ref.read(audioPlayerProvider.notifier).playSong(songs.first);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pageController.dispose();
    _wiggleController.dispose();
    _nameController.dispose();
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
                      _getGradientColor().withValues(alpha: 0.15),
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
                        if (_currentIndex < 4)
                          GestureDetector(
                            onTap: _wigglySkip,
                            child: RotationTransition(
                              turns: _wiggleAnimation,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: context.themeCardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: context.themeTextColor24),
                                ),
                                child: Text(
                                  "Skip",
                                  style: TextStyle(
                                    color: context.themeTextColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
                      physics: _isSkipping ? const NeverScrollableScrollPhysics() : null,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                        
                        // When leaving artist picker, cache them and preload home feed
                        if (index >= 2 && _selectedArtists.isNotEmpty) {
                          StorageService.setFavoriteArtists(_selectedArtists).then((_) {
                            ref.read(homeProvider.notifier).fetchYouSongs(_selectedArtists);
                          });
                        }
                        
                        // When hitting Sound Check, play a song
                        if (index == 3) {
                          _playPreviewSong();
                        } else {
                          // Pause if they leave the sound check page early
                          final engine = locator<AudioEngineService>();
                          if (engine.isPlaying) engine.pause();
                        }
                      },
                      children: [
                        _buildWelcomeSlide(),
                        _buildArtistPickerSlide(),
                        _buildThemePreviewSlide(),
                        _buildSoundCheckSlide(),
                        _buildNameInputSlide(),
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
                            5,
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
                          child: _currentIndex == 4
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

  Color _getGradientColor() {
    switch (_currentIndex) {
      case 0: return Colors.pinkAccent;
      case 1: return Colors.amber;
      case 2: return Colors.tealAccent;
      case 3: return Colors.blueAccent;
      case 4: return Colors.deepPurpleAccent;
      default: return Colors.transparent;
    }
  }

  Widget _buildWelcomeSlide() {
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
              Icons.favorite_rounded,
              size: 80,
              color: Colors.pinkAccent,
            ),
          ),
          const SizedBox(height: 48),
          Text(
            "Welcome to the Family",
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
            "Hope you feel \"IT Feels\" Magic <3 <3 <3",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: context.themeMutedTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistPickerSlide() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Pick Your Favorites",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: context.themeTextColor,
              shadows: context.themeTextShadow,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Just 3 artists are enough, but the more you tell us, the better your 'For You' feed gets!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: context.themeMutedTextColor,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: _popularArtists.take(_visibleArtistCount).map((artist) {
                  final isSelected = _selectedArtists.contains(artist);
                  return ChoiceChip(
                    label: Text(artist),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedArtists.add(artist);
                          if (_selectedArtists.length == 3) {
                             _visibleArtistCount += 20;
                          }
                        } else {
                          _selectedArtists.remove(artist);
                        }
                      });
                    },
                    selectedColor: Colors.amber.withValues(alpha: 0.2),
                    backgroundColor: context.themeCardColor,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.amber : context.themeTextColor,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? Colors.amber : Colors.transparent,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
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
              color: Colors.tealAccent.withValues(alpha: 0.1),
              border: Border.all(
                color: Colors.tealAccent.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.format_paint_rounded,
              size: 80,
              color: Colors.tealAccent,
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
          GestureDetector(
            onTap: () {
              ref.read(audioPlayerProvider.notifier).setAppThemeMode(
                isGlass ? AppThemeMode.midnight : AppThemeMode.glass,
              );
            },
            child: Container(
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
                IgnorePointer(
                  child: Switch(
                    value: isGlass,
                    onChanged: (value) {},
                    activeColor: Colors.tealAccent, // Deprecated, but keeping for compatibility
                  ),
                ),
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildSoundCheckSlide() {
    final currentSong = ref.watch(audioPlayerProvider).currentSong;
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
            currentSong?.title ?? "Feel the Music",
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
            currentSong != null 
                ? "Now playing: ${currentSong.artist}\nDrag the squiggly slider below to test the haptics, then proceed further."
                : "Drag the squiggly slider below to test the haptics, then proceed further.",
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
  
  Widget _buildNameInputSlide() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.deepPurpleAccent.withValues(alpha: 0.1),
              border: Border.all(
                color: Colors.deepPurpleAccent.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 80,
              color: Colors.deepPurpleAccent,
            ),
          ),
          const SizedBox(height: 48),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: "What should we call you?".length),
            duration: const Duration(seconds: 2),
            builder: (context, value, child) {
              return Text(
                "What should we call you?".substring(0, value),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: context.themeTextColor,
                  shadows: context.themeTextShadow,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            "(Optional) Your name helps us Greet you everyday.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: context.themeMutedTextColor,
            ),
          ),
          const SizedBox(height: 32),
          ExcludeSemantics(
            child: AnimatedBuilder(
              animation: _wiggleController,
              builder: (context, child) {
                // Wiggle goes from -0.015 to +0.015, we'll map it to 0.0 -> 1.0 for glow
                final glowValue = (_wiggleController.value + 0.015) / 0.03;
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurpleAccent.withValues(alpha: 0.2 + (0.4 * glowValue)),
                        blurRadius: 8 + (12 * glowValue),
                        spreadRadius: 2 * glowValue,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: TextField(
                controller: _nameController,
                style: TextStyle(color: context.themeTextColor, fontSize: 18),
                decoration: InputDecoration(
                  hintText: "Enter your name...",
                  hintStyle: TextStyle(color: context.themeMutedTextColor),
                  filled: true,
                  fillColor: context.themeCardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.deepPurpleAccent, width: 2),
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
