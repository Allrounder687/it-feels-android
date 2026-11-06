import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/utils/string_utils.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/new_ambient_canvas.dart';
import '../widgets/new_media_tile.dart';
import '../widgets/new_action_button.dart';
import '../widgets/new_glass_container.dart';

class NewPlaylistDetailScreen extends ConsumerStatefulWidget {
  final Playlist playlist;
  final List<Song>? staticTracks;

  const NewPlaylistDetailScreen({
    super.key,
    required this.playlist,
    this.staticTracks,
  });

  @override
  ConsumerState<NewPlaylistDetailScreen> createState() => _NewPlaylistDetailScreenState();
}

class _NewPlaylistDetailScreenState extends ConsumerState<NewPlaylistDetailScreen> {
  bool _isLoading = true;
  List<Song> _tracks = [];
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.staticTracks != null) {
      _tracks = List.from(widget.staticTracks!);
      _isLoading = false;
    } else {
      _fetchTracks();
    }
  }

  Future<void> _fetchTracks() async {
    try {
      final repo = locator<IMusicRepository>();
      final tracks = await repo.getPlaylistTracks(widget.playlist.id);
      if (mounted) {
        setState(() {
          _tracks = tracks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerNotifier = ref.read(audioPlayerProvider.notifier);

    final filteredTracks = _filterQuery.isEmpty
        ? _tracks
        : _tracks
            .where((s) =>
                s.title.toLowerCase().contains(_filterQuery.toLowerCase()) ||
                s.artist.toLowerCase().contains(_filterQuery.toLowerCase()))
            .toList();

    final totalSeconds = _tracks.fold<int>(0, (sum, s) => sum + s.duration);
    final totalDurationStr = StringUtils.formatDuration(Duration(seconds: totalSeconds));

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
          actions: [
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Playlist link copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
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
                  // ── Hero Header ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 600;

                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildCoverArt(180),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('PLAYLIST', style: NewExperienceTokens.eyebrowLabel()),
                                      const SizedBox(height: 6),
                                      Text(
                                        widget.playlist.title,
                                        style: NewExperienceTokens.displayHero(fontSize: 32),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${_tracks.length} Songs • $totalDurationStr',
                                        style: NewExperienceTokens.bodySmall(
                                          color: NewExperienceTokens.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildActionButtons(playerNotifier),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }

                          // Mobile Column Header
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildCoverArt(160),
                              const SizedBox(height: 16),
                              Text(
                                widget.playlist.title,
                                textAlign: TextAlign.center,
                                style: NewExperienceTokens.displayHero(fontSize: 24),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_tracks.length} Songs • $totalDurationStr',
                                style: NewExperienceTokens.bodySmall(
                                  color: NewExperienceTokens.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildActionButtons(playerNotifier),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // ── Search & Track Filter Input ──
                  if (_tracks.length > 5)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: NewGlassContainer(
                          borderRadius: NewExperienceTokens.radiusMedium,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: TextField(
                            style: NewExperienceTokens.bodyMedium(),
                            decoration: InputDecoration(
                              hintText: 'Filter tracks in playlist...',
                              hintStyle: NewExperienceTokens.bodySmall(
                                color: NewExperienceTokens.textMuted,
                              ),
                              border: InputBorder.none,
                              prefixIcon: const Icon(
                                Icons.filter_list_rounded,
                                color: NewExperienceTokens.textMuted,
                                size: 20,
                              ),
                              prefixIconConstraints: const BoxConstraints(minWidth: 32),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onChanged: (val) => setState(() => _filterQuery = val),
                          ),
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // ── Tracks List ──
                  if (filteredTracks.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No songs found in this playlist',
                            style: NewExperienceTokens.bodyMedium(
                              color: NewExperienceTokens.textMuted,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = filteredTracks[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: NewMediaTile(
                              song: song,
                              index: index,
                              onTap: () {
                                playerNotifier.playSong(song, queue: filteredTracks, index: index);
                              },
                            ),
                          );
                        },
                        childCount: filteredTracks.length,
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
      ),
    );
  }

  Widget _buildCoverArt(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(NewExperienceTokens.radiusMedium),
        border: Border.all(color: NewExperienceTokens.specularBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NewExperienceTokens.radiusMedium),
        child: widget.playlist.image.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: widget.playlist.image,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const Icon(
                  Icons.album_rounded,
                  size: 48,
                  color: NewExperienceTokens.textMuted,
                ),
              )
            : const Icon(
                Icons.album_rounded,
                size: 48,
                color: NewExperienceTokens.textMuted,
              ),
      ),
    );
  }

  Widget _buildActionButtons(AudioPlayerNotifier playerNotifier) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Play All Button
        NewActionButton(
          label: 'Play',
          icon: Icons.play_arrow_rounded,
          onPressed: () {
            if (_tracks.isNotEmpty) {
              playerNotifier.playSong(_tracks.first, queue: _tracks, index: 0);
            }
          },
        ),

        // Shuffle Button
        NewActionButton(
          label: 'Shuffle',
          icon: Icons.shuffle_rounded,
          variant: NewActionButtonVariant.glass,
          onPressed: () {
            if (_tracks.isNotEmpty) {
              final shuffled = List<Song>.from(_tracks)..shuffle();
              playerNotifier.playSong(shuffled.first, queue: shuffled, index: 0);
            }
          },
        ),
      ],
    );
  }
}
