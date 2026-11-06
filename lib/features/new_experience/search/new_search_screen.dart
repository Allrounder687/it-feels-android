import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:it_feels_music/features/search/search_provider.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/new_ambient_canvas.dart';
import '../widgets/new_media_tile.dart';
import '../widgets/new_glass_container.dart';
import '../playlist/new_playlist_detail_screen.dart';
import '../artist/new_artist_detail_screen.dart';

class NewSearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;

  const NewSearchScreen({super.key, this.initialQuery});

  @override
  ConsumerState<NewSearchScreen> createState() => _NewSearchScreenState();
}

class _NewSearchScreenState extends ConsumerState<NewSearchScreen> {
  late final TextEditingController _searchController;
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'Songs', 'Artists', 'Albums', 'Playlists'];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(searchProvider.notifier).search(widget.initialQuery!);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final searchNotifier = ref.read(searchProvider.notifier);
    final playerNotifier = ref.read(audioPlayerProvider.notifier);

    final hasQuery = searchState.query.trim().isNotEmpty;

    return NewAmbientCanvas(
      intensity: 0.3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Header & Search Input ──
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EXPLORE & FIND',
                      style: NewExperienceTokens.eyebrowLabel(
                        color: NewExperienceTokens.accentCyan,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Search Music',
                      style: NewExperienceTokens.displayHero(fontSize: 28),
                    ),
                    const SizedBox(height: 14),

                    // Search Field Box
                    NewGlassContainer(
                      borderRadius: NewExperienceTokens.radiusMedium,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            color: NewExperienceTokens.textSecondary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: NewExperienceTokens.bodyMedium(),
                              decoration: InputDecoration(
                                hintText: 'Songs, artists, albums, podcasts...',
                                hintStyle: NewExperienceTokens.bodySmall(
                                  color: NewExperienceTokens.textMuted,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onChanged: (val) {
                                searchNotifier.search(val);
                              },
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: NewExperienceTokens.textMuted,
                                size: 18,
                              ),
                              splashRadius: 16,
                              onPressed: () {
                                _searchController.clear();
                                searchNotifier.search('');
                              },
                            ),
                        ],
                      ),
                    ),

                    if (hasQuery) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _filters.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final filter = _filters[index];
                            final isSelected = _selectedFilter == filter;

                            return InkWell(
                              onTap: () => setState(() => _selectedFilter = filter),
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? NewExperienceTokens.accentViolet
                                      : Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.transparent
                                        : NewExperienceTokens.specularBorder,
                                  ),
                                ),
                                child: Text(
                                  filter,
                                  style: NewExperienceTokens.bodySmall(
                                    color: isSelected ? Colors.white : NewExperienceTokens.textSecondary,
                                  ).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Search Results or Genre Browse Feed ──
              Expanded(
                child: searchState.isSearching
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: NewExperienceTokens.accentViolet,
                        ),
                      )
                    : hasQuery
                        ? _buildSearchResults(searchState, playerNotifier)
                        : _buildBrowseAndRecent(searchState, searchNotifier),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(SearchState searchState, AudioPlayerNotifier playerNotifier) {
    if (searchState.songs.isEmpty &&
        searchState.artists.isEmpty &&
        searchState.albums.isEmpty &&
        searchState.playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_off_rounded, size: 48, color: NewExperienceTokens.textMuted),
            const SizedBox(height: 12),
            Text(
              'No matches found',
              style: NewExperienceTokens.sectionTitle(color: NewExperienceTokens.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Try searching with a different artist, song, or spelling.',
              style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 120),
      physics: const BouncingScrollPhysics(),
      children: [
        // Top Artist Match
        if (searchState.artists.isNotEmpty &&
            (_selectedFilter == 'All' || _selectedFilter == 'Artists')) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Top Artist Match', style: NewExperienceTokens.sectionTitle()),
          ),
          InkWell(
            onTap: () {
              final artist = searchState.artists.first;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => NewArtistDetailScreen(
                    artistId: artist['id']?.toString() ?? '',
                    artistName: artist['name']?.toString() ?? 'Artist',
                    artistImage: artist['image']?.toString() ?? '',
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: NewGlassContainer(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: NewExperienceTokens.midnightSurface,
                    backgroundImage: searchState.artists.first['image'] != null
                        ? NetworkImage(searchState.artists.first['image'].toString())
                        : null,
                    child: searchState.artists.first['image'] == null
                        ? const Icon(Icons.person_rounded, size: 28)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          searchState.artists.first['name']?.toString() ?? 'Artist',
                          style: NewExperienceTokens.sectionTitle(fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Artist • Verified JioSaavn Catalogue',
                          style: NewExperienceTokens.captionMuted(
                            color: NewExperienceTokens.accentCyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: NewExperienceTokens.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Songs Results
        if (searchState.songs.isNotEmpty &&
            (_selectedFilter == 'All' || _selectedFilter == 'Songs')) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Songs', style: NewExperienceTokens.sectionTitle()),
          ),
          ...searchState.songs.take(25).map(
                (song) => NewMediaTile(
                  song: song,
                  onTap: () => playerNotifier.playSong(song),
                ),
              ),
        ],

        // Albums Results
        if (searchState.albums.isNotEmpty &&
            (_selectedFilter == 'All' || _selectedFilter == 'Albums')) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Albums', style: NewExperienceTokens.sectionTitle()),
          ),
          ...searchState.albums.take(8).map(
                (album) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: album.image,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(album.title, style: NewExperienceTokens.bodyMedium()),
                  subtitle: Text(album.subtitle, style: NewExperienceTokens.captionMuted()),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => NewPlaylistDetailScreen(playlist: album),
                      ),
                    );
                  },
                ),
              ),
        ],
      ],
    );
  }

  Widget _buildBrowseAndRecent(SearchState searchState, SearchNotifier searchNotifier) {
    return ListView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 120),
      physics: const BouncingScrollPhysics(),
      children: [
        // Recent Searches
        if (searchState.recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Searches', style: NewExperienceTokens.sectionTitle(fontSize: 18)),
              TextButton(
                onPressed: () => searchNotifier.clearRecentSearches(),
                child: Text('Clear', style: NewExperienceTokens.captionMuted()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: searchState.recentSearches.take(6).map((q) {
              return InkWell(
                onTap: () {
                  _searchController.text = q;
                  searchNotifier.search(q);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: NewExperienceTokens.specularBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history_rounded, size: 14, color: NewExperienceTokens.textMuted),
                      const SizedBox(width: 6),
                      Text(q, style: NewExperienceTokens.bodySmall()),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],

        // Browse All Genres (Apple Music & Spotify Curated 2-column cards)
        Text('Browse Categories', style: NewExperienceTokens.sectionTitle(fontSize: 20)),
        const SizedBox(height: 12),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.1,
          ),
          itemCount: _genreBrowseCards.length,
          itemBuilder: (context, index) {
            final card = _genreBrowseCards[index];
            final gradientColors = card['gradient'] as List<Color>;
            return InkWell(
              onTap: () {
                _searchController.text = card['query'] as String;
                searchNotifier.search(card['query'] as String);
              },
              borderRadius: BorderRadius.circular(NewExperienceTokens.radiusMedium),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      gradientColors.first,
                      gradientColors.last.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(NewExperienceTokens.radiusMedium),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.first.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Stack(
                  clipBehavior: Clip.antiAlias,
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        card['title'] as String,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Transform.rotate(
                        angle: -0.15,
                        child: Icon(
                          card['icon'] as IconData,
                          color: Colors.white.withValues(alpha: 0.4),
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  static final List<Map<String, dynamic>> _genreBrowseCards = [
    {
      'title': 'Bollywood & Desi',
      'query': 'Bollywood Hits',
      'gradient': [const Color(0xFFE11D48), const Color(0xFFBE123C)],
      'icon': Icons.movie_filter_rounded,
    },
    {
      'title': 'Pop & Global',
      'query': 'Global Pop Hits',
      'gradient': [const Color(0xFF4F46E5), const Color(0xFF4338CA)],
      'icon': Icons.public_rounded,
    },
    {
      'title': 'Punjabi Beats',
      'query': 'Punjabi Top Hits',
      'gradient': [const Color(0xFFD97706), const Color(0xFFB45309)],
      'icon': Icons.music_note_rounded,
    },
    {
      'title': 'Hip-Hop & Rap',
      'query': 'Hip Hop Hits',
      'gradient': [const Color(0xFF059669), const Color(0xFF047857)],
      'icon': Icons.graphic_eq_rounded,
    },
    {
      'title': 'Chill & Acoustic',
      'query': 'Indie Acoustic',
      'gradient': [const Color(0xFF0891B2), const Color(0xFF0E7490)],
      'icon': Icons.spa_rounded,
    },
    {
      'title': 'Romance & Love',
      'query': 'Romantic Hindi',
      'gradient': [const Color(0xFF9333EA), const Color(0xFF7E22CE)],
      'icon': Icons.favorite_rounded,
    },
    {
      'title': 'Dance & Party',
      'query': 'Club Party EDM',
      'gradient': [const Color(0xFFDC2626), const Color(0xFF991B1B)],
      'icon': Icons.nightlife_rounded,
    },
    {
      'title': 'Tollywood & Telugu',
      'query': 'Telugu Top Hits',
      'gradient': [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
      'icon': Icons.star_rounded,
    },
  ];
}
