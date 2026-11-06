import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/new_ambient_canvas.dart';
import '../widgets/new_media_tile.dart';
import '../widgets/new_action_button.dart';
import '../widgets/new_section_header.dart';
import '../widgets/new_card.dart';
import '../playlist/new_playlist_detail_screen.dart';

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

class _NewArtistDetailScreenState extends ConsumerState<NewArtistDetailScreen> {
  bool _isLoading = true;
  List<Song> _topSongs = [];
  List<Playlist> _albums = [];
  String _imageUrl = '';

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.artistImage ?? '';
    _loadArtist();
  }

  Future<void> _loadArtist() async {
    try {
      final repo = locator<IMusicRepository>();
      final songs = await repo.searchSongs(widget.artistName);
      final albums = await repo.searchAlbums(widget.artistName);

      if (mounted) {
        setState(() {
          _topSongs = songs;
          _albums = albums;
          if (_imageUrl.isEmpty && songs.isNotEmpty) {
            _imageUrl = songs.first.image;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerNotifier = ref.read(audioPlayerProvider.notifier);

    return NewAmbientCanvas(
      intensity: 0.45,
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
                              border: Border.all(
                                color: NewExperienceTokens.accentViolet.withValues(alpha: 0.5),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _imageUrl.isNotEmpty
                                  ? CachedNetworkImage(imageUrl: _imageUrl, fit: BoxFit.cover)
                                  : const Icon(Icons.person_rounded, size: 60),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Verified Badge & Name
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.artistName,
                                style: NewExperienceTokens.displayHero(fontSize: 26),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified_rounded,
                                color: NewExperienceTokens.accentCyan,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Verified Artist • JioSaavn Catalogue',
                            style: NewExperienceTokens.captionMuted(
                              color: NewExperienceTokens.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Action Buttons
                          Wrap(
                            spacing: 12,
                            children: [
                              NewActionButton(
                                label: 'Play Top Songs',
                                icon: Icons.play_arrow_rounded,
                                onPressed: () {
                                  if (_topSongs.isNotEmpty) {
                                    playerNotifier.playSong(_topSongs.first, queue: _topSongs, index: 0);
                                  }
                                },
                              ),
                              NewActionButton(
                                label: 'Shuffle',
                                icon: Icons.shuffle_rounded,
                                variant: NewActionButtonVariant.glass,
                                onPressed: () {
                                  if (_topSongs.isNotEmpty) {
                                    final shuffled = List<Song>.from(_topSongs)..shuffle();
                                    playerNotifier.playSong(shuffled.first, queue: shuffled, index: 0);
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // ── Top 10 Popular Tracks ──
                  if (_topSongs.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: NewSectionHeader(
                          title: 'Popular Tracks',
                          eyebrow: 'TOP HITS',
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = _topSongs[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: NewMediaTile(
                              song: song,
                              index: index,
                              onTap: () => playerNotifier.playSong(song, queue: _topSongs, index: index),
                            ),
                          );
                        },
                        childCount: _topSongs.take(10).length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  ],

                  // ── Discography / Albums ──
                  if (_albums.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: NewSectionHeader(
                          title: 'Discography',
                          eyebrow: 'ALBUMS & SINGLES',
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 220,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _albums.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 14),
                          itemBuilder: (context, index) {
                            final album = _albums[index];
                            return NewCard(
                              title: album.title,
                              subtitle: album.subtitle,
                              imageUrl: album.image,
                              width: 148,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        NewPlaylistDetailScreen(playlist: album),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
      ),
    );
  }
}
