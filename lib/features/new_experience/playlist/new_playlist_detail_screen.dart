import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/utils/string_utils.dart';
import 'package:it_feels_music/core/intelligence/playlists/dynamic_playlist_service.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/new_ambient_canvas.dart';
import '../widgets/new_media_tile.dart';
import '../widgets/new_action_button.dart';
import '../widgets/new_glass_container.dart';
import '../widgets/new_artwork_image.dart';
import '../widgets/new_daily_mix_cover.dart';
import '../theme/content_viewport_insets.dart';

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
  bool _isSelectionMode = false;
  final Set<String> _selectedSongIds = {};

  void _showRenameDialog(String currentTitle, String playlistId) {
    final textController = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NewExperienceTokens.midnightSurface,
        title: Text('Rename Playlist', style: NewExperienceTokens.sectionTitle(fontSize: 18)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: NewExperienceTokens.bodyMedium(),
          decoration: InputDecoration(
            hintText: 'Enter new title...',
            hintStyle: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NewExperienceTokens.accentViolet),
            onPressed: () {
              final newName = textController.text.trim();
              if (newName.isNotEmpty) {
                ref.read(customPlaylistProvider.notifier).renamePlaylist(playlistId, newName);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Renamed playlist to "$newName"')),
                );
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePlaylist(String playlistId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NewExperienceTokens.midnightSurface,
        title: Text('Delete Playlist?', style: NewExperienceTokens.sectionTitle(fontSize: 18)),
        content: Text('Are you sure you want to delete "$title"? This cannot be undone.', style: NewExperienceTokens.bodyMedium()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              ref.read(customPlaylistProvider.notifier).deletePlaylist(playlistId);
              Navigator.pop(ctx);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted playlist "$title"')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

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
    // 1. If static tracks or playlist.songs are already available
    if (widget.staticTracks != null && widget.staticTracks!.isNotEmpty) {
      if (mounted) setState(() { _tracks = List.from(widget.staticTracks!); _isLoading = false; });
      return;
    }
    if (widget.playlist.songs != null && widget.playlist.songs!.isNotEmpty) {
      if (mounted) setState(() { _tracks = List.from(widget.playlist.songs!); _isLoading = false; });
      return;
    }

    // 2. Handle Daily Mixes (daily_mix_1 ... daily_mix_6)
    if (widget.playlist.id.startsWith('daily_mix_')) {
      final youPlaylists = ref.read(homeProvider).youPlaylists;
      final match = youPlaylists.where((p) => p.id == widget.playlist.id).firstOrNull;
      if (match != null && match.songs != null && match.songs!.isNotEmpty) {
        if (mounted) {
          setState(() {
            _tracks = List.from(match.songs!);
            _isLoading = false;
          });
        }
        return;
      }

      // Check DynamicPlaylistService
      if (locator.isRegistered<DynamicPlaylistService>()) {
        try {
          final dynService = locator<DynamicPlaylistService>();
          final dyn = dynService.getPlaylist(widget.playlist.id);
          if (dyn != null && dyn.tracks.isNotEmpty) {
            if (mounted) {
              setState(() {
                _tracks = List.from(dyn.tracks);
                _isLoading = false;
              });
            }
            return;
          }
          final refreshed = await dynService.refreshPlaylist(widget.playlist.id);
          if (refreshed.tracks.isNotEmpty) {
            if (mounted) {
              setState(() {
                _tracks = List.from(refreshed.tracks);
                _isLoading = false;
              });
            }
            return;
          }
        } catch (e) {
          debugPrint('[NewPlaylistDetailScreen] Dynamic playlist lookup error: $e');
        }
      }

      // Seed search fallback for Daily Mixes
      try {
        final seedQueries = {
          'daily_mix_1': 'Bollywood Romantic Top Hits',
          'daily_mix_2': 'Today Top Hits International English',
          'daily_mix_3': 'Punjabi Top Hits 2026',
          'daily_mix_4': 'Hip Hop Hits Rap',
          'daily_mix_5': 'Acoustic Chill Indie Vibes',
          'daily_mix_6': 'Bollywood Dance Club Anthems',
        };
        final query = seedQueries[widget.playlist.id] ?? widget.playlist.title;
        final repo = locator<IMusicRepository>();
        final tracks = await repo.searchSongs(query, count: 25);
        if (mounted) {
          setState(() {
            _tracks = tracks;
            _isLoading = false;
          });
        }
        return;
      } catch (e) {
        debugPrint('[NewPlaylistDetailScreen] Seed query fallback error: $e');
      }
    }

    // 3. Regular playlist or album fetching
    try {
      final repo = locator<IMusicRepository>();
      List<Song> tracks = [];
      if (widget.playlist.type == 'album') {
        final albumData = await repo.fetchAlbumDetails(widget.playlist.id);
        tracks = List<Song>.from(albumData['songs'] ?? []);
      } else {
        tracks = await repo.getPlaylistTracks(widget.playlist.id);
        if (tracks.isEmpty) {
          final playlistData = await repo.fetchPlaylistDetails(widget.playlist.id);
          tracks = List<Song>.from(playlistData['songs'] ?? []);
        }
      }
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
    final customPlaylistState = ref.watch(customPlaylistProvider);
    final customPlaylist = customPlaylistState.playlists.where((p) => p.id == widget.playlist.id).firstOrNull;
    final isCustom = customPlaylist != null;
    final effectiveTracks = isCustom ? customPlaylist.songs : _tracks;
    final effectiveTitle = isCustom ? customPlaylist.title : widget.playlist.title;

    final filteredTracks = _filterQuery.isEmpty
        ? effectiveTracks
        : effectiveTracks
            .where((s) =>
                s.title.toLowerCase().contains(_filterQuery.toLowerCase()) ||
                s.artist.toLowerCase().contains(_filterQuery.toLowerCase()))
            .toList();

    final totalSeconds = effectiveTracks.fold<int>(0, (sum, s) => sum + s.duration);
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
            // Toggle Multi-Selection
            IconButton(
              tooltip: _isSelectionMode ? 'Cancel Selection' : 'Select Tracks',
              icon: Icon(
                _isSelectionMode ? Icons.check_circle_rounded : Icons.checklist_rounded,
                color: _isSelectionMode ? NewExperienceTokens.accentCyan : Colors.white,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _isSelectionMode = !_isSelectionMode;
                  _selectedSongIds.clear();
                });
              },
            ),
            if (isCustom)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                color: NewExperienceTokens.midnightSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: NewExperienceTokens.specularBorder),
                ),
                onSelected: (val) {
                  switch (val) {
                    case 'rename':
                      _showRenameDialog(effectiveTitle, customPlaylist.id);
                      break;
                    case 'duplicate':
                      ref.read(customPlaylistProvider.notifier).duplicatePlaylist(customPlaylist.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Duplicated "$effectiveTitle"')),
                      );
                      break;
                    case 'delete':
                      _confirmDeletePlaylist(customPlaylist.id, effectiveTitle);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18, color: Colors.white),
                        SizedBox(width: 10),
                        Text('Rename Playlist', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Row(
                      children: [
                        Icon(Icons.copy_rounded, size: 18, color: Colors.white),
                        SizedBox(width: 10),
                        Text('Duplicate Playlist', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                        SizedBox(width: 10),
                        Text('Delete Playlist', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
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
            : Stack(
                children: [
                  CustomScrollView(
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
                                          Text(isCustom ? 'CUSTOM PLAYLIST' : 'PLAYLIST', style: NewExperienceTokens.eyebrowLabel()),
                                          const SizedBox(height: 6),
                                          Text(
                                            effectiveTitle,
                                            style: NewExperienceTokens.displayHero(fontSize: 32),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${effectiveTracks.length} Songs • $totalDurationStr',
                                            style: NewExperienceTokens.bodySmall(
                                              color: NewExperienceTokens.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          _buildActionButtons(playerNotifier, effectiveTracks),
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
                                    effectiveTitle,
                                    textAlign: TextAlign.center,
                                    style: NewExperienceTokens.displayHero(fontSize: 24),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${effectiveTracks.length} Songs • $totalDurationStr',
                                    style: NewExperienceTokens.bodySmall(
                                      color: NewExperienceTokens.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildActionButtons(playerNotifier, effectiveTracks),
                                ],
                              );
                            },
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 16)),

                      // ── Search & Track Filter Input ──
                      if (effectiveTracks.length > 5)
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
                              final isSelected = _selectedSongIds.contains(song.id);

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  children: [
                                    if (_isSelectionMode)
                                      Checkbox(
                                        value: isSelected,
                                        activeColor: NewExperienceTokens.accentCyan,
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedSongIds.add(song.id);
                                            } else {
                                              _selectedSongIds.remove(song.id);
                                            }
                                          });
                                        },
                                      ),
                                    Expanded(
                                      child: NewMediaTile(
                                        song: song,
                                        index: index,
                                        onTap: _isSelectionMode
                                            ? () {
                                                setState(() {
                                                  if (isSelected) {
                                                    _selectedSongIds.remove(song.id);
                                                  } else {
                                                    _selectedSongIds.add(song.id);
                                                  }
                                                });
                                              }
                                            : () {
                                                playerNotifier.playSong(song, queue: filteredTracks, index: index);
                                              },
                                      ),
                                    ),
                                    if (isCustom && !_isSelectionMode)
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline_rounded, color: NewExperienceTokens.textMuted, size: 18),
                                        tooltip: 'Remove from playlist',
                                        onPressed: () {
                                          ref.read(customPlaylistProvider.notifier).removeSongFromPlaylist(customPlaylist.id, song.id);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Removed "${song.title}" from playlist')),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              );
                            },
                            childCount: filteredTracks.length,
                          ),
                        ),

                      // Dynamic bottom clearance
                      ContentViewportInsets.sliverBottomSpacer(context, ref),
                    ],
                  ),

                  // Floating Multi-Select Action Dock
                  if (_isSelectionMode && _selectedSongIds.isNotEmpty)
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: ContentViewportInsets.bottom(context, ref) + 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: NewExperienceTokens.midnightSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: NewExperienceTokens.accentCyan, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${_selectedSongIds.length} Selected',
                                  style: NewExperienceTokens.bodyMedium(
                                    color: NewExperienceTokens.accentCyan,
                                  ).copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      if (_selectedSongIds.length == filteredTracks.length) {
                                        _selectedSongIds.clear();
                                      } else {
                                        _selectedSongIds.addAll(filteredTracks.map((s) => s.id));
                                      }
                                    });
                                  },
                                  child: Text(
                                    _selectedSongIds.length == filteredTracks.length ? 'Deselect All' : 'Select All',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                if (isCustom)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                    tooltip: 'Remove selected from playlist',
                                    onPressed: () {
                                      ref.read(customPlaylistProvider.notifier).removeSongsBatch(customPlaylist.id, _selectedSongIds.toList());
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Removed ${_selectedSongIds.length} tracks')),
                                      );
                                      setState(() {
                                        _selectedSongIds.clear();
                                        _isSelectionMode = false;
                                      });
                                    },
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 20),
                                  tooltip: 'Add selected to queue',
                                  onPressed: () {
                                    final selectedSongs = effectiveTracks.where((s) => _selectedSongIds.contains(s.id)).toList();
                                    playerNotifier.addSongsToQueue(selectedSongs);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Added ${selectedSongs.length} tracks to queue')),
                                    );
                                    setState(() {
                                      _selectedSongIds.clear();
                                      _isSelectionMode = false;
                                    });
                                  },
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: NewExperienceTokens.accentCyan,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isSelectionMode = false;
                                      _selectedSongIds.clear();
                                    });
                                  },
                                  child: const Text('Done', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
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

  Widget _buildCoverArt(double size) {
    final isDailyMix = widget.playlist.id.startsWith('daily_mix_');
    final mixIdx = isDailyMix ? (int.tryParse(widget.playlist.id.split('_').last) ?? 1) : null;
    final activeTracks = _tracks.isNotEmpty ? _tracks : (widget.staticTracks ?? []);
    final quadUrls = activeTracks
        .map((s) => s.image)
        .where((u) => u.isNotEmpty && !u.contains('404'))
        .take(4)
        .toList();

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
      child: isDailyMix
          ? NewDailyMixCover(
              mixIndex: mixIdx!,
              title: widget.playlist.title,
              subtitle: widget.playlist.subtitle,
              quadImageUrls: quadUrls.isNotEmpty ? quadUrls : null,
              primaryImageUrl: widget.playlist.image.isNotEmpty ? widget.playlist.image : null,
              width: size,
              height: size,
              borderRadius: BorderRadius.circular(NewExperienceTokens.radiusMedium),
            )
          : NewArtworkImage(
              imageUrl: widget.playlist.image,
              width: size,
              height: size,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(NewExperienceTokens.radiusMedium),
              iconSize: 48,
              fallbackTitle: widget.playlist.title,
            ),
    );
  }

  Widget _buildActionButtons(AudioPlayerNotifier playerNotifier, List<Song> activeTracks) {
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
            if (activeTracks.isNotEmpty) {
              playerNotifier.playSong(activeTracks.first, queue: activeTracks, index: 0);
            }
          },
        ),

        // Shuffle Button
        NewActionButton(
          label: 'Shuffle',
          icon: Icons.shuffle_rounded,
          variant: NewActionButtonVariant.glass,
          onPressed: () {
            if (activeTracks.isNotEmpty) {
              playerNotifier.shufflePlayContext(activeTracks);
            }
          },
        ),

        // Play Next Button
        NewActionButton(
          label: 'Play Next',
          icon: Icons.playlist_play_rounded,
          variant: NewActionButtonVariant.glass,
          onPressed: () {
            if (activeTracks.isNotEmpty) {
              playerNotifier.playNextBatch(activeTracks);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Playing ${activeTracks.length} tracks next')),
              );
            }
          },
        ),

        // Add to Queue Button
        NewActionButton(
          label: 'Add to Queue',
          icon: Icons.queue_music_rounded,
          variant: NewActionButtonVariant.glass,
          onPressed: () {
            if (activeTracks.isNotEmpty) {
              playerNotifier.addSongsToQueue(activeTracks);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Added ${activeTracks.length} tracks to queue')),
              );
            }
          },
        ),
      ],
    );
  }
}
