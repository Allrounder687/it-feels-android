import 'package:it_feels_music/views/widgets/custom_image_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/lyrics_provider.dart';
import '../../providers/video_player_provider.dart';
import '../lyrics/lyrics_screen.dart';
import '../room/room_bottom_sheet.dart';
import '../widgets/bouncy_icon_button.dart';
import '../widgets/song_options_sheet.dart';
import '../widgets/wavy_seek_bar.dart';
import 'queue_bottom_sheet.dart';
import 'sleep_timer_sheet.dart';
import '../home/driving_mode_screen.dart';
import '../widgets/animated_play_pause_button.dart';
import '../../providers/settings_provider.dart';
import '../video/video_player_screen.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AudioPlayerProvider, DownloadProvider>(
      builder: (context, playerProvider, downloadProvider, child) {
        final currentSong = playerProvider.currentSong;
        final bgColor = playerProvider.themeBackgroundColor;
        final surfaceColor = playerProvider.themeSurfaceColor;
        final accentColor = playerProvider.themeAccentColor;

        if (currentSong == null) {
          return Scaffold(
            backgroundColor: context.themeBackgroundColor,
            body: Center(
              child: Text(
                "No song selected",
                style: GoogleFonts.inter(color: context.themeMutedTextColor),
              ),
            ),
          );
        }

        final isFav = playerProvider.isFavorite(currentSong.id);
        final isDown = downloadProvider.isDownloaded(currentSong.id);
        final isDownloading = downloadProvider.isDownloading(currentSong.id);
        final settingsProvider = Provider.of<SettingsProvider>(context);

        return Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null) {
                  if (details.primaryVelocity! > 150) {
                    Navigator.pop(context); // Swipe down to close
                  } else if (details.primaryVelocity! < -150) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const QueueBottomSheet(),
                    );
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 700;
                    final artSize = isWide 
                        ? (constraints.maxWidth * 0.45).clamp(200.0, constraints.maxHeight * 0.75)
                        : (constraints.maxWidth * 0.82).clamp(150.0, constraints.maxHeight * 0.35);

                    final topAppBar = Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.themeTextColor, size: 32),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text(
                          "Now Playing",
                          style: GoogleFonts.inter(
                            color: context.themeTextColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: surfaceColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.directions_car_filled_rounded, color: context.themeTextColor, size: 24),
                              ),
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const DrivingModeScreen()));
                              },
                              tooltip: 'Driving Mode',
                            ),
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: surfaceColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  playerProvider.isSleepTimerActive || playerProvider.sleepAfterCurrentTrack
                                      ? Icons.bedtime_rounded
                                      : Icons.bedtime_outlined,
                                  color: playerProvider.isSleepTimerActive || playerProvider.sleepAfterCurrentTrack
                                      ? accentColor
                                      : context.themeTextColor,
                                  size: 24,
                                ),
                              ),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => const SleepTimerSheet(),
                                );
                              },
                            ),
                            // Removed redundant download icon from top app bar to fix layout overflow
                            if (settingsProvider.enableMusicVideos)
                              IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                                  ),
                                  child: Icon(Icons.video_library_rounded, color: accentColor, size: 24),
                                ),
                                onPressed: () {
                                  Provider.of<VideoPlayerProvider>(context, listen: false).playVideo(
                                    currentSong.id.contains(':') ? currentSong.id : 'search:${currentSong.id}', // Use search marker if it's a saavn ID
                                    currentSong.title,
                                    currentSong.artist,
                                    query: '${currentSong.title} ${currentSong.artist}',
                                  );
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const VideoPlayerScreen(),
                                    ),
                                  );
                                },
                              ),
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: surfaceColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.more_vert_rounded, color: context.themeTextColor, size: 24),
                              ),
                              onPressed: () {
                                SongOptionsSheet.show(context, currentSong);
                              },
                            ),
                          ],
                        ),
                      ],
                    );

                    final albumArt = Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: PulseGlowBackground(
                            color: accentColor,
                            isPlaying: playerProvider.isPlaying,
                          ),
                        ),
                        Hero(
                          tag: 'cover_${currentSong.id}',
                          child: Container(
                            width: artSize,
                            height: artSize,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(isWide ? 40 : 28),
                              boxShadow: [
                                BoxShadow(
                                  color: context.themeInvertedTextColor.withValues(alpha: 0.5),
                                  blurRadius: isWide ? 50 : 30,
                                  offset: Offset(0, isWide ? 25 : 15),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(isWide ? 40 : 28),
                              child: currentSong.coverArt.isNotEmpty
                                  ? CustomImageWidget(
                                      imageUrl: currentSong.coverArt,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) => Container(color: surfaceColor),
                                    )
                                  : Container(color: surfaceColor),
                            ),
                          ),
                        ),
                      ],
                    );

                    final songInfo = Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentSong.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: isWide ? 36 : 24,
                              fontWeight: FontWeight.w800,
                              color: context.themeTextColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentSong.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: isWide ? 18 : 15,
                              fontWeight: FontWeight.w500,
                              color: context.themeMutedTextColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              (currentSong.streamUrl?.toLowerCase().endsWith('.flac') ?? false) || (currentSong.streamUrl?.toLowerCase().endsWith('.alac') ?? false)
                                  ? 'LOSSLESS'
                                  : (currentSong.streamUrl?.toLowerCase().endsWith('.wav') ?? false)
                                      ? 'HIGH-RES'
                                      : '320 KBPS',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.amber,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );

                    final actionPills = SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => playerProvider.toggleFavorite(currentSong),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: surfaceColor.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: isFav ? Colors.pinkAccent : context.themeMutedTextColor,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isFav ? "Liked" : "Like",
                                    style: GoogleFonts.inter(
                                      color: context.themeTextColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () async {
                              if (isDown) {
                                await downloadProvider.removeDownload(currentSong);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Removed ${currentSong.title} from downloads")),
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Downloading ${currentSong.title}...")),
                                );
                                final ok = await downloadProvider.downloadSong(currentSong);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(ok ? "Downloaded ${currentSong.title}" : "Download failed")),
                                  );
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: surfaceColor.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                children: [
                                  isDownloading
                                      ? SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: context.themeTextColor),
                                        )
                                      : Icon(
                                          isDown ? Icons.download_done_rounded : Icons.file_download_outlined,
                                          color: isDown ? accentColor : context.themeMutedTextColor,
                                          size: 22,
                                        ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isDown ? "Downloaded" : "Download",
                                    style: GoogleFonts.inter(
                                      color: context.themeTextColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const LyricsScreen()),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: surfaceColor.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.lyrics_outlined, color: context.themeMutedTextColor, size: 22),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Lyrics",
                                    style: GoogleFonts.inter(
                                      color: context.themeTextColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );

                    final seekBar = WavySeekBar(
                      position: playerProvider.position,
                      duration: playerProvider.duration,
                      activeColor: accentColor,
                      inactiveColor: context.themeTextColor24,
                      onSeek: (newPos) => playerProvider.seek(newPos),
                    );

                    final timeStamps = Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(playerProvider.position),
                            style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12),
                          ),
                          Text(
                            _formatDuration(playerProvider.duration),
                            style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12),
                          ),
                        ],
                      ),
                    );

                    final primaryControls = Container(
                      height: isWide ? 90 : 80,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(isWide ? 45 : 40),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          BouncyIconButton(
                            child: Icon(Icons.replay_10_rounded, color: context.themeMutedTextColor, size: isWide ? 32 : 28),
                            onPressed: () => playerProvider.seekBackward(),
                          ),
                          BouncyIconButton(
                            child: Icon(Icons.skip_previous_rounded, color: context.themeTextColor, size: isWide ? 42 : 36),
                            onPressed: () => playerProvider.skipToPrevious(),
                          ),
                          BouncyIconButton(
                            onPressed: () => playerProvider.togglePlayPause(),
                            padding: EdgeInsets.zero,
                            child: Container(
                              width: isWide ? 72 : 62,
                              height: isWide ? 72 : 62,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: accentColor,
                                shape: BoxShape.circle,
                              ),
                              child: AnimatedPlayPauseButton(
                                isPlaying: playerProvider.isPlaying,
                                onPressed: () => playerProvider.togglePlayPause(),
                                color: context.themeInvertedTextColor,
                                size: isWide ? 44 : 38,
                              ),
                            ),
                          ),
                          BouncyIconButton(
                            child: Icon(Icons.skip_next_rounded, color: context.themeTextColor, size: isWide ? 42 : 36),
                            onPressed: () => playerProvider.skipToNext(),
                          ),
                          BouncyIconButton(
                            child: Icon(Icons.forward_10_rounded, color: context.themeMutedTextColor, size: isWide ? 32 : 28),
                            onPressed: () => playerProvider.seekForward(),
                          ),
                        ],
                      ),
                    );

                    final secondaryControls = Padding(
                      padding: EdgeInsets.symmetric(horizontal: isWide ? 20 : 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          BouncyIconButton(
                            child: Icon(
                              Icons.cell_tower_rounded, 
                              color: playerProvider.isInRoom ? Colors.greenAccent : context.themeMutedTextColor, 
                              size: 24,
                            ),
                            onPressed: () {
                              if (playerProvider.isInRoom && playerProvider.isHost) {
                                RoomBottomSheet.show(context, isHost: true);
                              } else if (!playerProvider.isInRoom) {
                                RoomBottomSheet.show(context, isHost: true);
                              } else {
                                // Guest trying to broadcast? 
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('You are already listening to a broadcast.'))
                                );
                              }
                            },
                          ),
                          BouncyIconButton(
                            child: Icon(
                              Icons.shuffle_rounded, 
                              color: playerProvider.isShuffle ? accentColor : context.themeMutedTextColor, 
                              size: 24,
                            ),
                            onPressed: () => playerProvider.toggleShuffle(),
                          ),
                          BouncyIconButton(
                            child: Icon(Icons.queue_music_rounded, color: context.themeMutedTextColor, size: 24),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const QueueBottomSheet(),
                              );
                            },
                          ),
                          BouncyIconButton(
                            child: Icon(
                              playerProvider.isRepeat ? Icons.repeat_one_rounded : Icons.repeat_rounded, 
                              color: playerProvider.isRepeat ? accentColor : context.themeMutedTextColor, 
                              size: 24,
                            ),
                            onPressed: () => playerProvider.toggleRepeat(),
                          ),
                        ],
                      ),
                    );

                    final bottomDragHandle = GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const QueueBottomSheet(),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: context.themeMutedTextColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Your queue",
                              style: GoogleFonts.inter(
                                color: context.themeTextColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    if (isWide) {
                      return Column(
                        children: [
                          topAppBar,
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32.0),
                                      child: albumArt,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 40),
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      songInfo,
                                      const SizedBox(height: 24),
                                      actionPills,
                                      const SizedBox(height: 32),
                                      seekBar,
                                      timeStamps,
                                      const SizedBox(height: 24),
                                      primaryControls,
                                      const SizedBox(height: 24),
                                      secondaryControls,
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    // Mobile Layout
                    return Column(
                      children: [
                        topAppBar,
                        const Spacer(),
                        albumArt,
                        const Spacer(),
                        songInfo,
                        const SizedBox(height: 16),
                        actionPills,
                        const SizedBox(height: 18),
                        seekBar,
                        timeStamps,
                        const SizedBox(height: 16),
                        primaryControls,
                        const SizedBox(height: 16),
                        secondaryControls,
                        const Spacer(),
                        bottomDragHandle,
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class PulseGlowBackground extends StatefulWidget {
  final Color color;
  final bool isPlaying;

  const PulseGlowBackground({super.key, required this.color, required this.isPlaying});

  @override
  State<PulseGlowBackground> createState() => _PulseGlowBackgroundState();
}

class _PulseGlowBackgroundState extends State<PulseGlowBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    if (widget.isPlaying) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PulseGlowBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.15 + (_controller.value * 0.15)),
                blurRadius: 80 + (_controller.value * 60),
                spreadRadius: 20 + (_controller.value * 30),
              ),
            ],
          ),
        );
      },
    );
  }
}
