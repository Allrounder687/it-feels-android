import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/providers/bottom_ui_provider.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:it_feels_music/core/widgets/song_options_sheet.dart';
import 'package:it_feels_music/core/widgets/skeleton_loading_list.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/library/artist_detail_screen.dart';
import 'package:it_feels_music/features/library/playlist_detail_screen.dart';
import 'package:it_feels_music/features/neo/home/widgets/neo_media_card.dart';
import 'package:it_feels_music/features/neo/home/widgets/neo_shelf_header.dart';

class NeoSearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;

  const NeoSearchScreen({super.key, this.initialQuery});

  @override
  ConsumerState<NeoSearchScreen> createState() => _NeoSearchScreenState();
}

class _NeoSearchScreenState extends ConsumerState<NeoSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _selectedFilterIndex = 0;
  final List<String> _filters = ["All", "Songs", "Artists", "Albums", "Playlists"];

  final List<Map<String, dynamic>> _browseGenres = [
    {
      'title': 'Bollywood & Desi',
      'query': 'Bollywood Top Hits',
      'colors': [const Color(0xFFE52D27), const Color(0xFFB31217)],
    },
    {
      'title': 'Pop & International',
      'query': 'Today Top Hits English',
      'colors': [const Color(0xFF3A1C71), const Color(0xFFD76D77)],
    },
    {
      'title': 'Hip-Hop & Rap',
      'query': 'Hip Hop Hits',
      'colors': [const Color(0xFFF7971E), const Color(0xFFFFD200)],
    },
    {
      'title': 'Dance & EDM',
      'query': 'Dance Electronic Hits',
      'colors': [const Color(0xFF8A2387), const Color(0xFFE94057)],
    },
    {
      'title': 'Punjabi Beats',
      'query': 'Punjabi Top Hits 2026',
      'colors': [const Color(0xFFF37335), const Color(0xFFFDC830)],
    },
    {
      'title': 'Chill & Acoustic',
      'query': 'Chill Acoustic Vibes',
      'colors': [const Color(0xFF134E5E), const Color(0xFF71B280)],
    },
    {
      'title': 'Romance & Love',
      'query': 'Romantic Hits',
      'colors': [const Color(0xFFED213A), const Color(0xFF93291E)],
    },
    {
      'title': 'Tollywood & Telugu',
      'query': 'Telugu Top Hits 2026',
      'colors': [const Color(0xFF4A00E0), const Color(0xFF8E2DE2)],
    },
    {
      'title': 'Kollywood & Tamil',
      'query': 'Tamil Top Hits 2026',
      'colors': [const Color(0xFF11998E), const Color(0xFF38EF7D)],
    },
    {
      'title': 'Workout & Energy',
      'query': 'Workout Motivation',
      'colors': [const Color(0xFFFF416C), const Color(0xFFFF4B2B)],
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(searchProvider.notifier).search(widget.initialQuery!);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    ref.read(searchProvider.notifier).search(query.trim());
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final hiddenSongs = ref.watch(hiddenSongsProvider);
    final playerState = ref.watch(audioPlayerProvider);
    final bottomUiHeight = ref.watch(bottomUiProvider);
    final accentColor = playerState.themeAccentColor;

    final rawSongs = searchState.songs.where((s) => !hiddenSongs.isHidden(s.id)).toList();
    final List<Song> songs = [];
    final Set<String> seenKeys = {};
    for (var s in rawSongs) {
      final key = '${s.title.trim().toLowerCase()}_${s.artist.trim().toLowerCase()}';
      if (seenKeys.add(key)) {
        songs.add(s);
      }
    }

    final artists = searchState.artists;
    final albums = searchState.albums;
    final playlists = searchState.playlists;
    final isQueryEmpty = searchState.query.isEmpty && _searchController.text.trim().isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E18),
      body: SafeArea(
        top: true,
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Editorial Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 12.0, bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "EXPLORE & DISCOVER",
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Colors.white.withValues(alpha: 0.50),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Search",
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Frosted Search Input Field ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _focusNode.hasFocus
                          ? accentColor.withValues(alpha: 0.60)
                          : Colors.white.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(
                        Icons.search_rounded,
                        color: Colors.white.withValues(alpha: 0.50),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          cursorColor: accentColor,
                          textInputAction: TextInputAction.search,
                          onSubmitted: _onSearchSubmitted,
                          decoration: InputDecoration(
                            hintText: "Artists, songs, lyrics, or playlists...",
                            hintStyle: GoogleFonts.inter(
                              fontSize: 14.5,
                              color: Colors.white.withValues(alpha: 0.35),
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withValues(alpha: 0.60),
                            size: 18,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _searchController.clear();
                            ref.read(searchProvider.notifier).clear();
                            setState(() {});
                          },
                        ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            ),

            // ── Search Segment Filter Capsules (When Search is Active) ──
            if (!isQueryEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 4.0),
                    itemCount: _filters.length,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedFilterIndex == index;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedFilterIndex = index;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8.0),
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? accentColor.withValues(alpha: 0.22)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? accentColor.withValues(alpha: 0.45)
                                  : Colors.white.withValues(alpha: 0.10),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _filters[index],
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? accentColor : Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // ── Content State: Empty Query (Browse Categories & Recent Searches) ──
            if (isQueryEmpty) ...[
              if (searchState.recentSearches.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Recent Searches",
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref.read(searchProvider.notifier).clearRecentSearches();
                          },
                          child: Text(
                            "Clear",
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
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
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 18.0),
                      itemCount: searchState.recentSearches.length,
                      itemBuilder: (context, index) {
                        final term = searchState.recentSearches[index];
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _searchController.text = term;
                            ref.read(searchProvider.notifier).search(term);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8.0),
                            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  color: Colors.white.withValues(alpha: 0.50),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  term,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(
                child: NeoShelfHeader(
                  title: "Browse Categories",
                  subtitle: "EXPLORE SOUNDSCAPES",
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.65,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _browseGenres[index];
                      final title = item['title'] as String;
                      final query = item['query'] as String;
                      final colors = item['colors'] as List<Color>;

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _searchController.text = title;
                          ref.read(searchProvider.notifier).search(query);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: colors,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: colors.first.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // Specular highlight rim
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: 1.0,
                                child: Container(
                                  color: Colors.white.withValues(alpha: 0.30),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: Text(
                                    title,
                                    style: GoogleFonts.outfit(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withValues(alpha: 0.40),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
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
                    childCount: _browseGenres.length,
                  ),
                ),
              ),
            ],

            // ── Loading Skeleton ──
            if (!isQueryEmpty && searchState.isSearching && songs.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: SkeletonLoadingList(),
                ),
              ),

            // ── Search Results: Top Artist Match ──
            if (!isQueryEmpty &&
                (_selectedFilterIndex == 0 || _selectedFilterIndex == 2) &&
                artists.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: NeoShelfHeader(
                  title: "Artists",
                  subtitle: "TOP MATCH",
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    itemCount: artists.length,
                    itemBuilder: (context, index) {
                      final artist = artists[index];
                      final name = artist['title']?.toString() ?? artist['name']?.toString() ?? '';
                      final image = artist['image']?.toString() ?? '';
                      final id = artist['id']?.toString() ?? '';

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ArtistDetailScreen(
                                artistName: name,
                                artistImage: image.isNotEmpty ? image : null,
                                artistId: id.isNotEmpty ? id : null,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 88,
                          margin: const EdgeInsets.only(right: 14.0),
                          child: Column(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: image.isNotEmpty
                                      ? CustomImageWidget(imageUrl: image, fit: BoxFit.cover)
                                      : Container(
                                          color: const Color(0xFF1B2232),
                                          child: const Icon(Icons.person, color: Colors.white54),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],

            // ── Search Results: Songs ──
            if (!isQueryEmpty &&
                (_selectedFilterIndex == 0 || _selectedFilterIndex == 1) &&
                songs.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: NeoShelfHeader(
                  title: "Songs",
                  subtitle: "TRACK RESULTS",
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = songs[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: CustomImageWidget(imageUrl: song.coverArt, fit: BoxFit.cover),
                            ),
                          ),
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: Colors.white.withValues(alpha: 0.60),
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.more_vert_rounded,
                              color: Colors.white.withValues(alpha: 0.60),
                              size: 20,
                            ),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => SongOptionsSheet(song: song),
                              );
                            },
                          ),
                          onTap: () {
                            ref.read(audioPlayerProvider.notifier).playSong(
                                  song,
                                  queue: songs,
                                  index: index,
                                );
                          },
                        ),
                      );
                    },
                    childCount: songs.length,
                  ),
                ),
              ),
            ],

            // ── Search Results: Albums ──
            if (!isQueryEmpty &&
                (_selectedFilterIndex == 0 || _selectedFilterIndex == 3) &&
                albums.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: NeoShelfHeader(
                  title: "Albums",
                  subtitle: "FULL RELEASES",
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 195,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    itemCount: albums.length,
                    itemBuilder: (context, index) {
                      final album = albums[index];
                      return NeoMediaCard(
                        title: album.title,
                        subtitle: album.type == 'album' ? "Album" : "${album.songCount} Songs",
                        imageUrl: album.coverArt,
                        size: 140,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlaylistDetailScreen(playlist: album),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],

            // ── Search Results: Playlists ──
            if (!isQueryEmpty &&
                (_selectedFilterIndex == 0 || _selectedFilterIndex == 4) &&
                playlists.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: NeoShelfHeader(
                  title: "Playlists",
                  subtitle: "COMMUNITY & CURATED",
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 205,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return NeoMediaCard(
                        title: playlist.title,
                        subtitle: "${playlist.songCount} Songs",
                        imageUrl: playlist.coverArt,
                        size: 150,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlaylistDetailScreen(playlist: playlist),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],

            // ── Bottom Clearance for Floating Island Dock ──
            SliverToBoxAdapter(
              child: SizedBox(height: bottomUiHeight + 36),
            ),
          ],
        ),
      ),
    );
  }
}
