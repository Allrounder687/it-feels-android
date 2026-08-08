import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/core/widgets/skeleton_loading_list.dart';
import 'package:go_router/go_router.dart';
import 'package:it_feels_music/features/library/artist_detail_screen.dart';
import 'package:it_feels_music/features/library/playlist_detail_screen.dart';
import 'package:it_feels_music/data/models/song_model.dart';


import 'package:it_feels_music/core/widgets/song_options_sheet.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/theme/app_dimensions.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  const SearchScreen({super.key, this.initialQuery});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _selectedCategoryIndex = 0;
  final List<String> _categories = ["ALL", "SONGS", "ARTISTS", "ALBUMS", "PLAYLISTS"];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(searchProvider.notifier).search(widget.initialQuery!);
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(searchProvider.notifier).loadMore(_selectedCategoryIndex);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final searchProviderObj = ref.watch(searchProvider);
        final hiddenProviderObj = ref.watch(hiddenSongsProvider);
        final settingsProviderObj = ref.watch(settingsProvider);
        final categories = ["ALL", "SONGS", "ARTISTS", "ALBUMS", "PLAYLISTS", "VIDEOS", "PODCASTS"];

        final songs = searchProviderObj.songs.where((s) => !hiddenProviderObj.isHidden(s.id)).toList();
        final albums = searchProviderObj.albums;
        final playlists = searchProviderObj.playlists;
        final videos = searchProviderObj.videos;
        final podcasts = searchProviderObj.podcasts;

        bool hasNoResults = _searchController.text.isNotEmpty &&
            !searchProviderObj.isSearching &&
            songs.isEmpty &&
            albums.isEmpty &&
            playlists.isEmpty &&
            searchProviderObj.artists.isEmpty &&
            videos.isEmpty &&
            podcasts.isEmpty;

        return Scaffold(
          backgroundColor: context.themeBackgroundColor,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Search Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Search",
                        style: GoogleFonts.outfit(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: context.themeTextColor,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Search Input Pill
                      Container(
                        decoration: BoxDecoration(
                          color: context.themeUnselectedPillColor,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: GoogleFonts.inter(color: context.themeUnselectedPillTextColor),
                          decoration: InputDecoration(
                            hintText: "Search songs, artists, albums, playlists...",
                            hintStyle: GoogleFonts.inter(color: context.themeMutedTextColor),
                            prefixIcon: Icon(Icons.search, color: context.themeMutedTextColor),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, color: context.themeMutedTextColor),
                                    onPressed: () {
                                      _searchController.clear();
                                      ref.read(searchProvider.notifier).search('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onChanged: (val) => ref.read(searchProvider.notifier).search(val),
                        ),
                      ),
                    ],
                  ),
                ),

                // Category Filter Pills (ALL, SONGS, ARTISTS, ALBUMS, PLAYLISTS)
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final isSelected = index == _selectedCategoryIndex;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategoryIndex = index;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Text(
                  categories[index],
                  style: GoogleFonts.inter(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Search Results List
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: searchProviderObj.isSearching && songs.isEmpty && albums.isEmpty
                          ? const SkeletonLoadingList()
                          : _searchController.text.isEmpty
                          ? _buildBrowseGrid(context, searchProviderObj.recentSearches)
                          : hasNoResults
                          ? _buildEmptyState(context, _searchController.text)
                          : ListView(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              children: [
                                // Artists Direct Match Section
                                if (_selectedCategoryIndex == 0 || _selectedCategoryIndex == 2) ...[
                                  if (searchProviderObj.artists.isNotEmpty) _buildTopResultCard(context, searchProviderObj.artists.first),
                                  const SizedBox(height: 16),

                                  if (searchProviderObj.artists.length > 1) ...[
                                    Text(
                                      "Artists",
                                      style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: context.themeTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...searchProviderObj.artists.skip(1).map((artist) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Material(
                                      color: context.themeCardColor.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(16),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: context.themeAccentColor,
                                          backgroundImage: artist['image']?.toString().isNotEmpty == true 
                                              ? CachedNetworkImageProvider(artist['image']) 
                                              : null,
                                          child: artist['image']?.toString().isNotEmpty == true 
                                              ? null 
                                              : Icon(Icons.person, color: context.themeInvertedTextColor),
                                        ),
                                        title: Text(
                                          artist['title'] ?? _searchController.text,
                                          style: GoogleFonts.inter(
                                            color: context.themeTextColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        subtitle: Text(
                                          "Explore full artist discography",
                                          style: GoogleFonts.inter(
                                            color: context.themeMutedTextColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                        trailing: Icon(Icons.chevron_right, color: context.themeMutedTextColor),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ArtistDetailScreen(
                                                artistName: artist['title'] ?? _searchController.text,
                                                artistImage: artist['image'],
                                                artistId: artist['id']?.toString(),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  )),
                                    const SizedBox(height: 16),
                                  ],
                                ],

                                // Songs Section
                                if ((_selectedCategoryIndex == 0 || _selectedCategoryIndex == 1) && songs.isNotEmpty) ...[
                                  Text(
                                    "Songs",
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: context.themeTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...songs.map((song) => Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Material(
                                          color: context.themeCardColor.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(16),
                                          child: ListTile(
                                            leading: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: SizedBox(
                                                width: 44,
                                                height: 44,
                                                child: song.coverArt.isNotEmpty
                                                    ? CustomImageWidget(
                                                        imageUrl: song.coverArt,
                                                        fit: BoxFit.cover,
                                                      )
                                                    : Icon(Icons.music_note, color: context.themeTextColor),
                                              ),
                                            ),
                                            title: Text(
                                              song.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                color: context.themeTextColor,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            subtitle: Row(
                                              children: [
                                                _buildProviderBadge(context, song),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    song.artist,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.inter(
                                                      color: context.themeMutedTextColor,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            trailing: IconButton(
                                              icon: Icon(Icons.more_vert, color: context.themeMutedTextColor),
                                              onPressed: () {
                                                SongOptionsSheet.show(context, song, playlistContext: songs);
                                              },
                                            ),
                                            onTap: () {
                                              ref.read(audioPlayerProvider.notifier).playSong(song, queue: songs, index: songs.indexOf(song));
                                            },
                                            onLongPress: () {
                                              SongOptionsSheet.show(context, song, playlistContext: songs);
                                            },
                                          ),
                                        ),
                                      )),
                                  const SizedBox(height: 16),
                                ],

                                // Albums Section
                                if ((_selectedCategoryIndex == 0 || _selectedCategoryIndex == 3) && albums.isNotEmpty) ...[
                                  Text(
                                    "Albums",
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: context.themeTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...albums.map((album) => Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Material(
                                          color: context.themeCardColor.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(16),
                                          child: ListTile(
                                            leading: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: SizedBox(
                                                width: 44,
                                                height: 44,
                                                child: album.coverArt.isNotEmpty
                                                    ? CustomImageWidget(
                                                        imageUrl: album.coverArt,
                                                        fit: BoxFit.cover,
                                                      )
                                                    : Icon(Icons.album, color: context.themeTextColor),
                                              ),
                                            ),
                                            title: Text(
                                              album.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                color: context.themeTextColor,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            subtitle: Text(
                                              "Album",
                                              style: GoogleFonts.inter(
                                                color: context.themeMutedTextColor,
                                                fontSize: 12,
                                              ),
                                            ),
                                            trailing: Icon(Icons.chevron_right, color: context.themeMutedTextColor),
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => PlaylistDetailScreen(playlist: album),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      )),
                                  const SizedBox(height: 16),
                                ],

                                // Playlists Section
                                if ((_selectedCategoryIndex == 0 || _selectedCategoryIndex == 4) && playlists.isNotEmpty) ...[
                                  Text(
                                    "Playlists",
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: context.themeTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...playlists.map((pl) => Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Material(
                                          color: context.themeCardColor.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(16),
                                          child: ListTile(
                                            leading: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: SizedBox(
                                                width: 44,
                                                height: 44,
                                                child: pl.coverArt.isNotEmpty
                                                    ? CustomImageWidget(
                                                        imageUrl: pl.coverArt,
                                                        fit: BoxFit.cover,
                                                      )
                                                    : Icon(Icons.queue_music, color: context.themeTextColor),
                                              ),
                                            ),
                                            title: Text(
                                              pl.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                color: context.themeTextColor,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            subtitle: Text(
                                              "Playlist",
                                              style: GoogleFonts.inter(
                                                color: context.themeMutedTextColor,
                                                fontSize: 12,
                                              ),
                                            ),
                                            trailing: Icon(Icons.chevron_right, color: context.themeMutedTextColor),
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => PlaylistDetailScreen(playlist: pl),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      )),
                                  const SizedBox(height: 16),
                                ],

                                // Videos Section
                                if ((_selectedCategoryIndex == 0 || _selectedCategoryIndex == 5) && videos.isNotEmpty) ...[
                                  Text(
                                    "Videos",
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: context.themeTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      if (constraints.maxWidth > 600) {
                                        return GridView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                            maxCrossAxisExtent: 320,
                                            childAspectRatio: 1.15,
                                            crossAxisSpacing: 16,
                                            mainAxisSpacing: 16,
                                          ),
                                          itemCount: videos.length,
                                          itemBuilder: (context, index) {
                                            return _buildVideoGridCard(context, videos[index]);
                                          },
                                        );
                                      } else {
                                        return Column(
                                          children: videos.map((vid) => Padding(
                                            padding: const EdgeInsets.only(bottom: 6),
                                            child: _buildVideoListTile(context, vid),
                                          )).toList(),
                                        );
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Podcasts Section
                                if ((_selectedCategoryIndex == 0 || _selectedCategoryIndex == 6) && podcasts.isNotEmpty) ...[
                                  Text(
                                    "Podcasts",
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: context.themeTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...podcasts.map((song) => Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Material(
                                          color: context.themeCardColor.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(16),
                                          child: ListTile(
                                            leading: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: SizedBox(
                                                width: 44,
                                                height: 44,
                                                child: song.coverArt.isNotEmpty
                                                    ? CustomImageWidget(
                                                        imageUrl: song.coverArt,
                                                        fit: BoxFit.cover,
                                                      )
                                                    : Icon(Icons.music_note, color: context.themeTextColor),
                                              ),
                                            ),
                                            title: Text(
                                              song.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                color: context.themeTextColor,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            subtitle: Row(
                                              children: [
                                                _buildProviderBadge(context, song),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    song.artist,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.inter(
                                                      color: context.themeMutedTextColor,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            trailing: IconButton(
                                              icon: Icon(Icons.more_vert, color: context.themeMutedTextColor),
                                              onPressed: () {
                                                SongOptionsSheet.show(context, song, playlistContext: podcasts);
                                              },
                                            ),
                                            onTap: () {
                                              ref.read(audioPlayerProvider.notifier).playSong(song, queue: podcasts, index: podcasts.indexOf(song));
                                            },
                                          ),
                                        ),
                                      )),
                                  const SizedBox(height: 16),
                                ],

                                if (searchProviderObj.isLoadingMore)
                                  const Padding(
                                    padding: EdgeInsets.all(20.0),
                                    child: Center(child: CircularProgressIndicator()),
                                  ),

                                SizedBox(height: AppDimensions.bottomClearance + MediaQuery.of(context).viewPadding.bottom),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, String query) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.search_off_rounded, size: 80, color: context.themeMutedTextColor.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        Text(
          "No results found",
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: context.themeTextColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "We couldn't find anything for \"$query\".\nTry searching for something else.",
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: context.themeMutedTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildProviderBadge(BuildContext context, Song song) {
    String label = 'SAAVN';
    Color badgeColor = const Color(0xFF00B0FF); // Cool Saavn Blue

    if (song.album.contains('(IT-Feels)')) {
      label = 'IT-FEELS';
      badgeColor = const Color(0xFF9C27B0); // Deep Purple
    } else if (song.id.startsWith('youtube:')) {
      label = 'YOUTUBE';
      badgeColor = const Color(0xFFFF3D00); // YouTube Red
    } else if (song.id.startsWith('spotify:')) {
      label = 'SPOTIFY';
      badgeColor = const Color(0xFF1DB954); // Spotify Green
    } else if (song.id.startsWith('soundcloud:')) {
      label = 'SOUNDCLOUD';
      badgeColor = const Color(0xFFFF5500); // SoundCloud Orange
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: badgeColor.withValues(alpha: 0.35), width: 0.7),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          color: badgeColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildBrowseGrid(BuildContext context, List<String> recentSearches) {
    final genres = [
      {'title': 'Pop', 'color': const Color(0xFFFF4632)},
      {'title': 'Hip-Hop', 'color': const Color(0xFFBA5D07)},
      {'title': 'Mood', 'color': const Color(0xFF8D67AB)},
      {'title': 'Podcasts', 'color': const Color(0xFF006450)},
      {'title': 'Charts', 'color': const Color(0xFFE1118C)},
      {'title': 'Dance/Electronic', 'color': const Color(0xFFD84000)},
      {'title': 'Indie', 'color': const Color(0xFFE13300)},
      {'title': 'Workout', 'color': const Color(0xFF777777)},
      {'title': 'K-Pop', 'color': const Color(0xFF148A08)},
      {'title': 'Sleep', 'color': const Color(0xFF1E3264)},
    ];

    return CustomScrollView(
      slivers: [
        if (recentSearches.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recent Searches",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.themeTextColor,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(searchProvider.notifier).clearRecentSearches();
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      "Clear",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.themeMutedTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: recentSearches.length,
                itemBuilder: (context, index) {
                  final term = recentSearches[index];
                  return GestureDetector(
                    onTap: () {
                      _searchController.text = term;
                      ref.read(searchProvider.notifier).search(term);
                      FocusScope.of(context).unfocus();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.only(left: 16, right: 8, top: 6, bottom: 6),
                      decoration: BoxDecoration(
                        color: context.themeCardColor.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(color: context.themeTextColor24, width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 14, color: context.themeMutedTextColor),
                          const SizedBox(width: 6),
                          Text(
                            term,
                            style: GoogleFonts.inter(
                              color: context.themeTextColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              ref.read(searchProvider.notifier).removeRecentSearch(term);
                            },
                            child: Icon(Icons.close, size: 16, color: context.themeMutedTextColor),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
            child: Text(
              "Browse Genres",
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.themeTextColor,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              childAspectRatio: 1.6,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
        final genre = genres[index];
        final color = genre['color'] as Color;
        final title = genre['title'] as String;

        // Pick an icon based on title
        IconData genreIcon = Icons.music_note;
        if (title == 'Pop') genreIcon = Icons.star_rounded;
        if (title == 'Hip-Hop') genreIcon = Icons.mic_external_on_rounded;
        if (title == 'Mood') genreIcon = Icons.nightlight_round;
        if (title == 'Podcasts') genreIcon = Icons.podcasts_rounded;
        if (title == 'Charts') genreIcon = Icons.trending_up_rounded;
        if (title == 'Dance/Electronic') genreIcon = Icons.speaker_group_rounded;
        if (title == 'Indie') genreIcon = Icons.coffee_rounded;
        if (title == 'Workout') genreIcon = Icons.fitness_center_rounded;
        if (title == 'K-Pop') genreIcon = Icons.favorite_rounded;
        if (title == 'Sleep') genreIcon = Icons.bedtime_rounded;

        return GestureDetector(
          onTap: () {
            // Append " Mix" to force the search API to return curated genre results
            // rather than literal song titles (e.g. "Sleep Deeply").
            final smartQuery = "$title Mix";
            _searchController.text = smartQuery;
            ref.read(searchProvider.notifier).search(smartQuery);
            // Hide keyboard if it was open
            FocusScope.of(context).unfocus();
          },
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Positioned(
                  bottom: -15,
                  right: -15,
                  child: Transform.rotate(
                    angle: 0.4,
                    child: Icon(
                      genreIcon,
                      size: 70,
                      color: Colors.black.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      childCount: genres.length,
    ),
  ),
),
SliverToBoxAdapter(child: SizedBox(height: AppDimensions.bottomClearance + MediaQuery.of(context).viewPadding.bottom)),
      ],
    );
  }

  Widget _buildTopResultCard(BuildContext context, Map<String, dynamic> artist) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArtistDetailScreen(
              artistName: artist['title'] ?? _searchController.text,
              artistImage: artist['image'],
              artistId: artist['id']?.toString(),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.themeCardColor.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.themeTextColor24, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: context.themeAccentColor,
              backgroundImage: artist['image']?.toString().isNotEmpty == true 
                  ? CachedNetworkImageProvider(artist['image']) 
                  : null,
              child: artist['image']?.toString().isNotEmpty == true 
                  ? null 
                  : Icon(Icons.person, size: 40, color: context.themeInvertedTextColor),
            ),
            const SizedBox(height: 16),
            Text(
              artist['title'] ?? _searchController.text,
              style: GoogleFonts.outfit(
                color: context.themeTextColor,
                fontWeight: FontWeight.w800,
                fontSize: 28,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.themeTextColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Artist",
                    style: GoogleFonts.inter(
                      color: context.themeBackgroundColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.midnightAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildVideoListTile(BuildContext context, Map<String, dynamic> vid) {
    return Material(
      color: context.themeCardColor.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 80,
            height: 45,
            child: CustomImageWidget(
              imageUrl: vid['thumbnail'] ?? '',
              fit: BoxFit.cover,
            ),
          ),
        ),
        title: Text(
          vid['title'] ?? 'Unknown',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: context.themeTextColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          vid['uploader'] ?? 'YouTube',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: context.themeMutedTextColor,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.play_circle_fill_rounded, color: Colors.red),
        onTap: () {
          ref.read(videoPlayerProvider.notifier).playVideo(
                vid['id'] ?? '',
                vid['title'] ?? 'Unknown Video',
                vid['uploader'] ?? 'YouTube',
              );
          context.push('/video_player');
        },
      ),
    );
  }

  Widget _buildVideoGridCard(BuildContext context, Map<String, dynamic> vid) {
    return GestureDetector(
      onTap: () {
        ref.read(videoPlayerProvider.notifier).playVideo(
              vid['id'] ?? '',
              vid['title'] ?? 'Unknown Video',
              vid['uploader'] ?? 'YouTube',
            );
        context.push('/video_player');
      },
      child: Material(
        color: context.themeCardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CustomImageWidget(
                imageUrl: vid['thumbnail'] ?? '',
                fit: BoxFit.cover,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      vid['title'] ?? 'Unknown',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: context.themeTextColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(), // Replaces fixed SizedBox to soak up remaining space naturally
                    Row(
                      children: [
                      Icon(Icons.person, size: 14, color: context.themeMutedTextColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          vid['uploader'] ?? 'YouTube',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: context.themeMutedTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Icon(Icons.play_circle_fill_rounded, color: Colors.red, size: 20),
                    ],
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
