import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/settings/settings_screen.dart';
import '../theme/new_experience_tokens.dart';
import '../home/new_home_screen.dart';
import '../search/new_search_screen.dart';
import '../library/new_library_screen.dart';
import '../hits/new_hits_screen.dart';
import '../ai/new_ai_discovery_screen.dart';
import '../import/new_spotify_import_screen.dart';
import '../player/new_mini_player.dart';
import '../player/new_now_playing_screen.dart';
import 'new_desktop_sidebar.dart';
import 'new_desktop_player_bar.dart';
import 'new_contextual_panel.dart';
import 'new_mobile_nav_dock.dart';

class NewExperienceShell extends ConsumerStatefulWidget {
  const NewExperienceShell({super.key});

  @override
  ConsumerState<NewExperienceShell> createState() => _NewExperienceShellState();
}

class _NewExperienceShellState extends ConsumerState<NewExperienceShell> {
  int _currentIndex = 0;
  bool _isSidebarCollapsed = false;
  bool _isContextualPanelOpen = false;
  ContextualPanelTab _contextualTab = ContextualPanelTab.lyrics;

  void _onSelectTab(int index) {
    setState(() => _currentIndex = index);
  }

  void _openNowPlaying() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const NewNowPlayingScreen(),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= NewExperienceTokens.breakpointMedium;
        final isMobile = constraints.maxWidth < NewExperienceTokens.breakpointCompact;

        if (isDesktop) {
          return _buildDesktopLayout();
        }

        if (isMobile) {
          return _buildMobilePortraitLayout();
        }

        // Tablet / Mobile Landscape layout
        return _buildTabletLandscapeLayout();
      },
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: NewExperienceTokens.obsidianBackground,
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // Collapsible Sidebar
                NewDesktopSidebar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _onSelectTab,
                  isCollapsed: _isSidebarCollapsed,
                  onToggleCollapse: () =>
                      setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                ),

                // Main Viewport
                Expanded(
                  child: ClipRect(
                    child: _buildCurrentScreen(),
                  ),
                ),

                // Optional Contextual Panel (Lyrics / Queue)
                if (_isContextualPanelOpen)
                  NewContextualPanel(
                    initialTab: _contextualTab,
                    onClose: () => setState(() => _isContextualPanelOpen = false),
                  ),
              ],
            ),
          ),

          // Persistent Playback Bar
          NewDesktopPlayerBar(
            isLyricsActive: _isContextualPanelOpen && _contextualTab == ContextualPanelTab.lyrics,
            isQueueActive: _isContextualPanelOpen && _contextualTab == ContextualPanelTab.queue,
            onToggleLyrics: () {
              setState(() {
                if (_isContextualPanelOpen && _contextualTab == ContextualPanelTab.lyrics) {
                  _isContextualPanelOpen = false;
                } else {
                  _isContextualPanelOpen = true;
                  _contextualTab = ContextualPanelTab.lyrics;
                }
              });
            },
            onToggleQueue: () {
              setState(() {
                if (_isContextualPanelOpen && _contextualTab == ContextualPanelTab.queue) {
                  _isContextualPanelOpen = false;
                } else {
                  _isContextualPanelOpen = true;
                  _contextualTab = ContextualPanelTab.queue;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLandscapeLayout() {
    return Scaffold(
      backgroundColor: NewExperienceTokens.obsidianBackground,
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                NewDesktopSidebar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _onSelectTab,
                  isCollapsed: true, // Always collapsed on tablet for maximum screen space
                  onToggleCollapse: () {},
                ),
                Expanded(child: _buildCurrentScreen()),
              ],
            ),
          ),
          const NewDesktopPlayerBar(),
        ],
      ),
    );
  }

  Widget _buildMobilePortraitLayout() {
    final playerState = ref.watch(audioPlayerProvider);
    final hasSong = playerState.currentSong != null;

    return Scaffold(
      backgroundColor: NewExperienceTokens.obsidianBackground,
      body: Stack(
        children: [
          // Active Screen
          Positioned.fill(
            child: _buildCurrentScreen(),
          ),

          // Floating MiniPlayer + Dock
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              bottom: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasSong)
                    NewMiniPlayer(
                      onTap: _openNowPlaying,
                    ),
                  NewMobileNavDock(
                    selectedIndex: _currentIndex.clamp(0, 4),
                    onDestinationSelected: (idx) {
                      if (idx == 4) {
                        _onSelectTab(6); // Map dock settings to settings screen
                      } else {
                        _onSelectTab(idx);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return NewHomeScreen(onOpenFullPlayer: _openNowPlaying);
      case 1:
        return const NewSearchScreen();
      case 2:
        return const NewLibraryScreen();
      case 3:
        return const NewHitsScreen();
      case 4:
        return const NewAIDiscoveryScreen();
      case 5:
        return const NewSpotifyImportScreen();
      case 6:
      default:
        return const SettingsScreen();
    }
  }
}
