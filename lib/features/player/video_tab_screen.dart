import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/widgets/clever_loading_text.dart';
import 'package:go_router/go_router.dart';
import 'package:it_feels_music/services/backend_api_service.dart';
import 'package:it_feels_music/services/storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

class VideoTabScreen extends ConsumerStatefulWidget {
  const VideoTabScreen({super.key});

  @override
  ConsumerState<VideoTabScreen> createState() => _VideoTabScreenState();
}

class _VideoTabScreenState extends ConsumerState<VideoTabScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  bool _isSearching = false;
  List<Map<String, dynamic>> _trendingVideos = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _offlineVideos = [];
  final ScrollController _scrollController = ScrollController();
  int _selectedCategoryIndex = 0; // 0: Trending, 1: Search, 2: Downloads

  final List<Map<String, String>> _allCategories = [
    {"label": "💻 Tech", "query": "Technology reviews"},
    {"label": "🎮 Gaming", "query": "Gaming let's play"},
    {"label": "🎵 Music", "query": "Music videos"},
    {"label": "🎙️ Podcasts", "query": "Podcasts"},
    {"label": "🍿 Movies", "query": "Movie recaps"},
    {"label": "⚽ Sports", "query": "Sports highlights"},
    {"label": "😂 Comedy", "query": "Standup comedy"},
    {"label": "🍳 Cooking", "query": "Cooking recipes"},
    {"label": "✈️ Travel", "query": "Travel vlogs"},
    {"label": "💪 Fitness", "query": "Workout routines"},
    {"label": "📚 Education", "query": "Educational documentaries"},
    {"label": "🚗 Cars", "query": "Car reviews"},
  ];
  List<Map<String, String>> _dynamicCategories = [];

  @override
  void initState() {
    super.initState();
    _allCategories.shuffle();
    _dynamicCategories = _allCategories.take(6).toList();
    _loadTrendingAndOffline();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isSearching) {
        // Here we would implement fetching the next page.
        // For now, since the API lacks pagination tokens, this is a placeholder.
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTrendingAndOffline() async {
    setState(() => _isLoading = true);

    try {
      final trending = await BackendApiService.getTrendingVideos();
      final offline = await StorageService.loadDownloadedVideos();

      _trendingVideos = trending;
      _offlineVideos = offline;
    } catch (e) {
      debugPrint('[VideoTabScreen] Error loading videos: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchVideos(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await BackendApiService.searchVideos(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _onCategoryTapped(int index, String? query) {
    setState(() => _selectedCategoryIndex = index);
    if (query != null) {
      _searchController.text = query;
      _searchVideos(query);
    } else if (index == 0) {
      _searchController.clear();
      _loadTrendingAndOffline();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.themeBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.midnightAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.video_library, color: AppColors.midnightAccent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Ad-Free Videos",
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: context.themeTextColor,
                        ),
                      ),
                    ],
                  ),

                  IconButton(
                    icon: Icon(Icons.refresh, color: context.themeMutedTextColor),
                    onPressed: _loadTrendingAndOffline,
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Container(
                decoration: BoxDecoration(
                  color: context.themeCardColor.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.themeMutedTextColor.withValues(alpha: 0.15)),
                ),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (val) {
                    setState(() => _selectedCategoryIndex = 1);
                    _searchVideos(val);
                  },
                  style: GoogleFonts.inter(color: context.themeTextColor),
                  decoration: InputDecoration(
                    hintText: "Search YouTube ad-free videos...",
                    hintStyle: GoogleFonts.inter(color: context.themeMutedTextColor),
                    prefixIcon: Icon(Icons.search, color: context.themeMutedTextColor),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: context.themeMutedTextColor),
                            onPressed: () {
                              _searchController.clear();
                              _searchVideos('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Category Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildCategoryPill(0, "🔥 Trending", query: null),
                  const SizedBox(width: 8),
                  _buildCategoryPill(1, "🔍 Search", query: null),
                  const SizedBox(width: 8),
                  _buildCategoryPill(2, "📥 Offline", query: null),
                  ..._dynamicCategories.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: _buildCategoryPill(entry.key + 3, entry.value["label"]!, query: entry.value["query"]),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Main Content Area
            Expanded(
              child: _isLoading || _isSearching
                  ? const Center(child: CleverLoadingText())
                  : _selectedCategoryIndex == 2
                      ? _buildOfflineVideosList()
                      : (_selectedCategoryIndex == 1 || _selectedCategoryIndex >= 3)
                          ? _buildVideoGrid(_searchResults, emptyMessage: "No video search results found")
                          : _buildVideoGrid(_trendingVideos, emptyMessage: "No trending videos available"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPill(int index, String label, {String? query}) {
    final isSelected = _selectedCategoryIndex == index;
    return GestureDetector(
      onTap: () => _onCategoryTapped(index, query),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? context.themeAccentColor : context.themeCardColor.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? context.themeInvertedTextColor : context.themeMutedTextColor,
          ),
        ),
      ),
    );
  }

  Widget _buildVideoGrid(List<Map<String, dynamic>> videos, {required String emptyMessage}) {
    if (videos.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: GoogleFonts.inter(color: context.themeMutedTextColor),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 900) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 2;
        }

        return ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.only(left: 20, right: 20, bottom: 160 + MediaQuery.of(context).viewPadding.bottom),
          itemCount: (videos.length / crossAxisCount).ceil(),
          itemBuilder: (context, rowIndex) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(crossAxisCount, (colIndex) {
                final index = rowIndex * crossAxisCount + colIndex;
                if (index >= videos.length) {
                  return const Expanded(child: SizedBox());
                }

                final video = videos[index];
                final videoId = video['id']?.toString() ?? '';
                final title = video['title']?.toString() ?? 'Video';
                final uploader = video['uploader']?.toString() ?? 'YouTube Creator';
                final thumbnail = video['thumbnail']?.toString() ?? '';
                final views = video['views']?.toString() ?? '';

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: 16,
                      right: colIndex < crossAxisCount - 1 ? 16 : 0,
                    ),
                    child: Material(
                      color: context.themeCardColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                ref.read(videoPlayerProvider.notifier).playVideo(videoId, title, uploader);
                context.push('/video_player');
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Video Thumbnail Banner
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: thumbnail.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: thumbnail,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => Container(color: Colors.black26),
                                )
                              : Container(color: Colors.black26),
                        ),

                        // Center Play Glassmorphism Icon
                        Positioned.fill(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white30),
                              ),
                              child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                            ),
                          ),
                        ),

                        // Views Pill Badge
                        if (views.isNotEmpty)
                          Positioned(
                            bottom: 10,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                views,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Video Details Footer
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.midnightAccent.withValues(alpha: 0.2),
                          radius: 18,
                          child: const Icon(Icons.video_library, color: AppColors.midnightAccent, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: context.themeTextColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                uploader,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: context.themeMutedTextColor,
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
          ),
        ),
      );
              }),
            );
          },
        );
      },
    );
  }

  Widget _buildOfflineVideosList() {
    if (_offlineVideos.isEmpty) {
      return Center(
        child: Text(
          "No offline downloaded videos yet",
          style: GoogleFonts.inter(color: context.themeMutedTextColor),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 900) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 2;
        }

        return ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.only(left: 20, right: 20, bottom: 160 + MediaQuery.of(context).viewPadding.bottom),
          itemCount: (_offlineVideos.length / crossAxisCount).ceil(),
          itemBuilder: (context, rowIndex) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(crossAxisCount, (colIndex) {
                final index = rowIndex * crossAxisCount + colIndex;
                if (index >= _offlineVideos.length) {
                  return const Expanded(child: SizedBox());
                }

                final video = _offlineVideos[index];
                final videoId = video['id']?.toString() ?? '';
                final title = video['title']?.toString() ?? 'Downloaded Video';
                final uploader = video['uploader']?.toString() ?? 'Offline Video';
                final localPath = video['localPath']?.toString() ?? '';

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: 12,
                      right: colIndex < crossAxisCount - 1 ? 16 : 0,
                    ),
                    child: Material(
                      color: context.themeCardColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.midnightAccent.withValues(alpha: 0.2),
                child: const Icon(Icons.download_done, color: AppColors.midnightAccent),
              ),
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: context.themeTextColor),
              ),
              subtitle: Text(
                "$uploader • Offline MP4",
                style: GoogleFonts.inter(fontSize: 12, color: context.themeMutedTextColor),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () async {
                  if (localPath.isNotEmpty && File(localPath).existsSync()) {
                    File(localPath).deleteSync();
                  }
                  await StorageService.deleteDownloadedVideo(videoId);
                  _loadTrendingAndOffline();
                },
              ),
              onTap: () {
                if (localPath.isNotEmpty && File(localPath).existsSync()) {
                  ref.read(videoPlayerProvider.notifier).playVideo(
                        videoId,
                        title,
                        uploader,
                        localPath: localPath,
                      );
                  context.push('/video_player');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Video file not found. It may have been deleted.')),
                  );
                }
              },
            ),
          ),
        ),
      );
              }),
            );
          },
        );
      },
    );
  }
}
