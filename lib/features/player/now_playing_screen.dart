import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/data/services/audio_engine_service.dart';
import 'package:it_feels_music/features/player/video_player_provider.dart';
import 'package:it_feels_music/features/settings/settings_provider.dart';
import 'package:it_feels_music/services/backend_api_service.dart';
import 'package:it_feels_music/core/widgets/song_options_sheet.dart';
import 'package:it_feels_music/features/player/queue_bottom_sheet.dart';
import 'package:it_feels_music/features/player/sleep_timer_sheet.dart';
import 'package:it_feels_music/features/home/driving_mode_screen.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/widgets/glass_shield_wrapper.dart';
import 'package:it_feels_music/features/cast/cast_service.dart'
    as it_feels_music_cast_service;
import 'package:it_feels_music/features/cast/cast_bottom_sheet.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';

import 'package:it_feels_music/features/player/widgets/live_lyrics_preview_card.dart';
import 'package:it_feels_music/features/player/widgets/now_playing_header.dart';
import 'package:it_feels_music/features/player/widgets/now_playing_art.dart';
import 'package:it_feels_music/features/player/widgets/now_playing_info.dart';
import 'package:it_feels_music/features/player/widgets/now_playing_actions.dart';
import 'package:it_feels_music/features/player/widgets/now_playing_controls.dart';
import 'package:it_feels_music/features/player/widgets/now_playing_progress.dart';

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
    if (videoProvider.isVideoActive && audioProvider.currentSong != null) {
      final vId = videoProvider.currentVideoId;
      final sId = audioProvider.currentSong!.id;
      if (vId == sId || vId == 'search:$sId') {
        _isVideoMode = true;
        _hasViewedVideoForCurrentSong = true;
        _lastPlayedSongId = sId; // Prevent build() from resetting to false!
      }
    }
  }

  Future<void> _toggleMode(
    bool toVideo,
    AudioPlayerState audioProvider,
    VideoPlayerState videoProvider,
    SettingsState settingsProv,
  ) async {
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

      ref
          .read(videoPlayerProvider.notifier)
          .playVideo(
            currentSong.id.contains(':')
                ? currentSong.id
                : 'search:${currentSong.id}',
            currentSong.title,
            currentSong.artist,
            query: BackendApiService.cleanSearchQuery(
              currentSong.title,
              currentSong.artist,
            ),
            startPosition: position,
            isBackgroundHandoff: true,
            onToastMessage: (msg) {
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(msg)));
              }
            },
          );
    } else {
      // Switching to audio
      final useVideoAudio = settingsProv.useVideoAudioSource;
      if (useVideoAudio) {
        Duration? syncPosition = videoProvider.player?.state.position;
        if (syncPosition != null && syncPosition > Duration.zero) {
          final targetDuration = audioProvider.duration;
          final sourceDuration =
              videoProvider.player?.state.duration ?? Duration.zero;

          if (targetDuration > Duration.zero &&
              sourceDuration > Duration.zero) {
            final diffSeconds =
                (sourceDuration.inSeconds - targetDuration.inSeconds).abs();
            if (diffSeconds > 15) {
              syncPosition = Duration.zero;
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Different version detected. Starting from the beginning.",
                    ),
                  ),
                );
              }
            } else {
              final pct =
                  syncPosition.inMilliseconds / sourceDuration.inMilliseconds;
              syncPosition = Duration(
                milliseconds: (targetDuration.inMilliseconds * pct).toInt(),
              );
            }

            if (targetDuration.inSeconds > 2) {
              final maxDuration = targetDuration - const Duration(seconds: 2);
              if (syncPosition > maxDuration) syncPosition = maxDuration;
              if (syncPosition < Duration.zero) syncPosition = Duration.zero;
            }
          }
          ref.read(audioPlayerProvider.notifier).seek(syncPosition);
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
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _showQualityPickerBottomSheet(
    BuildContext context,
    VideoPlayerState videoProvider,
  ) {
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
                  Icon(
                    Icons.hd_rounded,
                    color: context.themeTextColor,
                    size: 24,
                  ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: isSelected
                          ? context.themeAccentColor.withValues(alpha: 0.15)
                          : Colors.transparent,
                      title: Text(
                        quality,
                        style: GoogleFonts.inter(
                          color: isSelected
                              ? context.themeAccentColor
                              : context.themeTextColor,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: context.themeAccentColor,
                            )
                          : null,
                      onTap: () {
                        ref
                            .read(videoPlayerProvider.notifier)
                            .changeQuality(quality);
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
                  leading: Icon(
                    Icons.directions_car_filled_rounded,
                    color: context.themeTextColor,
                  ),
                  title: Text(
                    'Driving Mode',
                    style: GoogleFonts.inter(
                      color: context.themeTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DrivingModeScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    playerProvider.isSleepTimerActive ||
                            playerProvider.sleepAfterCurrentTrack
                        ? Icons.bedtime_rounded
                        : Icons.bedtime_outlined,
                    color:
                        playerProvider.isSleepTimerActive ||
                            playerProvider.sleepAfterCurrentTrack
                        ? accentColor
                        : context.themeTextColor,
                  ),
                  title: Text(
                    'Sleep Timer',
                    style: GoogleFonts.inter(
                      color: context.themeTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: playerProvider.isSleepTimerActive
                      ? Text(
                          'Active',
                          style: GoogleFonts.inter(
                            color: accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        )
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
                  title: Text(
                    'Audio Vibes',
                    style: GoogleFonts.inter(
                      color: context.themeTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    playerProvider.currentVibe == AudioVibe.slowedReverb
                        ? '🌙 Slowed + Reverb'
                        : playerProvider.currentVibe == AudioVibe.nightcore
                        ? '⚡ Nightcore (Sped Up)'
                        : '🎵 Normal Audio',
                    style: GoogleFonts.inter(
                      color: context.themeMutedTextColor,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    final current = playerProvider.currentVibe;
                    if (current == AudioVibe.normal) {
                      ref
                          .read(audioPlayerProvider.notifier)
                          .setAudioVibe(AudioVibe.slowedReverb);
                    } else if (current == AudioVibe.slowedReverb) {
                      ref
                          .read(audioPlayerProvider.notifier)
                          .setAudioVibe(AudioVibe.nightcore);
                    } else {
                      ref
                          .read(audioPlayerProvider.notifier)
                          .setAudioVibe(AudioVibe.normal);
                    }
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: Icon(
                    locator<it_feels_music_cast_service.CastService>()
                            .isConnected
                        ? Icons.cast_connected_rounded
                        : Icons.cast_rounded,
                    color:
                        locator<it_feels_music_cast_service.CastService>()
                            .isConnected
                        ? accentColor
                        : context.themeTextColor,
                  ),
                  title: Text(
                    'Cast Audio',
                    style: GoogleFonts.inter(
                      color: context.themeTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showCastBottomSheet(context);
                  },
                ),
                if (currentSong != null)
                  ListTile(
                    leading: Icon(
                      Icons.more_horiz_rounded,
                      color: context.themeTextColor,
                    ),
                    title: Text(
                      'More Options',
                      style: GoogleFonts.inter(
                        color: context.themeTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
        ref.listen(audioPlayerProvider.select((p) => p.currentSong), (
          previous,
          next,
        ) {
          if (next != null) {
            ref.read(lyricsProvider.notifier).loadLyricsIfNeeded(next);
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
          return GlassShieldWrapper(
            isGlassMode: context.isGlassTheme,
            child: Scaffold(
              backgroundColor: context.themeBackgroundColor,
              body: Center(
              child: Text(
                "No song selected",
                style: GoogleFonts.inter(color: context.themeMutedTextColor),
              ),
            ),
          ));
        }

        if (currentSong.id != _lastPlayedSongId) {
          final isPodcast = currentSong.album == 'YouTube Podcast';
          _lastPlayedSongId = currentSong.id;
          _hasViewedVideoForCurrentSong = false;
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _isVideoMode = isPodcast;
              });
              
              final settingsProv = ref.read(settingsProvider);
              
              if (isPodcast) {
                if (settingsProv.useVideoAudioSource) {
                  ref.read(videoPlayerProvider.notifier).setMuted(false);
                } else {
                  ref.read(videoPlayerProvider.notifier).setMuted(true);
                }
                
                ref.read(videoPlayerProvider.notifier).setOnVideoStarted(() {
                  if (_isVideoMode && settingsProv.useVideoAudioSource) {
                    ref.read(audioPlayerProvider.notifier).pause();
                  }
                });
              }

              ref.read(videoPlayerProvider.notifier).playVideo(
                currentSong.id.contains(':')
                    ? currentSong.id
                    : 'search:${currentSong.id}',
                currentSong.title,
                currentSong.artist,
                query: BackendApiService.cleanSearchQuery(
                  currentSong.title,
                  currentSong.artist,
                ),
                startPosition: ref.read(audioPlayerProvider).position,
              );
            }
          });
        }

        final isFav = playerProvider.isFavorite(currentSong.id);
        final isDown = downloadProviderLocal.isDownloaded(currentSong.id);
        final isDownloading = downloadProviderLocal.isDownloading(
          currentSong.id,
        );

        final queue = playerProvider.queue;
        final currentIndex = playerProvider.currentIndex;
        final nextSong = (queue.isNotEmpty && currentIndex + 1 < queue.length)
            ? queue[currentIndex + 1]
            : null;

        return GlassShieldWrapper(
          isGlassMode: context.isGlassTheme,
          child: Scaffold(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 700;
                    final artSize = isWide
                        ? (constraints.maxWidth * 0.45).clamp(
                            200.0,
                            math
                                .max(200.0, constraints.maxHeight * 0.75)
                                .toDouble(),
                          )
                        : (constraints.maxWidth * 0.78).clamp(
                            140.0,
                            math
                                .max(140.0, constraints.maxHeight * 0.34)
                                .toDouble(),
                          );

                    // Redesigned 3-Zone Clean Header Bar
                    final topAppBar = NowPlayingHeader(
                      isVideoMode: _isVideoMode,
                      hasViewedVideoForCurrentSong:
                          _hasViewedVideoForCurrentSong,
                      surfaceColor: surfaceColor,
                      accentColor: accentColor,
                      onToggleMode: (toVideo) {
                        final settingsProv = ref.read(settingsProvider);
                        _toggleMode(
                          toVideo,
                          ref.read(audioPlayerProvider),
                          videoProvider,
                          settingsProv,
                        );
                      },
                      onOptionsTap: () => _showPlayerOptionsMenu(context),
                    );

                    final albumArt = NowPlayingArt(
                      isVideoMode: _isVideoMode,
                      isWide: isWide,
                      artSize: artSize,
                      currentSong: currentSong,
                      isPlaying: playerProvider.isPlaying,
                      surfaceColor: surfaceColor,
                      accentColor: accentColor,
                      onQualityPickerTap: () =>
                          _showQualityPickerBottomSheet(context, videoProvider),
                    );

                    final songInfo = NowPlayingInfo(
                      currentSong: currentSong,
                      isWide: isWide,
                    );

                    final actionPills = NowPlayingActions(
                      currentSong: currentSong,
                      isFav: isFav,
                      isDown: isDown,
                      isDownloading: isDownloading,
                      surfaceColor: surfaceColor,
                      accentColor: accentColor,
                    );

                    final progressWidget = NowPlayingProgress(
                      isVideoMode: _isVideoMode,
                      accentColor: accentColor,
                    );

                    final primaryControls = NowPlayingPrimaryControls(
                      isWide: isWide,
                      isVideoMode: _isVideoMode,
                      surfaceColor: surfaceColor,
                      accentColor: accentColor,
                    );

                    final secondaryControls = NowPlayingSecondaryControls(
                      isWide: isWide,
                      accentColor: accentColor,
                    );

                    final dragHandle = QueueDragHandle(
                      nextSong: nextSong,
                      surfaceColor: surfaceColor,
                    );

                    final liveLyricsCard = LiveLyricsPreviewCard(
                      song: currentSong,
                      surfaceColor: surfaceColor,
                      accentColor: accentColor,
                      isWide: isWide,
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
                                    child: Container(
                                      width: artSize,
                                      height: artSize,
                                      decoration: BoxDecoration(
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.3,
                                            ),
                                            blurRadius: 30,
                                            spreadRadius: 2,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: albumArt,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 40),
                                Expanded(
                                  flex: 5,
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        songInfo,
                                        const SizedBox(height: 16),
                                        actionPills,
                                        const SizedBox(height: 24),
                                        progressWidget,
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
                    final dynamicSpacer = SizedBox(
                      height: (screenHeight * 0.012).clamp(6.0, 16.0),
                    );

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
                            progressWidget,
                            const SizedBox(height: 6),
                            primaryControls,
                            const SizedBox(height: 8),
                            secondaryControls,
                            dynamicSpacer,
                            liveLyricsCard,
                            dynamicSpacer,
                            dragHandle,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ));
      },
    );
  }

  void _showCastBottomSheet(BuildContext context) {
    CastBottomSheet.show(context);
  }
}
