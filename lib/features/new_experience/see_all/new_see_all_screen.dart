import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:window_manager/window_manager.dart';

import '../playlist/new_playlist_detail_screen.dart';
import '../theme/content_viewport_insets.dart';
import '../theme/new_ambient_canvas.dart';
import '../theme/new_experience_tokens.dart';
import '../widgets/new_card.dart';
import '../widgets/new_glass_container.dart';
import '../widgets/new_media_tile.dart';
import '../widgets/new_daily_mix_cover.dart';

enum NewSeeAllType { songs, playlists }

class NewSeeAllScreen extends ConsumerStatefulWidget {
  final String title;
  final String? eyebrow;
  final NewSeeAllType type;
  final List<Song>? songs;
  final List<Playlist>? playlists;

  const NewSeeAllScreen.songs({
    super.key,
    required this.title,
    this.eyebrow,
    required this.songs,
  })  : type = NewSeeAllType.songs,
        playlists = null;

  const NewSeeAllScreen.playlists({
    super.key,
    required this.title,
    this.eyebrow,
    required this.playlists,
  })  : type = NewSeeAllType.playlists,
        songs = null;

  @override
  ConsumerState<NewSeeAllScreen> createState() => _NewSeeAllScreenState();
}

class _NewSeeAllScreenState extends ConsumerState<NewSeeAllScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _playAll(List<Song> songList, {bool shuffle = false}) {
    if (songList.isEmpty) return;
    final playerNotifier = ref.read(audioPlayerProvider.notifier);
    final list = shuffle ? (List<Song>.from(songList)..shuffle()) : songList;
    playerNotifier.playSong(list.first, queue: list, index: 0);
    if (shuffle) {
      final isShuffle = ref.read(audioPlayerProvider).isShuffle;
      if (!isShuffle) {
        playerNotifier.toggleShuffle();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerNotifier = ref.read(audioPlayerProvider.notifier);

    // Filter items based on user query
    final filteredSongs = widget.songs != null
        ? widget.songs!.where((s) {
            if (_query.isEmpty) return true;
            final q = _query.toLowerCase();
            return s.title.toLowerCase().contains(q) ||
                s.artist.toLowerCase().contains(q) ||
                s.album.toLowerCase().contains(q);
          }).toList()
        : <Song>[];

    final filteredPlaylists = widget.playlists != null
        ? widget.playlists!.where((p) {
            if (_query.isEmpty) return true;
            final q = _query.toLowerCase();
            return p.title.toLowerCase().contains(q) ||
                p.subtitle.toLowerCase().contains(q);
          }).toList()
        : <Playlist>[];

    final totalCount = widget.type == NewSeeAllType.songs
        ? filteredSongs.length
        : filteredPlaylists.length;

    return NewAmbientCanvas(
      intensity: 0.35,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux))
              ? const DragToMoveArea(
                  child: SizedBox(
                    height: 48,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox.shrink(),
                    ),
                  ),
                )
              : null,
        ),
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Hero Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 4, bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.eyebrow != null) ...[
                        Text(
                          widget.eyebrow!.toUpperCase(),
                          style: NewExperienceTokens.eyebrowLabel(
                            color: NewExperienceTokens.accentCyan,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              style: NewExperienceTokens.displayHero(fontSize: 26),
                            ),
                          ),
                          Text(
                            '$totalCount ${widget.type == NewSeeAllType.songs ? "tracks" : "collections"}',
                            style: NewExperienceTokens.captionMuted(
                              color: NewExperienceTokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Action Bar: Search & Transport ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    children: [
                      // Search Filter Bar
                      NewGlassContainer(
                        borderRadius: 14,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: TextField(
                          controller: _searchController,
                          style: NewExperienceTokens.bodyMedium(),
                          decoration: InputDecoration(
                            hintText: 'Filter ${widget.title.toLowerCase()}...',
                            hintStyle: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
                            border: InputBorder.none,
                            prefixIcon: const Icon(Icons.search, size: 18, color: NewExperienceTokens.textMuted),
                            suffixIcon: _query.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16, color: NewExperienceTokens.textMuted),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (val) => setState(() => _query = val.trim()),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Transport Play / Shuffle Action Pills (for Songs)
                      if (widget.type == NewSeeAllType.songs && filteredSongs.isNotEmpty)
                        Row(
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: NewExperienceTokens.accentViolet,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              onPressed: () => _playAll(filteredSongs, shuffle: false),
                              icon: const Icon(Icons.play_arrow_rounded, size: 20),
                              label: Text(
                                'Play All',
                                style: NewExperienceTokens.bodySmall(color: Colors.white)
                                    .copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: NewExperienceTokens.specularBorder),
                                backgroundColor: Colors.white.withValues(alpha: 0.05),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () => _playAll(filteredSongs, shuffle: true),
                              icon: const Icon(Icons.shuffle_rounded, size: 18, color: NewExperienceTokens.accentCyan),
                              label: Text(
                                'Shuffle',
                                style: NewExperienceTokens.bodySmall(color: Colors.white)
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 10)),

              // ── Content: Songs List ──
              if (widget.type == NewSeeAllType.songs) ...[
                if (filteredSongs.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          _query.isNotEmpty ? 'No tracks match "$_query"' : 'No tracks found in this collection',
                          style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = filteredSongs[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: NewMediaTile(
                            song: song,
                            index: index,
                            onTap: () => playerNotifier.playSong(
                              song,
                              queue: filteredSongs,
                              index: index,
                            ),
                          ),
                        );
                      },
                      childCount: filteredSongs.length,
                    ),
                  ),
              ],

              // ── Content: Playlists / Albums Grid ──
              if (widget.type == NewSeeAllType.playlists) ...[
                if (filteredPlaylists.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          _query.isNotEmpty ? 'No collections match "$_query"' : 'No collections available',
                          style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.72,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final pl = filteredPlaylists[index];
                          final sub = pl.songCount > 0
                              ? '${pl.songCount} Tracks'
                              : (pl.customSubtitle ?? 'Collection');

                          final isDailyMix = pl.id.startsWith('daily_mix_');
                          final mixIdx = isDailyMix ? (int.tryParse(pl.id.split('_').last) ?? 1) : null;
                          final quadUrls = (pl.songs ?? [])
                              .map((s) => s.image)
                              .where((u) => u.isNotEmpty && !u.contains('404'))
                              .take(4)
                              .toList();

                          return NewCard(
                            title: pl.title,
                            subtitle: sub,
                            imageUrl: pl.image,
                            customArtwork: isDailyMix
                                ? NewDailyMixCover(
                                    mixIndex: mixIdx!,
                                    title: pl.title,
                                    subtitle: sub,
                                    quadImageUrls: quadUrls.isNotEmpty ? quadUrls : null,
                                    primaryImageUrl: pl.image.isNotEmpty ? pl.image : null,
                                  )
                                : null,
                            width: 160,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => NewPlaylistDetailScreen(
                                    playlist: pl,
                                    staticTracks: pl.songs,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        childCount: filteredPlaylists.length,
                      ),
                    ),
                  ),
              ],

              // Dynamic viewport clearance spacer
              ContentViewportInsets.sliverBottomSpacer(context, ref),
            ],
          ),
        ),
      ),
    );
  }
}
