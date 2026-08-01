import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/features/library/download_provider.dart';
import 'package:it_feels_music/features/player/video_player_provider.dart';
import 'package:it_feels_music/features/subscription/subscription_provider.dart';
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
import 'package:video_player/video_player.dart';
import 'package:video_player/video_player.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/features/cast/cast_service.dart' as it_feels_music_cast_service;
import 'package:it_feels_music/features/cast/cast_bottom_sheet.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  bool _isVideoMode = false;
  String? _lastPlayedSongId;



  Future<void> _toggleMode(bool toVideo, AudioPlayerState audioProvider, VideoPlayerState videoProvider, SettingsState settingsProv) async {
    if (_isVideoMode == toVideo) return;
    final currentSong = audioProvider.currentSong;
    if (currentSong == null) return;

    setState(() {
      _isVideoMode = toVideo;
    });

    if (toVideo) {
      // Switching to video
      final position = audioProvider.position;
      final useVideoAudio = settingsProv.useVideoAudioSource;
      
      if (useVideoAudio) {
        ref.read(audioPlayerProvider.notifier).pause();
        ref.read(videoPlayerProvider.notifier).setMuted(false);
      } else {
        // Keep high quality audio playing from music player!
        ref.read(videoPlayerProvider.notifier).setMuted(true);
        ref.read(audioPlayerProvider.notifier).seek(position);
        if (!audioProvider.isPlaying) {
          ref.read(audioPlayerProvider.notifier).play();
        }
      }
      
      ref.read(videoPlayerProvider.notifier).setOnVideoStarted(() {
        if (_isVideoMode && !settingsProv.useVideoAudioSource) {
          if (!audioProvider.isPlaying) {
            ref.read(audioPlayerProvider.notifier).play();
          }
        }
      });

      ref.read(videoPlayerProvider.notifier).playVideo(
        currentSong.id.contains(':') ? currentSong.id : 'search:${currentSong.id}',
        currentSong.title,
        currentSong.artist,
        query: BackendApiService.cleanSearchQuery(currentSong.title, currentSong.artist),
        startPosition: position,
      );
    } else {
      // Switching to audio
      final useVideoAudio = settingsProv.useVideoAudioSource;
      if (useVideoAudio) {
        final position = videoProvider.videoController?.value.position;
        if (position != null && position > Duration.zero) {
          ref.read(audioPlayerProvider.notifier).seek(position);
        }
      }
      videoProvider.videoController?.pause();
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

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _isVideoMode = false;
              });
              final settingsProv = ref.read(settingsProvider);
              // Trigger background load without switching UI
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
        }

        final isFav = playerProvider.isFavorite(currentSong.id);
        final isDown = downloadProviderLocal.isDownloaded(currentSong.id);
        final isDownloading = downloadProviderLocal.isDownloading(currentSong.id);

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
                        Builder(
                          builder: (context) {
                            final settingsProv = ref.read(settingsProvider);
                            return Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => _toggleMode(false, ref.read(audioPlayerProvider), videoProvider, settingsProv),
                                    child: Container(
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
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _isVideoMode ? accentColor : Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: (! _isVideoMode && videoProvider.videoController != null && videoProvider.videoController!.value.isInitialized)
                                            ? [BoxShadow(color: accentColor.withValues(alpha: 0.8), blurRadius: 10, spreadRadius: 2)]
                                            : null,
                                      ),
                                      child: Text(
                                        'Video',
                                        style: GoogleFonts.inter(
                                          color: _isVideoMode || (videoProvider.videoController != null && videoProvider.videoController!.value.isInitialized) 
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
                        Flexible(
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              ShaderMask(
                                shaderCallback: (Rect bounds) {
                                  return const LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [Colors.transparent, Colors.black, Colors.black],
                                    stops: [0.0, 0.15, 1.0],
                                  ).createShader(bounds);
                                },
                                blendMode: BlendMode.dstIn,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  reverse: true,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 18),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        BouncyIconButton(
                                          onPressed: () {
                                            Navigator.push(context, MaterialPageRoute(builder: (_) => const DrivingModeScreen()));
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: surfaceColor,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(Icons.directions_car_filled_rounded, color: context.themeTextColor, size: 24),
                                          ),
                                          tooltip: 'Driving Mode',
                                        ),
                                        BouncyIconButton(
                                          onPressed: () {
                                            showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              backgroundColor: Colors.transparent,
                                              builder: (_) => const SleepTimerSheet(),
                                            );
                                          },
                                          child: Container(
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
                                          tooltip: 'Sleep Timer',
                                        ),
                                        BouncyIconButton(
                                          onPressed: () {
                                            final current = playerProvider.currentVibe;
                                            if (current == AudioVibe.normal) {
                                              ref.read(audioPlayerProvider.notifier).setAudioVibe(AudioVibe.slowedReverb);
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🌙 Slowed + Reverb'), duration: Duration(seconds: 1)));
                                            } else if (current == AudioVibe.slowedReverb) {
                                              ref.read(audioPlayerProvider.notifier).setAudioVibe(AudioVibe.nightcore);
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚡ Nightcore (Sped Up)'), duration: Duration(seconds: 1)));
                                            } else {
                                              ref.read(audioPlayerProvider.notifier).setAudioVibe(AudioVibe.normal);
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎵 Normal Audio'), duration: Duration(seconds: 1)));
                                            }
                                          },
                                          tooltip: 'Audio Vibes',
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: surfaceColor,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              playerProvider.currentVibe == AudioVibe.normal
                                                  ? Icons.graphic_eq
                                                  : playerProvider.currentVibe == AudioVibe.slowedReverb
                                                      ? Icons.nightlight_round
                                                      : Icons.bolt,
                                              color: playerProvider.currentVibe == AudioVibe.normal
                                                  ? context.themeTextColor
                                                  : accentColor,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                        BouncyIconButton(
                                          onPressed: () {
                                            _showCastBottomSheet(context);
                                          },
                                          tooltip: 'Cast Audio',
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: surfaceColor,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              locator<it_feels_music_cast_service.CastService>().isConnected ? Icons.cast_connected_rounded : Icons.cast_rounded,
                                              color: locator<it_feels_music_cast_service.CastService>().isConnected ? accentColor : context.themeTextColor,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                        BouncyIconButton(
                                          onPressed: () {
                                            SongOptionsSheet.show(context, currentSong);
                                          },
                                          tooltip: 'Options',
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: surfaceColor,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(Icons.more_vert_rounded, color: context.themeTextColor, size: 24),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: surfaceColor.withValues(alpha: 0.8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.chevron_left_rounded,
                                    size: 14,
                                    color: context.themeMutedTextColor.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                            aspectRatio: (videoProvider.videoController != null && videoProvider.videoController!.value.isInitialized)
                                ? videoProvider.videoController!.value.aspectRatio
                                : 16 / 9,
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
                                        : videoProvider.videoController != null && videoProvider.videoController!.value.isInitialized
                                          ? VideoPlayer(videoProvider.videoController!)
                                          : Center(child: Text('Video unavailable', style: GoogleFonts.inter(color: Colors.white))),
                                    ),
                                    if (videoProvider.videoController != null && videoProvider.videoController!.value.isInitialized)
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
                          ),
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
                            onTap: () => ref.read(audioPlayerProvider.notifier).toggleFavorite(currentSong),
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

                    Widget buildProgress() {
                      if (_isVideoMode && videoProvider.videoController != null) {
                        return ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: videoProvider.videoController!,
                          builder: (context, value, child) {
                            return Column(
                              children: [
                                WavySeekBar(
                                  position: value.position,
                                  duration: value.duration,
                                  activeColor: accentColor,
                                  inactiveColor: context.themeTextColor24,
                                  onSeek: (newPos) {
                                    videoProvider.videoController?.seekTo(newPos);
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
                                        _formatDuration(value.position),
                                        style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12),
                                      ),
                                      Text(
                                        _formatDuration(value.duration),
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
                            onPressed: () {
                              final settingsProv = ref.read(settingsProvider);
                              if (_isVideoMode) {
                                final pos = videoProvider.videoController?.value.position ?? Duration.zero;
                                final newPos = pos - const Duration(seconds: 10);
                                videoProvider.videoController?.seekTo(newPos);
                                if (!settingsProv.useVideoAudioSource) {
                                  ref.read(audioPlayerProvider.notifier).seek(newPos);
                                }
                              } else {
                                ref.read(audioPlayerProvider.notifier).seekBackward();
                              }
                            },
                          ),
                          BouncyIconButton(
                            child: Icon(Icons.skip_previous_rounded, color: context.themeTextColor, size: isWide ? 42 : 36),
                            onPressed: () {
                              ref.read(audioPlayerProvider.notifier).skipToPrevious();
                            },
                          ),
                          BouncyIconButton(
                            onPressed: () {
                              final settingsProv = ref.read(settingsProvider);
                              if (_isVideoMode) {
                                final ctrl = videoProvider.videoController;
                                if (ctrl != null) {
                                  if (ctrl.value.isPlaying) {
                                    ctrl.pause();
                                    if (!settingsProv.useVideoAudioSource) {
                                      ref.read(audioPlayerProvider.notifier).pause();
                                    }
                                  } else {
                                    ctrl.play();
                                    if (!settingsProv.useVideoAudioSource) {
                                      ref.read(audioPlayerProvider.notifier).seek(ctrl.value.position);
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
                              width: isWide ? 72 : 62,
                              height: isWide ? 72 : 62,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: accentColor,
                                shape: BoxShape.circle,
                              ),
                              child: _isVideoMode && videoProvider.videoController != null
                                ? ValueListenableBuilder<VideoPlayerValue>(
                                    valueListenable: videoProvider.videoController!,
                                    builder: (context, value, child) {
                                      final settingsProv = ref.read(settingsProvider);
                                      return AnimatedPlayPauseButton(
                                        isPlaying: value.isPlaying,
                                        onPressed: () {
                                          if (value.isPlaying) {
                                            videoProvider.videoController!.pause();
                                            if (!settingsProv.useVideoAudioSource) {
                                              ref.read(audioPlayerProvider.notifier).pause();
                                            }
                                          } else {
                                            videoProvider.videoController!.play();
                                            if (!settingsProv.useVideoAudioSource) {
                                              ref.read(audioPlayerProvider.notifier).seek(value.position);
                                              ref.read(audioPlayerProvider.notifier).play();
                                            }
                                          }
                                        },
                                        color: context.themeInvertedTextColor,
                                        size: isWide ? 44 : 38,
                                      );
                                    }
                                  )
                                : AnimatedPlayPauseButton(
                                    isPlaying: playerProvider.isPlaying,
                                    onPressed: () => ref.read(audioPlayerProvider.notifier).togglePlayPause(),
                                    color: context.themeInvertedTextColor,
                                    size: isWide ? 44 : 38,
                                  ),
                            ),
                          ),
                          BouncyIconButton(
                            child: Icon(Icons.skip_next_rounded, color: context.themeTextColor, size: isWide ? 42 : 36),
                            onPressed: () {
                              ref.read(audioPlayerProvider.notifier).skipToNext();
                            },
                          ),
                          BouncyIconButton(
                            child: Icon(Icons.forward_10_rounded, color: context.themeMutedTextColor, size: isWide ? 32 : 28),
                            onPressed: () {
                              final settingsProv = ref.read(settingsProvider);
                              if (_isVideoMode) {
                                final pos = videoProvider.videoController?.value.position ?? Duration.zero;
                                final newPos = pos + const Duration(seconds: 10);
                                videoProvider.videoController?.seekTo(newPos);
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
                            onPressed: () => ref.read(audioPlayerProvider.notifier).toggleShuffle(),
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
                                    child: SingleChildScrollView(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          songInfo,
                                          const SizedBox(height: 24),
                                          actionPills,
                                          const SizedBox(height: 32),
                                          buildProgress(),
                                          const SizedBox(height: 24),
                                          primaryControls,
                                          const SizedBox(height: 24),
                                          secondaryControls,
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
                    final dynamicSpacer = SizedBox(height: screenHeight * 0.02);

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            topAppBar,
                            dynamicSpacer,
                            albumArt,
                            dynamicSpacer,
                            songInfo,
                            const SizedBox(height: 12),
                            actionPills,
                            const SizedBox(height: 12),
                            buildProgress(),
                            const SizedBox(height: 6),
                            primaryControls,
                            const SizedBox(height: 12),
                            secondaryControls,
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
