import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/music_identity/canonical_artist.dart';
import 'package:it_feels_music/core/intelligence/federation/federated_music_intelligence_service.dart';
import 'package:it_feels_music/core/intelligence/analytics/music_dna_service.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/new_ambient_canvas.dart';
import '../widgets/new_media_tile.dart';
import '../widgets/new_action_button.dart';
import '../widgets/new_section_header.dart';
import '../widgets/new_card.dart';
import '../widgets/new_glass_container.dart';
import '../widgets/new_artwork_image.dart';
import '../album/new_album_detail_screen.dart';
import '../see_all/new_see_all_screen.dart';
import '../theme/content_viewport_insets.dart';

class NewArtistDetailScreen extends ConsumerStatefulWidget {
  final String artistName;
  final String? artistImage;
  final String? artistId;

  const NewArtistDetailScreen({
    super.key,
    required this.artistName,
    this.artistImage,
    this.artistId,
  });

  @override
  ConsumerState<NewArtistDetailScreen> createState() => _NewArtistDetailScreenState();
}

class _NewArtistDetailScreenState extends ConsumerState<NewArtistDetailScreen> with SingleTickerProviderStateMixin {
  final FederatedMusicIntelligenceService _fedService = FederatedMusicIntelligenceService();
  final MusicDnaService _dnaService = MusicDnaService();

