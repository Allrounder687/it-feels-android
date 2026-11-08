import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/music_identity/canonical_album.dart';
import 'package:it_feels_music/core/intelligence/federation/federated_music_intelligence_service.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/new_ambient_canvas.dart';
import '../widgets/new_artwork_image.dart';
import '../widgets/new_action_button.dart';
import '../widgets/new_glass_container.dart';
import '../widgets/new_media_tile.dart';
import '../widgets/new_section_header.dart';
import '../theme/content_viewport_insets.dart';
import '../artist/new_artist_detail_screen.dart';

class NewAlbumDetailScreen extends ConsumerStatefulWidget {
  final String albumTitle;
  final String artistName;
  final String? albumCover;
  final String? albumId;
  final List<Song>? initialTracks;

  const NewAlbumDetailScreen({
    super.key,
    required this.albumTitle,
    required this.artistName,
    this.albumCover,
    this.albumId,
    this.initialTracks,
  });

  @override
  ConsumerState<NewAlbumDetailScreen> createState() => _NewAlbumDetailScreenState();
}

class _NewAlbumDetailScreenState extends ConsumerState<NewAlbumDetailScreen> {
  final FederatedMusicIntelligenceService _fedService =
      FederatedMusicIntelligenceService();

  bool _isLoading = true;
  List<Song> _tracks = [];
  CanonicalAlbum? _canonicalAlbum;
  String _coverUrl = '';

  @override
  void initState() {
    super.initState();
    _coverUrl = widget.albumCover ?? '';
    _loadAlbumDetails();
  }

