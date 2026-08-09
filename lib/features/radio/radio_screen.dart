import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/radio_api_service.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

class RadioScreen extends ConsumerStatefulWidget {
  const RadioScreen({super.key});

  @override
  ConsumerState<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends ConsumerState<RadioScreen> {
  final RadioApiService _radioService = locator<RadioApiService>();
  final TextEditingController _searchController = TextEditingController();
  
  List<Song> _stations = [];
  bool _isLoading = true;
  String _currentQuery = '';

  final Map<String, String> _quickFilters = {
    'ðŸ”¥ Top': '',
    'ðŸ‡®ðŸ‡³ India': 'India',
    'ðŸ‡ºðŸ‡¸ USA': 'United States',
    'ðŸ‡¬ðŸ‡§ UK': 'United Kingdom',
    'ðŸ‡¯ðŸ‡µ Japan': 'Japan',
    'ðŸŽ· Jazz': 'Jazz',
    'ðŸ“° News': 'News',
    'ðŸŽ¸ Rock': 'Rock',
    'ðŸŽ§ Lofi': 'Lofi',
  };

  @override
  void initState() {
    super.initState();
    _loadTopStations();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTopStations() async {
    setState(() => _isLoading = true);
    final stations = await _radioService.getTopStations();
    if (mounted) {
      setState(() {
        _stations = stations;
        _isLoading = false;
      });
    }
  }

  Future<void> _searchStations(String query) async {
    if (query.isEmpty) {
      _loadTopStations();
      return;
    }
    setState(() {
      _isLoading = true;
      _currentQuery = query;
    });
    final stations = await _radioService.searchStations(query);
    if (mounted && _currentQuery == query) {
      setState(() {
        _stations = stations;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.themeBackgroundColor,
      appBar: AppBar(
        flexibleSpace: kIsWeb ? null : (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux ? null : const DragToMoveArea(child: SizedBox.expand())),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.themeTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Global Radio",
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: context.themeTextColor,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (val == _searchController.text) {
                    _searchStations(val);
                  }
                });
              },
              style: TextStyle(color: context.themeTextColor),
              decoration: InputDecoration(
                hintText: 'Search worldwide stations...',
                hintStyle: TextStyle(color: context.themeMutedTextColor),
                prefixIcon: Icon(Icons.search, color: context.themeMutedTextColor),
                filled: true,
                fillColor: context.themeSurfaceColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: _quickFilters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final entry = _quickFilters.entries.elementAt(index);
                final isSelected = entry.value.isEmpty ? _currentQuery.isEmpty : _currentQuery.toLowerCase() == entry.value.toLowerCase();
                
                return ActionChip(
                  backgroundColor: isSelected ? context.themeAccentColor : context.themeSurfaceColor,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  label: Text(
                    entry.key,
                    style: GoogleFonts.inter(
                      color: isSelected ? Colors.black : context.themeTextColor,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    if (entry.value.isEmpty) {
                      _searchController.clear();
                      _loadTopStations();
                    } else {
                      _searchController.text = entry.value;
                      _searchStations(entry.value);
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator(color: context.themeAccentColor))
              : _stations.isEmpty
                ? Center(
                    child: Text(
                      "No stations found.",
                      style: GoogleFonts.inter(color: context.themeMutedTextColor),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewPadding.bottom + 120,
                      top: 12,
                    ),
                    itemCount: _stations.length,
                    itemBuilder: (context, index) {
                      final station = _stations[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: station.coverArt,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              width: 56,
                              height: 56,
                              color: context.themeSurfaceColor,
                              child: Icon(Icons.radio, color: context.themeMutedTextColor),
                            ),
                          ),
                        ),
                        title: Text(
                          station.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: context.themeTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          station.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: context.themeMutedTextColor,
                            fontSize: 13,
                          ),
                        ),
                        trailing: Icon(Icons.play_circle_fill_rounded, color: context.themeAccentColor, size: 32),
                        onTap: () {
                          // Play the station directly using the encryptedMediaUrl (which holds the resolved URL)
                          ref.read(audioPlayerProvider.notifier).playSong(station, predefinedStreamUrl: station.encryptedMediaUrl);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Tuning into \${station.title}...'),
                              backgroundColor: context.themeAccentColor,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


