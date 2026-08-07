import 'dart:ui';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/core/widgets/skeleton_loading_list.dart';
import 'package:it_feels_music/features/library/download_provider.dart';
import 'package:it_feels_music/core/widgets/song_options_sheet.dart';
import 'package:it_feels_music/core/widgets/animated_equalizer.dart';
import 'package:it_feels_music/core/widgets/mini_player.dart';
import 'package:it_feels_music/features/player/now_playing_screen.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  bool _isLoading = true;
  String _title = '';
  String _coverArt = '';
  List<Song> _songs = [];

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (widget.playlist.songs != null && widget.playlist.songs!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _title = widget.playlist.title;
          _coverArt = widget.playlist.coverArt;
          _songs = widget.playlist.songs!;
          _isLoading = false;
        });
      }
      return;
    }

    final api = MusicApiService();
    Map<String, dynamic> data;

    if (widget.playlist.type == 'album') {
      data = await api.fetchAlbumDetails(widget.playlist.id);
    } else {
      data = await api.fetchPlaylistDetails(widget.playlist.id);
    }

    if (mounted) {
      setState(() {
        _title = data['name'] ?? widget.playlist.title;
        _coverArt = (data['image'] as String?)?.isNotEmpty == true
            ? data['image']
            : widget.playlist.coverArt;
        _songs = List<Song>.from(data['songs'] ?? []);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = ref.read(audioPlayerProvider);
    final downloadProv = ref.watch(downloadProvider);

    return Scaffold(
      backgroundColor: context.themeBackgroundColor,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            _isLoading
                ? const SkeletonLoadingList()
                : CustomScrollView(
                    slivers: [
                  // Immersive Dynamic Header
                  SliverAppBar(
                    expandedHeight: 340,
                    pinned: true,
                    backgroundColor: context.themeBackgroundColor,
                    leading: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.themeBackgroundColor.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_back, color: context.themeTextColor, size: 20),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    actions: [
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.themeBackgroundColor.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.file_download_outlined, color: context.themeTextColor, size: 20),
                        ),
                        tooltip: "Download All",
                        onPressed: () async {
                          if (_songs.isEmpty) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Downloading ${_songs.length} songs...")),
                          );
                          await ref.read(downloadProvider.notifier).downloadBatch(_songs);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Batch download completed!")),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    flexibleSpace: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final top = constraints.biggest.height;
                        final minHeight = MediaQuery.of(context).padding.top + kToolbarHeight;
                        final scrollPercent = ((top - minHeight) / (340 - minHeight)).clamp(0.0, 1.0);
                        final isCollapsed = top <= minHeight + 20;

                        return FlexibleSpaceBar(
                          titlePadding: const EdgeInsets.only(left: 64, right: 64, bottom: 16),
                          title: isCollapsed
                              ? Text(
                                  _title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: context.themeTextColor,
                                  ),
                                )
                              : const SizedBox.shrink(),
                          background: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Blurred Artwork Background
                              if (_coverArt.isNotEmpty)
                                ImageFiltered(
                                  imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                                  child: CustomImageWidget(
                                    imageUrl: _coverArt,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              Positioned.fill(
                                child: Container(color: context.themeBackgroundColor.withValues(alpha: 0.6)),
                              ),
                              // Foreground Artwork and Text (Fades out when scrolling up)
                              Opacity(
                                opacity: scrollPercent,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      width: 180,
                                      height: 180,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            blurRadius: 30,
                                            offset: const Offset(0, 15),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: _coverArt.isNotEmpty
                                            ? CustomImageWidget(imageUrl: _coverArt, fit: BoxFit.cover)
                                            : Container(color: context.themeCardColor),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      child: Text(
                                        _title,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          color: context.themeTextColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${_songs.length} Tracks",
                                      style: GoogleFonts.inter(
                                        color: context.themeMutedTextColor,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Play and Shuffle Buttons Apple Music Style
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.themeCardColor.withValues(alpha: 0.8),
                                foregroundColor: context.themeTextColor,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: Icon(Icons.play_arrow_rounded, size: 24, color: context.themeAccentColor),
                              label: Text("Play", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                              onPressed: () {
                                if (_songs.isNotEmpty) ref.read(audioPlayerProvider.notifier).playSong(_songs[0], queue: _songs, index: 0);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.themeCardColor.withValues(alpha: 0.8),
                                foregroundColor: context.themeTextColor,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: Icon(Icons.shuffle_rounded, size: 20, color: context.themeAccentColor),
                              label: Text("Shuffle", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                              onPressed: () {
                                if (_songs.isNotEmpty) {
                                  final shuffled = List<Song>.from(_songs)..shuffle();
                                  ref.read(audioPlayerProvider.notifier).playSong(shuffled[0], queue: shuffled, index: 0);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Songs List
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = _songs[index];
                        final isDown = downloadProv.isDownloaded(song.id);

                        return Consumer(builder: (context, ref, child) { final playerProvider = ref.watch(audioPlayerProvider); 
                            final isCurrentSong = playerProvider.currentSong?.id == song.id;

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          child: Material(
                            color: context.themeCardColor.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: song.coverArt.isNotEmpty
                                      ? CustomImageWidget(
                                          imageUrl: song.coverArt,
                                          fit: BoxFit.cover,
                                        )
                                      : Icon(Icons.music_note, color: context.themeTextColor),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      song.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: isCurrentSong ? context.themeAccentColor : context.themeTextColor,
                                        fontWeight: isCurrentSong ? FontWeight.w800 : FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (isDown) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.download_done_rounded, color: context.themeAccentColor, size: 16),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: context.themeMutedTextColor,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: isCurrentSong && playerProvider.isPlaying
                                  ? Padding(
                                      padding: const EdgeInsets.only(right: 12.0),
                                      child: AnimatedEqualizer(color: context.themeAccentColor),
                                    )
                                  : IconButton(
                                      icon: Icon(Icons.more_vert, color: context.themeMutedTextColor),
                                      onPressed: () {
                                        SongOptionsSheet.show(context, song, playlistContext: _songs);
                                      },
                                    ),
                              onTap: () {
                                ref.read(audioPlayerProvider.notifier).playSong(song, queue: _songs, index: index);
                              },
                              onLongPress: () {
                                SongOptionsSheet.show(context, song, playlistContext: _songs);
                              },
                            ),
                          ),
                        );
                          },
                        );
                      },
                      childCount: _songs.length,
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
