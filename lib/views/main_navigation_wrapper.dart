import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/audio_player_provider.dart';
import '../providers/listening_history_provider.dart';
import '../data/models/song_model.dart';
import 'home/home_screen.dart';
import 'library/library_screen.dart';
import 'player/now_playing_screen.dart';
import 'search/search_screen.dart';
import 'widgets/mini_player.dart';

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentTab = 0;
  Song? _lastLoggedSong;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = Provider.of<AudioPlayerProvider>(context, listen: false);
      final history = Provider.of<ListeningHistoryProvider>(context, listen: false);
      
      player.addListener(() {
        final currentSong = player.currentSong;
        if (currentSong != null && currentSong.id != _lastLoggedSong?.id) {
          _lastLoggedSong = currentSong;
          history.logSong(currentSong);
        }
      });
    });
  }

  void _openFullPlayer() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const NowPlayingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(openFullPlayer: _openFullPlayer),
      const SearchScreen(),
      const LibraryScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.midnightBackground,
      body: Stack(
        children: [
          // Indexed Active Screen
          IndexedStack(
            index: _currentTab,
            children: screens,
          ),

          // Floating MiniPlayer + Bottom Navigation Bar Overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mini Player Pill
                MiniPlayer(onTap: _openFullPlayer),

                // Floating Bottom Navigation Bar Pill Container
                Container(
                  height: 64,
                  margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.midnightSurface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentTab == index;
    return Consumer<AudioPlayerProvider>(
      builder: (context, playerProvider, child) {
        return Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _currentTab = index;
              });
            },
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.midnightPill : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: isSelected ? AppColors.midnightAccent : Colors.white60,
                      size: 26,
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white,
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
          ),
        );
      },
    );
  }
}
