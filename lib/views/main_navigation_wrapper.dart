import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../core/theme/app_colors.dart';
import '../providers/audio_player_provider.dart';
import '../providers/listening_history_provider.dart';
import '../providers/custom_playlist_provider.dart';
import '../data/models/song_model.dart';
import '../data/services/music_api_service.dart';
import '../services/playlist_import_service.dart';
import '../providers/settings_provider.dart';
import 'video/video_tab_screen.dart';
import 'home/home_screen.dart';
import 'library/library_screen.dart';
import 'player/now_playing_screen.dart';
import 'search/search_screen.dart';
import 'widgets/mini_player.dart';
import 'widgets/import_progress_banner.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> with WidgetsBindingObserver {
  int _currentTab = 0;
  Song? _lastLoggedSong;
  late StreamSubscription _intentSubscription;
  String _lastCheckedClipboard = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Listen to media sharing incoming links while app is in memory
    _intentSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) {
        _handleSharedText(value.first.path);
      }
    }, onError: (err) {
      debugPrint("Intent error: $err");
    });

    // Check for sharing intent when app is opened from closed state
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        _handleSharedText(value.first.path);
      }
      ReceiveSharingIntent.instance.reset();
    });

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
      
      // Check clipboard on startup
      _checkClipboardForPlaylist();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _intentSubscription.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboardForPlaylist();
    }
  }

  Future<void> _checkClipboardForPlaylist() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text?.trim() ?? '';
    
    if (text.isNotEmpty && text != _lastCheckedClipboard) {
      _lastCheckedClipboard = text;
      _handleSharedText(text);
    }
  }

  void _handleSharedText(String text) {
    if (text.contains('open.spotify.com/playlist/')) {
      // Extract URL from possible text like "Check out this playlist: https://..."
      final RegExp urlRegExp = RegExp(r'(https?://[^\s]+)');
      final match = urlRegExp.firstMatch(text);
      if (match != null) {
        final url = match.group(0)!;
        _promptImport(url);
      }
    }
  }

  void _promptImport(String url) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.themeSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.playlist_add, size: 48, color: AppColors.midnightAccent),
              const SizedBox(height: 16),
              Text(
                'Import Playlist?',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: context.themeTextColor),
              ),
              const SizedBox(height: 8),
              Text(
                'We detected a Spotify playlist link. Would you like to import it to IT-Feels?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: context.themeMutedTextColor),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: GoogleFonts.inter(color: context.themeMutedTextColor)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.midnightAccent,
                        foregroundColor: context.themeBackgroundColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        PlaylistImportService().startBackgroundImport(
                          url, 
                          Provider.of<CustomPlaylistProvider>(context, listen: false), 
                          MusicApiService()
                        );
                      },
                      child: Text('Import Now', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
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
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final enableVideos = settingsProvider.enableMusicVideos;

    final List<Widget> screens = [
      HomeScreen(openFullPlayer: _openFullPlayer),
      const SearchScreen(),
      const LibraryScreen(),
      if (enableVideos) const VideoTabScreen(),
    ];

    return Scaffold(
      backgroundColor: context.themeBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth >= 600;

          if (isWideScreen) {
            return Row(
              children: [
                // Floating Side Navigation Pill for Wide Screens
                SafeArea(
                  right: false,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        width: 96,
                        margin: const EdgeInsets.only(left: 12, top: 12, bottom: 12),
                        decoration: BoxDecoration(
                          color: context.themeSurfaceColor.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: context.themeInvertedTextColor.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(8, 0),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildNavItem(0, Icons.home_rounded, "Home", isVertical: true),
                            const SizedBox(height: 24),
                            _buildNavItem(1, Icons.search_rounded, "Search", isVertical: true),
                            const SizedBox(height: 24),
                            _buildNavItem(2, Icons.library_music_rounded, "Library", isVertical: true),
                            if (enableVideos) ...[
                              const SizedBox(height: 24),
                              _buildNavItem(3, Icons.video_library_rounded, "Videos", isVertical: true),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Main Content
                Expanded(
                  child: Stack(
                    children: [
                      // Indexed Active Screen
                      IndexedStack(
                        index: _currentTab < screens.length ? _currentTab : 0,
                        children: screens,
                      ),
                      // Floating MiniPlayer Overlay
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: SafeArea(
                          bottom: true,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Import Progress Banner
                              const ImportProgressBanner(),
                              // Mini Player Pill
                              MiniPlayer(onTap: _openFullPlayer),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          // Mobile View
          return Stack(
            children: [
              // Indexed Active Screen
              IndexedStack(
                index: _currentTab < screens.length ? _currentTab : 0,
                children: screens,
              ),

              // Floating MiniPlayer + Bottom Navigation Bar Overlay
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  bottom: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Import Progress Banner
                      const ImportProgressBanner(),
                      
                      // Mini Player Pill
                      MiniPlayer(onTap: _openFullPlayer),
      
                      // Floating Bottom Navigation Bar Pill Container
                      ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            height: 76,
                            margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                            decoration: BoxDecoration(
                              color: context.themeSurfaceColor.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: context.themeInvertedTextColor.withValues(alpha: 0.4),
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
                                if (enableVideos) _buildNavItem(3, Icons.video_library_rounded, "Videos"),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {bool isVertical = false}) {
    final isSelected = _currentTab == index;
    return Consumer<AudioPlayerProvider>(
      builder: (context, playerProvider, child) {
        final content = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              _currentTab = index;
            });
          },
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: EdgeInsets.symmetric(
                horizontal: isVertical ? 12 : 20,
                vertical: isVertical ? 16 : 16,
              ),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.midnightPill : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: isVertical
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          color: isSelected ? AppColors.midnightAccent : context.themeMutedTextColor,
                          size: 32,
                        ),
                        if (isSelected) ...[
                          const SizedBox(height: 6),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: context.themeTextColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          color: isSelected ? AppColors.midnightAccent : context.themeMutedTextColor,
                          size: 32,
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: context.themeTextColor,
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
        );
        return isVertical ? content : Expanded(child: content);
      },
    );
  }
}
