import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/data/services/audio_engine_service.dart';
import 'package:it_feels_music/features/player/video_player_provider.dart';
import 'package:it_feels_music/features/settings/settings_provider.dart';
import 'package:it_feels_music/services/backend_api_service.dart';
import 'package:it_feels_music/features/subscription/paywall_bottom_sheet.dart';
import 'package:it_feels_music/features/player/lyrics_screen.dart';
import 'package:it_feels_music/features/social/room_bottom_sheet.dart';
import 'package:it_feels_music/core/widgets/bouncy_icon_button.dart';
import 'package:it_feels_music/core/widgets/song_options_sheet.dart';
import 'package:it_feels_music/core/widgets/wavy_seek_bar.dart';
import 'package:it_feels_music/features/player/queue_bottom_sheet.dart';
import 'package:it_feels_music/features/player/sleep_timer_sheet.dart';
import 'package:it_feels_music/core/widgets/animated_play_pause_button.dart';
import 'package:it_feels_music/features/player/fullscreen_video_screen.dart';
import 'package:it_feels_music/features/home/driving_mode_screen.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/features/cast/cast_service.dart' as it_feels_music_cast_service;
import 'package:it_feels_music/features/cast/cast_bottom_sheet.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/models/song_model.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  bool _isVideoMode = false;
  String? _lastPlayedSongId;
  bool _hasViewedVideoForCurrentSong = false;

  @override
  void initState() {
    super.initState();
    // Initialize into video mode if the miniplayer was tapped while a video was active!
    final videoProvider = ref.read(videoPlayerProvider);
    final audioProvider = ref.read(audioPlayerProvider);
    if (videoProvider.isVideoActive && videoProvider.currentVideoId != null && audioProvider.currentSong != null) {
      final vId = videoProvider.currentVideoId!;
      final sId = audioProvider.currentSong!.id;
      if (vId == sId || vId == 'search:$sId') {
        _isVideoMode = true;
        _hasViewedVideoForCurrentSong = true;
        _lastPlayedSongId = sId; // Prevent build() from resetting to false!
      }
    }
  }

  Future<void> _toggleMode(bool toVideo, AudioPlayerState audioProvider, VideoPlayerState videoProvider, SettingsState settingsProv) async {
    if (_isVideoMode == toVideo) return;
    final currentSong = audioProvider.currentSong;
    if (currentSong == null) return;

    setState(() {
      _isVideoMode = toVideo;
      if (toVideo) {
        _hasViewedVideoForCurrentSong = true;
      }
    });

    if (toVideo) {
      // Switching to video
      final position = audioProvider.position;
      final useVideoAudio = settingsProv.useVideoAudioSource;
      
      if (useVideoAudio) {
        ref.read(videoPlayerProvider.notifier).setMuted(false);
      } else {
        // Keep high quality audio playing from music player!
        ref.read(videoPlayerProvider.notifier).setMuted(true);
      }
      
      ref.read(videoPlayerProvider.notifier).setOnVideoStarted(() {
        if (_isVideoMode) {
          if (settingsProv.useVideoAudioSource) {
            // Video is ready, now we can pause the audio to handoff!
            ref.read(audioPlayerProvider.notifier).pause();
          }
          // If NOT using video audio, audio is already playing uninterrupted, do nothing!
        }
      });

      ref.read(videoPlayerProvider.notifier).playVideo(
        currentSong.id.contains(':') ? currentSong.id : 'search:${currentSong.id}',
        currentSong.title,
        currentSong.artist,
        query: BackendApiService.cleanSearchQuery(currentSong.title, currentSong.artist),
        startPosition: position,
        isBackgroundHandoff: true,
      );
    } else {
      // Switching to audio
      final useVideoAudio = settingsProv.useVideoAudioSource;
      if (useVideoAudio) {
        final position = videoProvider.player?.state.position;
        if (position != null && position > Duration.zero) {
          ref.read(audioPlayerProvider.notifier).seek(position);
        }
      }
      videoProvider.player?.pause();
      if (!audioProvider.isPlaying) {
        ref.read(audioPlayerProvider.notifier).play();
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showQualityPickerBottomSheet(BuildContext context, VideoPlayerState videoProvider) {
    if (videoProvider.streams.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.themeSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.hd_rounded, color: context.themeTextColor, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Select Video Quality',
                    style: GoogleFonts.plusJakartaSans(
                      color: context.themeTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: videoProvider.streams.length,
                  itemBuilder: (context, index) {
                    final stream = videoProvider.streams[index];
                    final quality = stream['quality'] as String;
                    final isSelected = quality == videoProvider.selectedQuality;

                    return ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: isSelected ? context.themeAccentColor.withValues(alpha: 0.15) : Colors.transparent,
                      title: Text(
                        quality,
                        style: GoogleFonts.inter(
                          color: isSelected ? context.themeAccentColor : context.themeTextColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: context.themeAccentColor) : null,
                      onTap: () {
                        ref.read(videoPlayerProvider.notifier).changeQuality(quality);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPlayerOptionsMenu(BuildContext context) {
    final playerProvider = ref.read(audioPlayerProvider);
    final currentSong = playerProvider.currentSong;
    final accentColor = playerProvider.themeAccentColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.themeSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: context.themeMutedTextColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.directions_car_filled_rounded, color: context.themeTextColor),
                  title: Text('Driving Mode', style: GoogleFonts.inter(color: context.themeTextColor, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DrivingModeScreen()));
                  },
                ),
                ListTile(
                  leading: Icon(
                    playerProvider.isSleepTimerActive || playerProvider.sleepAfterCurrentTrack
                        ? Icons.bedtime_rounded
                        : Icons.bedtime_outlined,
                    color: playerProvider.isSleepTimerActive || playerProvider.sleepAfterCurrentTrack
                        ? accentColor
                        : context.themeTextColor,
                  ),
                  title: Text('Sleep Timer', style: GoogleFonts.inter(color: context.themeTextColor, fontWeight: FontWeight.w600)),
                  trailing: playerProvider.isSleepTimerActive
                      ? Text('Active', style: GoogleFonts.inter(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold))
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const SleepTimerSheet(),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    playerProvider.currentVibe == AudioVibe.normal
                        ? Icons.graphic_eq
                        : playerProvider.currentVibe == AudioVibe.slowedReverb
                            ? Icons.nightlight_round
                            : Icons.bolt,
                    color: playerProvider.currentVibe == AudioVibe.normal
                        ? context.themeTextColor
                        : accentColor,
                  ),
                  title: Text('Audio Vibes', style: GoogleFonts.inter(color: context.themeTextColor, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    playerProvider.currentVibe == AudioVibe.slowedReverb
                        ? '🌙 Slowed + Reverb'
                        : playerProvider.currentVibe == AudioVibe.nightcore
                            ? '⚡ Nightcore (Sped Up)'
                            : '🎵 Normal Audio',
                    style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12),
                  ),
                  onTap: () {
                    final current = playerProvider.currentVibe;
                    if (current == AudioVibe.normal) {
                      ref.read(audioPlayerProvider.notifier).setAudioVibe(AudioVibe.slowedReverb);
                    } else if (current == AudioVibe.slowedReverb) {
                      ref.read(audioPlayerProvider.notifier).setAudioVibe(AudioVibe.nightcore);
                    } else {
                      ref.read(audioPlayerProvider.notifier).setAudioVibe(AudioVibe.normal);
                    }
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: Icon(
                    locator<it_feels_music_cast_service.CastService>().isConnected ? Icons.cast_connected_rounded : Icons.cast_rounded,
                    color: locator<it_feels_music_cast_service.CastService>().isConnected ? accentColor : context.themeTextColor,
                  ),
                  title: Text('Cast Audio', style: GoogleFonts.inter(color: context.themeTextColor, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _showCastBottomSheet(context);
                  },
                ),
                if (currentSong != null)
                  ListTile(
                    leading: Icon(Icons.more_horiz_rounded, color: context.themeTextColor),
                    title: Text('More Options', style: GoogleFonts.inter(color: context.themeTextColor, fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      SongOptionsSheet.show(context, currentSong);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        ref.listen(audioPlayerProvider.select((p) => p.position), (previous, next) {
          final song = ref.read(audioPlayerProvider).currentSong;
          if (song != null) {
            ref.read(lyricsProvider.notifier).loadLyricsIfNeeded(song, next);
          }
        });

        final playerProvider = ref.watch(audioPlayerProvider);
        final downloadProviderLocal = ref.watch(downloadProvider);
        final videoProvider = ref.watch(videoPlayerProvider);

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

        if (_isVideoMode && currentSong.id != _lastPlayedSongId) {
          _lastPlayedSongId = currentSong.id;
          _hasViewedVideoForCurrentSong = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _isVideoMode = false;
              });
              final settingsProv = ref.read(settingsProvider);
              ref.read(videoPlayerProvider.notifier).playVideo(
                currentSong.id.contains(':') ? currentSong.id : 'search:${currentSong.id}',
                currentSong.title,
                currentSong.artist,
                query: BackendApiService.cleanSearchQuery(currentSong.title, currentSong.artist),
                startPosition: ref.read(audioPlayerProvider).position,
              );
            }
          });
        } else if (currentSong.id != _lastPlayedSongId) {
          _lastPlayedSongId = currentSong.id;
          _hasViewedVideoForCurrentSong = false;
        }

        final isFav = playerProvider.isFavorite(currentSong.id);
        final isDown = downloadProviderLocal.isDownloaded(currentSong.id);
        final isDownloading = downloadProviderLocal.isDownloading(currentSong.id);

        final queue = playerProvider.queue;
        final currentIndex = playerProvider.currentIndex;
        final nextSong = (queue.isNotEmpty && currentIndex + 1 < queue.length)
            ? queue[currentIndex + 1]
            : null;

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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 700;
                    final artSize = isWide 
                        ? (constraints.maxWidth * 0.45).clamp(200.0, constraints.maxHeight * 0.75)
                        : (constraints.maxWidth * 0.78).clamp(140.0, constraints.maxHeight * 0.34);

                    // Redesigned 3-Zone Clean Header Bar
                    final topAppBar = Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.themeTextColor, size: 30),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Close Player',
                        ),
                        // Glassmorphic Segmented Toggle (Song / Video)
                        Builder(
                          builder: (context) {
                            final settingsProv = ref.read(settingsProvider);
                            return Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: surfaceColor.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => _toggleMode(false, ref.read(audioPlayerProvider), videoProvider, settingsProv),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: !_isVideoMode ? accentColor : Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'Song',
                                        style: GoogleFonts.inter(
                                          color: !_isVideoMode ? context.themeInvertedTextColor : context.themeMutedTextColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _toggleMode(true, ref.read(audioPlayerProvider), videoProvider, settingsProv),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _isVideoMode ? accentColor : Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: (!_isVideoMode && !_hasViewedVideoForCurrentSong && videoProvider.videoController != null)
                                            ? [BoxShadow(color: accentColor.withValues(alpha: 0.8), blurRadius: 10, spreadRadius: 2)]
                                            : null,
                                      ),
                                      child: Text(
                                        'Video',
                                        style: GoogleFonts.inter(
                                          color: _isVideoMode || (videoProvider.videoController != null) 
                                              ? context.themeInvertedTextColor : context.themeMutedTextColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        // Top Right Menu Overflow Button
                        IconButton(
                          icon: Icon(Icons.more_vert_rounded, color: context.themeTextColor, size: 26),
                          onPressed: () => _showPlayerOptionsMenu(context),
                          tooltip: 'Options',
                        ),
                      ],
                    );

                    final albumArt = AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: _isVideoMode 
                        ? AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Container(
                              key: const ValueKey('video_player'),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: videoProvider.isLoading 
                                        ? Center(child: CircularProgressIndicator(color: accentColor))
                                        : videoProvider.videoController != null
                                          ? ExcludeSemantics(
                                              child: Video(
                                                controller: videoProvider.videoController!,
                                                controls: NoVideoControls,
                                                fill: Colors.black,
                                              ),
                                            )
                                          : Center(child: Text('Video unavailable', style: GoogleFonts.inter(color: Colors.white))),
                                    ),
                                    if (videoProvider.videoController != null)
                                      Positioned(
                                        right: 8,
                                        bottom: 8,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Downloading video for ${currentSong.title}...'),
                                                    behavior: SnackBarBehavior.floating,
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.65),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.file_download_rounded, color: Colors.white, size: 16),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () {
                                                _showQualityPickerBottomSheet(context, videoProvider);
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.65),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  videoProvider.selectedQuality,
                                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => FullscreenVideoScreen(song: currentSong),
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.65),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 20),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : Stack(
                            key: const ValueKey('audio_art'),
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
                                    borderRadius: BorderRadius.circular(isWide ? 36 : 24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.themeInvertedTextColor.withValues(alpha: 0.35),
                                        blurRadius: isWide ? 40 : 24,
                                        offset: Offset(0, isWide ? 20 : 12),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(isWide ? 36 : 24),
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
                          ),
                    );

                    final songInfo = Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          currentSong.title,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: isWide ? 32 : 22,
                            fontWeight: FontWeight.w800,
                            color: context.themeTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                currentSong.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: isWide ? 16 : 14,
                                  fontWeight: FontWeight.w500,
                                  color: context.themeMutedTextColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Inlined Sleek Audio Quality Tag
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                (currentSong.streamUrl?.toLowerCase().endsWith('.flac') ?? false) || (currentSong.streamUrl?.toLowerCase().endsWith('.alac') ?? false)
                                    ? 'LOSSLESS'
                                    : (currentSong.streamUrl?.toLowerCase().endsWith('.wav') ?? false)
                                        ? 'HIGH-RES'
                                        : '320 KBPS',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.amber,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );

                    // Redesigned Glassmorphic Action Row
                    final actionPills = SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => ref.read(audioPlayerProvider.notifier).toggleFavorite(currentSong),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: surfaceColor.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: isFav ? Colors.pinkAccent : context.themeMutedTextColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isFav ? "Liked" : "Like",
                                    style: GoogleFonts.inter(
                                      color: context.themeTextColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () async {
                              if (isDown) {
                                await ref.read(downloadProvider.notifier).removeDownload(currentSong);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Removed ${currentSong.title} from downloads")),
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Downloading ${currentSong.title}...")),
                                );
                                final ok = await ref.read(downloadProvider.notifier).downloadSong(currentSong);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(ok ? "Downloaded ${currentSong.title}" : "Download failed")),
                                  );
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: surfaceColor.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Row(
                                children: [
                                  isDownloading
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: context.themeTextColor),
                                        )
                                      : Icon(
                                          isDown ? Icons.download_done_rounded : Icons.file_download_outlined,
                                          color: isDown ? accentColor : context.themeMutedTextColor,
                                          size: 18,
                                        ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isDown ? "Downloaded" : "Download",
                                    style: GoogleFonts.inter(
                                      color: context.themeTextColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              final sub = ref.read(subscriptionProvider);
                              if (sub.isPremium) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const LyricsScreen()),
                                );
                              } else {
                                PaywallBottomSheet.show(context, featureName: "Lyrics");
                              }
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: surfaceColor.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.lyrics_outlined, color: context.themeMutedTextColor, size: 18),
                                  const SizedBox(width: 5),
                                  Text(
                                    "Lyrics",
                                    style: GoogleFonts.inter(
                                      color: context.themeTextColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // New Share Button Pill
                          InkWell(
                            onTap: () {
                              Share.share(
                                'Listening to "${currentSong.title}" by ${currentSong.artist} on It Feels Music! 🎶',
                                subject: 'Check out this song',
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: surfaceColor.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.share_outlined, color: context.themeMutedTextColor, size: 18),
                                  const SizedBox(width: 5),
                                  Text(
                                    "Share",
                                    style: GoogleFonts.inter(
                                      color: context.themeTextColor,
                                      fontSize: 13,
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

                    Widget buildProgress() {
                      if (_isVideoMode && videoProvider.videoController != null) {
                        return StreamBuilder<Duration>(
                          stream: videoProvider.player!.stream.position,
                          builder: (context, snapshot) {
                            final position = snapshot.data ?? videoProvider.player!.state.position;
                            final duration = videoProvider.player!.state.duration;
                            return Column(
                              children: [
                                WavySeekBar(
                                  position: position,
                                  duration: duration,
                                  activeColor: accentColor,
                                  inactiveColor: context.themeTextColor24,
                                  onSeek: (newPos) {
                                    videoProvider.player?.seek(newPos);
                                    final settingsProv = ref.read(settingsProvider);
                                    if (!settingsProv.useVideoAudioSource) {
                                      ref.read(audioPlayerProvider.notifier).seek(newPos);
                                    }
                                  },
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(position),
                                        style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12),
                                      ),
                                      Text(
                                        _formatDuration(duration),
                                        style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }
                        );
                      }

                      return StreamBuilder<Duration>(
                        stream: ref.read(audioPlayerProvider.notifier).audioHandler.player.positionStream,
                        initialData: playerProvider.position,
                        builder: (context, snapshot) {
                          final currentPos = snapshot.data ?? playerProvider.position;
                          return Column(
                            children: [
                              WavySeekBar(
                                position: currentPos,
                                duration: playerProvider.duration,
                                activeColor: accentColor,
                                inactiveColor: context.themeTextColor24,
                                onSeek: (newPos) => ref.read(audioPlayerProvider.notifier).seek(newPos),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(currentPos),
                                      style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12),
                                    ),
                                    Text(
                                      _formatDuration(playerProvider.duration),
                                      style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    }

                    // Redesigned Adaptive Acrylic Control Capsule
                    final primaryControls = Container(
                      height: isWide ? 86 : 74,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: surfaceColor.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(isWide ? 43 : 37),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          BouncyIconButton(
                            child: Icon(Icons.replay_10_rounded, color: context.themeMutedTextColor, size: isWide ? 30 : 26),
                            onPressed: () {
                              final settingsProv = ref.read(settingsProvider);
                              if (_isVideoMode) {
                                final pos = videoProvider.player?.state.position ?? Duration.zero;
                                final newPos = pos - const Duration(seconds: 10);
                                videoProvider.player?.seek(newPos);
                                if (!settingsProv.useVideoAudioSource) {
                                  ref.read(audioPlayerProvider.notifier).seek(newPos);
                                }
                              } else {
                                ref.read(audioPlayerProvider.notifier).seekBackward();
                              }
                            },
                          ),
                          BouncyIconButton(
                            child: Icon(Icons.skip_previous_rounded, color: context.themeTextColor, size: isWide ? 40 : 34),
                            onPressed: () {
                              ref.read(audioPlayerProvider.notifier).skipToPrevious();
                            },
                          ),
                          // Glowing Accent Play/Pause Button
                          BouncyIconButton(
                            onPressed: () {
                              final settingsProv = ref.read(settingsProvider);
                              if (_isVideoMode) {
                                final player = videoProvider.player;
                                if (player != null) {
                                  if (player.state.playing) {
                                    player.pause();
                                    if (!settingsProv.useVideoAudioSource) {
                                      ref.read(audioPlayerProvider.notifier).pause();
                                    }
                                  } else {
                                    player.play();
                                    if (!settingsProv.useVideoAudioSource) {
                                      ref.read(audioPlayerProvider.notifier).seek(player.state.position);
                                      ref.read(audioPlayerProvider.notifier).play();
                                    }
                                  }
                                  setState(() {});
                                }
                              } else {
                                ref.read(audioPlayerProvider.notifier).togglePlayPause();
                              }
                            },
                            padding: EdgeInsets.zero,
                            child: Container(
                              width: isWide ? 68 : 56,
                              height: isWide ? 68 : 56,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: accentColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: _isVideoMode && videoProvider.player != null
                                ? StreamBuilder<bool>(
                                    stream: videoProvider.player!.stream.playing,
                                    builder: (context, snapshot) {
                                      final isPlaying = snapshot.data ?? videoProvider.player!.state.playing;
                                      return IgnorePointer(
                                        child: AnimatedPlayPauseButton(
                                          isPlaying: isPlaying,
                                          onPressed: () {},
                                          color: context.themeInvertedTextColor,
                                          size: isWide ? 40 : 32,
                                        ),
                                      );
                                    }
                                  )
                                : IgnorePointer(
                                    child: AnimatedPlayPauseButton(
                                      isPlaying: playerProvider.isPlaying,
                                      onPressed: () {},
                                      color: context.themeInvertedTextColor,
                                      size: isWide ? 40 : 32,
                                    ),
                                  ),
                            ),
                          ),
                          BouncyIconButton(
                            child: Icon(Icons.skip_next_rounded, color: context.themeTextColor, size: isWide ? 40 : 34),
                            onPressed: () {
                              ref.read(audioPlayerProvider.notifier).skipToNext();
                            },
                          ),
                          BouncyIconButton(
                            child: Icon(Icons.forward_10_rounded, color: context.themeMutedTextColor, size: isWide ? 30 : 26),
                            onPressed: () {
                              final settingsProv = ref.read(settingsProvider);
                              if (_isVideoMode) {
                                final pos = videoProvider.player?.state.position ?? Duration.zero;
                                final newPos = pos + const Duration(seconds: 10);
                                videoProvider.player?.seek(newPos);
                                if (!settingsProv.useVideoAudioSource) {
                                  ref.read(audioPlayerProvider.notifier).seek(newPos);
                                }
                              } else {
                                ref.read(audioPlayerProvider.notifier).seekForward();
                              }
                            },
                          ),
                        ],
                      ),
                    );

                    final secondaryControls = Padding(
                      padding: EdgeInsets.symmetric(horizontal: isWide ? 20 : 36),
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
                            onPressed: () => ref.read(audioPlayerProvider.notifier).toggleShuffle(),
                          ),
                          PopupMenuButton<double>(
                            icon: Icon(Icons.speed_rounded, color: context.themeMutedTextColor, size: 24),
                            initialValue: playerProvider.playbackSpeed,
                            onSelected: (speed) => ref.read(audioPlayerProvider.notifier).setPlaybackSpeed(speed),
                            itemBuilder: (context) {
                              return [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((s) {
                                return PopupMenuItem<double>(
                                  value: s,
                                  child: Text('${s}x', style: TextStyle(fontWeight: s == playerProvider.playbackSpeed ? FontWeight.bold : FontWeight.w500, fontSize: 14)),
                                );
                              }).toList();
                            },
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
                            onPressed: () => ref.read(audioPlayerProvider.notifier).toggleRepeat(),
                          ),
                        ],
                      ),
                    );

                    // Redesigned Up Next Queue Peek Handle
                    final bottomDragHandle = GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const QueueBottomSheet(),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: surfaceColor.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 32,
                              height: 4,
                              decoration: BoxDecoration(
                                color: context.themeMutedTextColor.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.keyboard_arrow_up_rounded, color: context.themeMutedTextColor, size: 16),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    nextSong != null
                                        ? "UP NEXT • ${nextSong.title}"
                                        : "YOUR QUEUE",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: context.themeTextColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );

                    // Live Lyrics Preview Card
                    final liveLyricsCard = _LiveLyricsPreviewCard(
                      song: currentSong,
                      position: playerProvider.position,
                      surfaceColor: surfaceColor,
                      accentColor: accentColor,
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
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        songInfo,
                                        const SizedBox(height: 16),
                                        actionPills,
                                        const SizedBox(height: 24),
                                        buildProgress(),
                                        const SizedBox(height: 16),
                                        primaryControls,
                                        const SizedBox(height: 16),
                                        secondaryControls,
                                        const SizedBox(height: 16),
                                        liveLyricsCard,
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    // Mobile Layout
                    final screenHeight = MediaQuery.of(context).size.height;
                    final dynamicSpacer = SizedBox(height: (screenHeight * 0.012).clamp(6.0, 16.0));

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          children: [
                            topAppBar,
                            dynamicSpacer,
                            albumArt,
                            dynamicSpacer,
                            songInfo,
                            const SizedBox(height: 8),
                            actionPills,
                            const SizedBox(height: 8),
                            buildProgress(),
                            const SizedBox(height: 6),
                            primaryControls,
                            const SizedBox(height: 8),
                            secondaryControls,
                            dynamicSpacer,
                            liveLyricsCard,
                            dynamicSpacer,
                            bottomDragHandle,
                          ],
                        ),
                      ),
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

  void _showCastBottomSheet(BuildContext context) {
    CastBottomSheet.show(context);
  }
}

class _LiveLyricsPreviewCard extends ConsumerWidget {
  final Song song;
  final Duration position;
  final Color surfaceColor;
  final Color accentColor;

  const _LiveLyricsPreviewCard({
    required this.song,
    required this.position,
    required this.surfaceColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyricsState = ref.watch(lyricsProvider);

    final lyricsResult = lyricsState.lyricsResult;
    final isLoading = lyricsState.isLoading;
    final isNotFound = lyricsState.lyricsNotFound;

    String prevLine = "";
    String currentLine = "";
    String nextLine = "";

    if (lyricsResult != null && lyricsResult.hasSynced) {
      final activeIdx = lyricsState.getActiveLineIndex(position);
      if (activeIdx >= 0 && activeIdx < lyricsResult.syncedLyrics.length) {
        if (activeIdx > 0) {
          prevLine = lyricsResult.syncedLyrics[activeIdx - 1].text;
        }
        currentLine = lyricsResult.syncedLyrics[activeIdx].text;
        if (activeIdx + 1 < lyricsResult.syncedLyrics.length) {
          nextLine = lyricsResult.syncedLyrics[activeIdx + 1].text;
        }
      }
    } else if (lyricsResult != null && lyricsResult.hasStatic && lyricsResult.staticLyrics != null) {
      final lines = lyricsResult.staticLyrics!.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isNotEmpty) currentLine = lines.first;
      if (lines.length > 1) nextLine = lines[1];
    }

    return GestureDetector(
      onTap: () {
        final sub = ref.read(subscriptionProvider);
        if (sub.isPremium) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LyricsScreen()),
          );
        } else {
          PaywallBottomSheet.show(context, featureName: "Lyrics");
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: surfaceColor.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.mic_rounded, color: accentColor, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE LYRICS',
                      style: GoogleFonts.inter(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'FULL SCREEN',
                      style: GoogleFonts.inter(
                        color: context.themeMutedTextColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.north_east_rounded, color: context.themeMutedTextColor, size: 12),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isLoading)
              Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Searching lyrics...',
                    style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 13),
                  ),
                ],
              )
            else if (isNotFound || currentLine.isEmpty)
              Text(
                'Tap to view lyrics & sing along 🎶',
                style: GoogleFonts.inter(
                  color: context.themeMutedTextColor,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              )
              else
                SizedBox(
                  height: 85, // Fixed height to prevent jumping
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      // Determines slide direction based on key entering/exiting
                      final slideIn = Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: slideIn,
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      key: ValueKey(currentLine),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (prevLine.isNotEmpty)
                          Text(
                            prevLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: context.themeMutedTextColor.withValues(alpha: 0.35),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (prevLine.isNotEmpty) const SizedBox(height: 3),
                        Text(
                          currentLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: context.themeTextColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            shadows: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                        ),
                        if (nextLine.isNotEmpty) const SizedBox(height: 3),
                        if (nextLine.isNotEmpty)
                          Text(
                            nextLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: context.themeMutedTextColor.withValues(alpha: 0.6),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
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
}

class PulseGlowBackground extends ConsumerStatefulWidget {
  final Color color;
  final bool isPlaying;

  const PulseGlowBackground({super.key, required this.color, required this.isPlaying});

  @override
  ConsumerState<PulseGlowBackground> createState() => _PulseGlowBackgroundState();
}

class _PulseGlowBackgroundState extends ConsumerState<PulseGlowBackground> with SingleTickerProviderStateMixin {
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