  Future<void> _loadAlbumDetails() async {
    try {
      final repo = locator<IMusicRepository>();

      // 1. Fetch tracks if not preloaded
      if (widget.initialTracks != null && widget.initialTracks!.isNotEmpty) {
        _tracks = List.from(widget.initialTracks!);
      } else {
        final found = await repo.searchSongs('${widget.albumTitle} ${widget.artistName}');
        _tracks = found.where((s) => s.album.toLowerCase().contains(widget.albumTitle.toLowerCase())).toList();
        if (_tracks.isEmpty) _tracks = found;
      }

      if (_coverUrl.isEmpty && _tracks.isNotEmpty) {
        _coverUrl = _tracks.first.image;
      }

      // 2. Build and enrich CanonicalAlbum
      final baseAlbum = CanonicalAlbum(
        id: widget.albumId ?? 'alb_${widget.albumTitle.hashCode}',
        title: widget.albumTitle,
        artist: widget.artistName,
        coverArt: _coverUrl,
        year: _tracks.isNotEmpty ? _tracks.first.year : 2024,
        trackCount: _tracks.length,
        canonicalTrackIds: _tracks.map((t) => t.id).toList(),
      );

      final enriched = await _fedService.enrichAlbum(baseAlbum);

      if (mounted) {
        setState(() {
          _canonicalAlbum = enriched;
          if (enriched.coverArt != null && enriched.coverArt!.isNotEmpty) {
            _coverUrl = enriched.coverArt!;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _playAll({int startIndex = 0}) {
    if (_tracks.isEmpty) return;
    final notifier = ref.read(audioPlayerProvider.notifier);
    notifier.playSong(_tracks[startIndex], queue: _tracks, index: startIndex);
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
        title: Text('Add Album to Playlist', style: NewExperienceTokens.sectionTitle(fontSize: 18)),
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
                  for (final song in _tracks) {
                    playlistNotifier.addSongToPlaylist(pl.id, song);
                  }
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added ${_tracks.length} tracks to "${pl.title}"')),
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
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white),
              onPressed: () {},
            ),
          ],
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Cover Artwork
                          Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(NewExperienceTokens.radiusLarge),
                              boxShadow: [
                                BoxShadow(
                                  color: NewExperienceTokens.accentViolet.withValues(alpha: 0.35),
                                  blurRadius: 28,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(NewExperienceTokens.radiusLarge),
                              child: NewArtworkImage(
                                imageUrl: _coverUrl,
                                width: 180,
                                height: 180,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          Text(
                            widget.albumTitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: NewExperienceTokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),

                          InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => NewArtistDetailScreen(artistName: widget.artistName),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              child: Text(
                                widget.artistName,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: NewExperienceTokens.accentCyan,
                                  decoration: TextDecoration.underline,
                                  decorationColor: NewExperienceTokens.accentCyan.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Metadata row (Year • Track Count • Release Type)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${_canonicalAlbum?.year ?? 2024}',
                                style: const TextStyle(color: NewExperienceTokens.textMuted, fontSize: 13),
                              ),
                              const Text(' • ', style: TextStyle(color: NewExperienceTokens.textMuted)),
                              Text(
                                '${_tracks.length} Tracks',
                                style: const TextStyle(color: NewExperienceTokens.textMuted, fontSize: 13),
                              ),
                              const Text(' • ', style: TextStyle(color: NewExperienceTokens.textMuted)),
                              Text(
                                _canonicalAlbum?.releaseType ?? 'Album',
                                style: const TextStyle(color: NewExperienceTokens.accentViolet, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Comprehensive Action Buttons: Play Album, Shuffle, Play Next, Add to Queue, Add to Playlist
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              NewActionButton(
                                label: 'Play Album',
                                icon: Icons.play_arrow_rounded,
                                onPressed: () => _playAll(startIndex: 0),
                              ),
                              NewActionButton(
                                label: 'Shuffle',
                                icon: Icons.shuffle_rounded,
                                variant: NewActionButtonVariant.glass,
                                onPressed: () {
                                  if (_tracks.isNotEmpty) {
                                    ref.read(audioPlayerProvider.notifier).shufflePlayContext(_tracks);
                                  }
                                },
                              ),
                              NewActionButton(
                                label: 'Play Next',
                                icon: Icons.playlist_play_rounded,
                                variant: NewActionButtonVariant.glass,
                                onPressed: () {
                                  if (_tracks.isNotEmpty) {
                                    ref.read(audioPlayerProvider.notifier).playNextBatch(_tracks);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Playing ${_tracks.length} tracks next')),
                                    );
                                  }
                                },
                              ),
                              NewActionButton(
                                label: 'Add to Queue',
                                icon: Icons.queue_music_rounded,
                                variant: NewActionButtonVariant.glass,
                                onPressed: () {
                                  if (_tracks.isNotEmpty) {
                                    ref.read(audioPlayerProvider.notifier).addSongsToQueue(_tracks);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Added ${_tracks.length} tracks to queue')),
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
                        ],
                      ),
                    ),
                  ),

                  // ── Album Story Section ──
                  if (_canonicalAlbum?.albumStory != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: NewGlassContainer(
                          borderRadius: NewExperienceTokens.radiusMedium,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.auto_stories_rounded, color: NewExperienceTokens.accentCyan, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Album Story',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: NewExperienceTokens.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _canonicalAlbum!.albumStory!,
                                style: NewExperienceTokens.bodyMedium(
                                  color: NewExperienceTokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ── Tracklist Header ──
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: NewSectionHeader(
                        title: 'Tracklist',
                        actionLabel: 'Playable',
                      ),
                    ),
                  ),

                  // ── Tracklist Items ──
                  if (_tracks.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.album_outlined, size: 48, color: NewExperienceTokens.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                'No tracks found for this album',
                                style: NewExperienceTokens.bodyMedium(color: NewExperienceTokens.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = _tracks[index];

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
                            child: NewMediaTile(
                              song: song,
                              index: index,
                              onTap: () => _playAll(startIndex: index),
                            ),
                          );
                        },
                        childCount: _tracks.length,
                      ),
                    ),

                  // Dynamic Bottom Clearance
                  ContentViewportInsets.sliverBottomSpacer(context, ref),
                ],
              ),
      ),
    );
  }
}
