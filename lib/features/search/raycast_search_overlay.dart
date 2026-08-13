import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:window_manager/window_manager.dart';

class RaycastSearchOverlay extends ConsumerStatefulWidget {
  const RaycastSearchOverlay({super.key});

  @override
  ConsumerState<RaycastSearchOverlay> createState() => _RaycastSearchOverlayState();
}

class _RaycastSearchOverlayState extends ConsumerState<RaycastSearchOverlay> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      // Ensure the window is on top when summoned
      if (Platform.isWindows) {
        windowManager.setAlwaysOnTop(true);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    if (Platform.isWindows) {
      windowManager.setAlwaysOnTop(false);
    }
    super.dispose();
  }

  void _playSong(Song song) async {
    ref.read(audioPlayerProvider.notifier).playSong(song);
    
    // Close the overlay
    if (context.mounted) {
      context.pop();
    }
    
    // Minimize the window back to tray/background if desired
    if (Platform.isWindows) {
      await windowManager.minimize();
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (context.mounted) context.pop();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          final results = ref.read(searchProvider).songs;
          if (_selectedIndex < results.length - 1) {
            _selectedIndex++;
          }
        });
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          if (_selectedIndex > 0) {
            _selectedIndex--;
          }
        });
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        final results = ref.read(searchProvider).songs;
        if (results.isNotEmpty && _selectedIndex < results.length) {
          _playSong(results[_selectedIndex]);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final songs = searchState.songs;

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.transparent, // Fully transparent scaffold
        body: Stack(
          children: [
            // Click outside to dismiss
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                color: Colors.black.withValues(alpha: 0.6), // Dim the main window
              ),
            ),
            
            // Centered Search Box
            Center(
              child: Container(
                width: 700,
                constraints: const BoxConstraints(maxHeight: 500),
                decoration: BoxDecoration(
                  color: context.themeSurfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                  border: Border.all(
                    color: context.themeTextColor.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search Input
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        style: TextStyle(
                          color: context.themeTextColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: "Search for a song...",
                          hintStyle: TextStyle(
                            color: context.themeMutedTextColor,
                            fontSize: 24,
                          ),
                          prefixIcon: Icon(Icons.search, color: context.themeMutedTextColor, size: 28),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (val) {
                          setState(() => _selectedIndex = 0);
                          ref.read(searchProvider.notifier).search(val);
                        },
                      ),
                    ),
                    
                    // Divider
                    if (songs.isNotEmpty || searchState.isSearching)
                      Divider(color: context.themeTextColor.withValues(alpha: 0.1), height: 1),
                    
                    // Results List
                    if (searchState.isSearching)
                      const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (songs.isNotEmpty)
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: songs.length > 5 ? 5 : songs.length, // Show top 5 results
                          itemBuilder: (context, index) {
                            final song = songs[index];
                            final isSelected = index == _selectedIndex;
                            
                            return Container(
                              color: isSelected ? context.themeAccentColor.withValues(alpha: 0.15) : Colors.transparent,
                              child: ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CustomImageWidget(
                                    imageUrl: song.coverArt,
                                    width: 48,
                                    height: 48,
                                  ),
                                ),
                                title: Text(
                                  song.title,
                                  style: TextStyle(
                                    color: context.themeTextColor,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  song.artist,
                                  style: TextStyle(
                                    color: context.themeMutedTextColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: isSelected
                                    ? Icon(Icons.keyboard_return, color: context.themeAccentColor, size: 20)
                                    : null,
                                onTap: () => _playSong(song),
                              ),
                            );
                          },
                        ),
                      ),
                      
                    // Footer
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.themeBackgroundColor,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            "Press Enter to play • Esc to dismiss",
                            style: TextStyle(
                              color: context.themeMutedTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
