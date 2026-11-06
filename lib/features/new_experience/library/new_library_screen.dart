import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/new_ambient_canvas.dart';
import '../widgets/new_section_header.dart';
import '../widgets/new_glass_container.dart';
import '../widgets/new_media_tile.dart';
import '../playlist/new_playlist_detail_screen.dart';

class NewLibraryScreen extends ConsumerStatefulWidget {
  const NewLibraryScreen({super.key});

  @override
  ConsumerState<NewLibraryScreen> createState() => _NewLibraryScreenState();
}

class _NewLibraryScreenState extends ConsumerState<NewLibraryScreen> {
  String _activeTab = 'All';
  final List<String> _tabs = ['All', 'Playlists', 'Liked Songs', 'Downloads'];

  void _showCreatePlaylistDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NewExperienceTokens.midnightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NewExperienceTokens.radiusLarge),
          side: BorderSide(color: NewExperienceTokens.specularBorder),
        ),
        title: Text(
          'Create Playlist',
          style: NewExperienceTokens.sectionTitle(fontSize: 18),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: NewExperienceTokens.bodyMedium(),
          decoration: InputDecoration(
            hintText: 'My Playlist #1',
            hintStyle: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: NewExperienceTokens.specularBorder),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: NewExperienceTokens.accentViolet,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final title = textController.text.trim();
              if (title.isNotEmpty) {
                ref.read(customPlaylistProvider.notifier).createPlaylist(title);
                Navigator.pop(context);
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlistState = ref.watch(customPlaylistProvider);
    final downloadState = ref.watch(downloadProvider);
    final playerState = ref.watch(audioPlayerProvider);
    final playerNotifier = ref.read(audioPlayerProvider.notifier);

    final likedSongs = playerState.favoriteSongs;
    final downloadedSongs = downloadState.downloadedSongs;

    return NewAmbientCanvas(
      intensity: 0.3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header & Title ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 18, bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YOUR COLLECTION',
                            style: NewExperienceTokens.eyebrowLabel(
                              color: NewExperienceTokens.accentCyan,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your Library',
                            style: NewExperienceTokens.displayHero(fontSize: 28),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Rescan Storage',
                            icon: const Icon(
                              Icons.sync_rounded,
                              color: NewExperienceTokens.textSecondary,
                              size: 22,
                            ),
                            onPressed: () {
                              ref.read(downloadProvider.notifier).scanAndSync();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Storage scan completed'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            tooltip: 'Create Playlist',
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: NewExperienceTokens.accentViolet,
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            onPressed: _showCreatePlaylistDialog,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Filter Chips ──
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    scrollDirection: Axis.horizontal,
                    itemCount: _tabs.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final tab = _tabs[index];
                      final isSelected = _activeTab == tab;

                      return InkWell(
                        onTap: () => setState(() => _activeTab = tab),
                        borderRadius: BorderRadius.circular(18),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? NewExperienceTokens.accentViolet
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected ? Colors.transparent : NewExperienceTokens.specularBorder,
                            ),
                          ),
                          child: Text(
                            tab,
                            style: NewExperienceTokens.bodySmall(
                              color: isSelected ? Colors.white : NewExperienceTokens.textSecondary,
                            ).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── Liked Songs Hero Banner (if All or Liked Songs) ──
              if (_activeTab == 'All' || _activeTab == 'Liked Songs') ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: InkWell(
                      onTap: () {
                        final playlist = Playlist(
                          id: 'favorites_playlist',
                          title: 'Liked Songs',
                          subtitle: '${likedSongs.length} Songs',
                          image: likedSongs.isNotEmpty ? likedSongs.first.image : '',
                          songCount: likedSongs.length,
                        );
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => NewPlaylistDetailScreen(
                              playlist: playlist,
                              staticTracks: likedSongs,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        height: 110,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4C1D95), Color(0xFF1E1B4B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4C1D95).withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Liked Songs',
                                  style: NewExperienceTokens.sectionTitle(fontSize: 22),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${likedSongs.length} Favorite Tracks',
                                  style: NewExperienceTokens.bodySmall(
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                              child: const Icon(
                                Icons.favorite_rounded,
                                color: NewExperienceTokens.accentRose,
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Downloaded Tracks Shelf ──
              if ((_activeTab == 'All' || _activeTab == 'Downloads') && downloadedSongs.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Downloaded Music (${downloadedSongs.length})',
                      eyebrow: 'OFFLINE READY',
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = downloadedSongs[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: NewMediaTile(
                          song: song,
                          index: index,
                          onTap: () => playerNotifier.playSong(song),
                        ),
                      );
                    },
                    childCount: downloadedSongs.take(15).length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Custom User Playlists ──
              if (_activeTab == 'All' || _activeTab == 'Playlists') ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NewSectionHeader(
                      title: 'Your Playlists (${playlistState.playlists.length})',
                      eyebrow: 'CREATED BY YOU',
                      actionLabel: '+ New',
                      onAction: _showCreatePlaylistDialog,
                    ),
                  ),
                ),
                if (playlistState.playlists.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.playlist_add_rounded,
                              size: 40,
                              color: NewExperienceTokens.textMuted,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No custom playlists yet',
                              style: NewExperienceTokens.bodyMedium(
                                color: NewExperienceTokens.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap the + button to create your first playlist.',
                              style: NewExperienceTokens.captionMuted(),
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
                        final pl = playlistState.playlists[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          child: InkWell(
                            onTap: () {
                              final playlist = Playlist(
                                id: pl.id,
                                title: pl.title,
                                subtitle: '${pl.songs.length} Tracks',
                                image: pl.songs.isNotEmpty ? pl.songs.first.image : '',
                                songCount: pl.songs.length,
                              );
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => NewPlaylistDetailScreen(
                                    playlist: playlist,
                                    staticTracks: pl.songs,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: NewGlassContainer(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: NewExperienceTokens.midnightSurface,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: pl.songs.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: CachedNetworkImage(
                                              imageUrl: pl.songs.first.image,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.music_note_rounded,
                                            color: NewExperienceTokens.accentViolet,
                                          ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pl.title,
                                          style: NewExperienceTokens.bodyMedium().copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${pl.songs.length} Songs • Playlist',
                                          style: NewExperienceTokens.captionMuted(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: NewExperienceTokens.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: playlistState.playlists.length,
                    ),
                  ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }
}