  late TabController _tabController;
  bool _isLoading = true;
  List<Song> _topSongs = [];
  List<Playlist> _albums = [];
  String _imageUrl = '';
  CanonicalArtist? _canonicalArtist;
  ArtistPersonalRelationship? _personalRelationship;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _imageUrl = widget.artistImage ?? '';
    _loadArtist();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadArtist() async {
    try {
      final repo = locator<IMusicRepository>();
      final songs = await repo.searchSongs(widget.artistName);
      final albums = await repo.searchAlbums(widget.artistName);

      if (_imageUrl.isEmpty && songs.isNotEmpty) {
        _imageUrl = songs.first.image;
      }

      // Base canonical model
      final base = CanonicalArtist(
        id: widget.artistId ?? 'art_${widget.artistName.hashCode}',
        name: widget.artistName,
        imageUrl: _imageUrl,
      );

      // Concurrently enrich with federated intelligence & personal relationship
      final results = await Future.wait([
        _fedService.enrichArtist(base),
        _dnaService.getArtistRelationship(widget.artistName),
      ]);

      if (mounted) {
        setState(() {
          _topSongs = songs;
          _albums = albums;
          _canonicalArtist = results[0] as CanonicalArtist;
          _personalRelationship = results[1] as ArtistPersonalRelationship;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _playAll({int startIndex = 0}) {
    if (_topSongs.isEmpty) return;
    ref.read(audioPlayerProvider.notifier).playSong(_topSongs[startIndex], queue: _topSongs, index: startIndex);
  }

  void _showAddToPlaylistDialog() {
    final playlistState = ref.read(customPlaylistProvider);
    final playlistNotifier = ref.read(customPlaylistProvider.notifier);
    if (playlistState.playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No custom playlists yet. Create one in your Library first!')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NewExperienceTokens.midnightSurface,
        title: Text('Add Artist Tracks to Playlist', style: NewExperienceTokens.sectionTitle(fontSize: 18)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: playlistState.playlists.length,
            itemBuilder: (context, idx) {
              final pl = playlistState.playlists[idx];
              return ListTile(
                leading: const Icon(Icons.playlist_add_rounded, color: NewExperienceTokens.accentCyan),
                title: Text(pl.title, style: NewExperienceTokens.bodyMedium()),
                subtitle: Text('${pl.songs.length} tracks', style: NewExperienceTokens.captionMuted()),
                onTap: () {
                  for (final song in _topSongs) {
                    playlistNotifier.addSongToPlaylist(pl.id, song);
                  }
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added ${_topSongs.length} tracks to "${pl.title}"')),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NewAmbientCanvas(
      intensity: 0.55,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: NewExperienceTokens.accentViolet),
              )
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── Hero Banner ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Circular Artist Portrait
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: NewExperienceTokens.accentViolet.withValues(alpha: 0.35),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: NewArtworkImage(
                                imageUrl: _imageUrl,
                                width: 140,
                                height: 140,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Primary Name
                          Text(
                            widget.artistName,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: NewExperienceTokens.textPrimary,
                            ),
                          ),

                          // Native Names (Devanagari, regional script)
                          if (_canonicalArtist != null && _canonicalArtist!.nativeNames.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              _canonicalArtist!.nativeNames.first,
                              style: const TextStyle(
                                fontSize: 14,
                                color: NewExperienceTokens.accentCyan,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],

                          const SizedBox(height: 6),

                          // Meta context: Origin • Active Years
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_canonicalArtist?.country != null) ...[
                                Text(
                                  _canonicalArtist!.country!,
                                  style: const TextStyle(color: NewExperienceTokens.textMuted, fontSize: 13),
                                ),
                                const Text(' • ', style: TextStyle(color: NewExperienceTokens.textMuted)),
                              ],
                              Text(
                                _canonicalArtist?.activeYears ?? 'Verified Artist',
                                style: const TextStyle(color: NewExperienceTokens.textMuted, fontSize: 13),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // Action Buttons: Play Artist, Shuffle, Play Next, Add to Queue, Add to Playlist
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              NewActionButton(
                                label: 'Play Artist',
                                icon: Icons.play_arrow_rounded,
                                onPressed: () => _playAll(startIndex: 0),
                              ),
                              NewActionButton(
                                label: 'Shuffle',
                                icon: Icons.shuffle_rounded,
                                variant: NewActionButtonVariant.glass,
                                onPressed: () {
                                  if (_topSongs.isNotEmpty) {
                                    ref.read(audioPlayerProvider.notifier).shufflePlayContext(_topSongs);
                                  }
                                },
                              ),
                              NewActionButton(
                                label: 'Play Next',
                                icon: Icons.playlist_play_rounded,
                                variant: NewActionButtonVariant.glass,
                                onPressed: () {
                                  if (_topSongs.isNotEmpty) {
                                    ref.read(audioPlayerProvider.notifier).playNextBatch(_topSongs);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Playing ${_topSongs.length} tracks next')),
                                    );
                                  }
                                },
                              ),
                              NewActionButton(
                                label: 'Add to Queue',
                                icon: Icons.queue_music_rounded,
                                variant: NewActionButtonVariant.glass,
                                onPressed: () {
                                  if (_topSongs.isNotEmpty) {
                                    ref.read(audioPlayerProvider.notifier).addSongsToQueue(_topSongs);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Added ${_topSongs.length} tracks to queue')),
                                    );
                                  }
                                },
                              ),
                              NewActionButton(
                                label: 'Add to Playlist',
                                icon: Icons.playlist_add_rounded,
                                variant: NewActionButtonVariant.glass,
                                onPressed: _showAddToPlaylistDialog,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Tab Bar
                          TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            tabAlignment: TabAlignment.center,
                            indicatorColor: NewExperienceTokens.accentCyan,
                            indicatorWeight: 3,
                            labelColor: NewExperienceTokens.accentCyan,
                            unselectedLabelColor: NewExperienceTokens.textMuted,
                            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                            unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.normal, fontSize: 14),
                            tabs: const [
                              Tab(text: 'Overview'),
                              Tab(text: 'Timeline'),
                              Tab(text: 'Connections'),
                              Tab(text: 'Your History'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Tab View Content ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: AnimatedBuilder(
                        animation: _tabController,
                        builder: (context, _) {
                          switch (_tabController.index) {
                            case 1:
                              return _buildTimelineTab();
                            case 2:
                              return _buildConnectionsTab();
                            case 3:
                              return _buildHistoryTab();
                            case 0:
                            default:
                              return _buildOverviewTab();
                          }
                        },
                      ),
                    ),
                  ),

                  // Dynamic Bottom Clearance
                  ContentViewportInsets.sliverBottomSpacer(context, ref),
                ],
              ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Biography snippet if available
        if (_canonicalArtist?.biography != null) ...[
          NewGlassContainer(
            borderRadius: NewExperienceTokens.radiusMedium,
            padding: const EdgeInsets.all(14),
            child: Text(
              _canonicalArtist!.biography!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: NewExperienceTokens.bodyMedium(
                color: NewExperienceTokens.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Popular Songs
        NewSectionHeader(
          title: 'Popular Songs',
          actionLabel: 'See All',
          onAction: _topSongs.length > 8
              ? () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NewSeeAllScreen.songs(
                        title: '${widget.artistName} - Popular Songs',
                        eyebrow: 'ARTIST TOP TRACKS',
                        songs: _topSongs,
                      ),
                    ),
                  )
              : null,
        ),
        const SizedBox(height: 8),

        ..._topSongs.take(8).toList().asMap().entries.map((entry) {
          final index = entry.key;
          final song = entry.value;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: NewMediaTile(
              song: song,
              index: index,
              onTap: () => _playAll(startIndex: index),
            ),
          );
        }),

        const SizedBox(height: 24),

        // Discography & Albums Carousel
        if (_albums.isNotEmpty) ...[
          NewSectionHeader(
            title: 'Discography & Albums',
            actionLabel: 'See All',
            onAction: _albums.length > 6
                ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NewSeeAllScreen.playlists(
                          title: '${widget.artistName} - Discography',
                          eyebrow: 'DISCOGRAPHY & ALBUMS',
                          playlists: _albums,
                        ),
                      ),
                    )
                : null,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 195,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _albums.length,
              separatorBuilder: (context, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final album = _albums[index];
                return SizedBox(
                  width: 140,
                  child: NewCard(
                    title: album.title,
                    subtitle: album.subtitle,
                    imageUrl: album.image,
                    badgeText: 'Album',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => NewAlbumDetailScreen(
                            albumTitle: album.title,
                            artistName: widget.artistName,
                            albumCover: album.image,
                            albumId: album.id,
                            initialTracks: album.songs,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimelineTab() {
    final timeline = _canonicalArtist?.timeline ?? [];
    if (timeline.isEmpty) {
      return _buildNoticeCard('No chronological career milestones recorded for this artist yet.');
    }

    return Column(
      children: timeline.map((m) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: NewGlassContainer(
            borderRadius: NewExperienceTokens.radiusMedium,
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: NewExperienceTokens.accentCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: NewExperienceTokens.accentCyan.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    m['year']?.toString() ?? 'Year',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: NewExperienceTokens.accentCyan,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m['title']?.toString() ?? 'Milestone',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: NewExperienceTokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m['detail']?.toString() ?? '',
                        style: NewExperienceTokens.bodyMedium(
                          color: NewExperienceTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildConnectionsTab() {
    final collaborators = _canonicalArtist?.collaborators ?? [];
    final similar = _canonicalArtist?.relatedArtists ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NewSectionHeader(
          title: 'Verified Collaborators',
          actionLabel: 'On Recordings',
        ),
        const SizedBox(height: 10),
        if (collaborators.isEmpty)
          _buildNoticeCard('No recorded collaborators found in catalog.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: collaborators.map((c) {
              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => NewArtistDetailScreen(artistName: c),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: NewExperienceTokens.midnightSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: NewExperienceTokens.specularBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_rounded, size: 14, color: NewExperienceTokens.accentViolet),
                      const SizedBox(width: 6),
                      Text(
                        c,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: NewExperienceTokens.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

        const SizedBox(height: 24),

        const NewSectionHeader(
          title: 'Similar Artists',
          actionLabel: 'Community',
        ),
        const SizedBox(height: 10),
        if (similar.isEmpty)
          _buildNoticeCard('No similar artists mapped yet.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: similar.map((s) {
              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => NewArtistDetailScreen(artistName: s),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: NewExperienceTokens.midnightSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: NewExperienceTokens.specularBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.graphic_eq_rounded, size: 14, color: NewExperienceTokens.accentCyan),
                      const SizedBox(width: 6),
                      Text(
                        s,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: NewExperienceTokens.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    final rel = _personalRelationship;
    if (rel == null || rel.totalPlays == 0) {
      return _buildNoticeCard('You have not played tracks by ${widget.artistName} yet on this device.');
    }

    return Column(
      children: [
        NewGlassContainer(
          borderRadius: NewExperienceTokens.radiusMedium,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '${rel.totalPlays}',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: NewExperienceTokens.accentCyan,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'TOTAL PLAYS',
                        style: NewExperienceTokens.eyebrowLabel(color: NewExperienceTokens.textMuted),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '${(rel.averageCompletionRate * 100).toInt()}%',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: NewExperienceTokens.accentViolet,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'COMPLETION',
                        style: NewExperienceTokens.eyebrowLabel(color: NewExperienceTokens.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (rel.mostPlayedTracks.isNotEmpty) ...[
          const NewSectionHeader(
            title: 'Your Most Played Tracks',
            actionLabel: 'On Device',
          ),
          const SizedBox(height: 8),
          NewGlassContainer(
            borderRadius: NewExperienceTokens.radiusMedium,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: rel.mostPlayedTracks.map((t) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.music_note_rounded, color: NewExperienceTokens.accentViolet),
                  title: Text(
                    t.key,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: NewExperienceTokens.textPrimary),
                  ),
                  trailing: Text(
                    '${t.value} plays',
                    style: const TextStyle(color: NewExperienceTokens.accentCyan, fontSize: 13),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNoticeCard(String msg) {
    return NewGlassContainer(
      borderRadius: NewExperienceTokens.radiusMedium,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: NewExperienceTokens.bodyMedium(color: NewExperienceTokens.textMuted),
        ),
      ),
    );
  }
}
