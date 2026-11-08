import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/audio_engine_service.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/utils/string_utils.dart';
import 'package:it_feels_music/features/player/sleep_timer_sheet.dart';
import 'package:it_feels_music/features/new_experience/player/new_now_playing_screen.dart';
import '../theme/new_experience_tokens.dart';
import '../widgets/new_artwork_image.dart';

class NewDesktopPlayerBar extends ConsumerStatefulWidget {
  final VoidCallback? onToggleLyrics;
  final VoidCallback? onToggleQueue;
  final VoidCallback? onToggleStory;
  final bool isLyricsActive;
  final bool isQueueActive;
  final bool isStoryActive;

  const NewDesktopPlayerBar({
    super.key,
    this.onToggleLyrics,
    this.onToggleQueue,
    this.onToggleStory,
    this.isLyricsActive = false,
    this.isQueueActive = false,
    this.isStoryActive = false,
  });

  @override
  ConsumerState<NewDesktopPlayerBar> createState() => _NewDesktopPlayerBarState();
}

class _NewDesktopPlayerBarState extends ConsumerState<NewDesktopPlayerBar> {
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          if (locator.isRegistered<AudioEngineService>()) {
            final current = ref.read(audioPlayerProvider.notifier).currentVolume;
            setState(() {
              _volume = (current / 100.0).clamp(0.0, 1.0);
            });
          }
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Highly isolated selectors: prevent rebuilds during volume, position, or other song downloads
    final song = ref.watch(audioPlayerProvider.select((s) => s.currentSong));

    if (song == null) {
      return const SizedBox.shrink();
    }

    final isPlaying = ref.watch(audioPlayerProvider.select((s) => s.isPlaying));
    final isShuffle = ref.watch(audioPlayerProvider.select((s) => s.isShuffle));
    final isRepeat = ref.watch(audioPlayerProvider.select((s) => s.isRepeat));
    final isSleepTimerActive = ref.watch(audioPlayerProvider.select((s) => s.isSleepTimerActive));
    final isFav = ref.watch(audioPlayerProvider.select((s) => s.favoriteSongs.any((item) => item.id == song.id)));
    final isDown = ref.watch(downloadProvider.select((s) => s.isDownloaded(song.id)));
    final isDownloading = ref.watch(downloadProvider.select((s) => s.isDownloading(song.id)));
    final notifier = ref.read(audioPlayerProvider.notifier);

    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: NewExperienceTokens.midnightSurface.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: NewExperienceTokens.specularBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Left: Track Metadata & Heart / Download / Share ──
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(NewExperienceTokens.radiusSmall),
                    border: Border.all(color: NewExperienceTokens.specularBorder),
                  ),
                  child: NewArtworkImage(
                    imageUrl: song.image,
                    width: 52,
                    height: 52,
                    borderRadius: BorderRadius.circular(NewExperienceTokens.radiusSmall),
                    iconSize: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NewExperienceTokens.bodyMedium(
                          color: NewExperienceTokens.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NewExperienceTokens.bodySmall(
                          color: NewExperienceTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Favorite Button
                IconButton(
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
                  icon: Icon(
                    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFav ? NewExperienceTokens.accentRose : NewExperienceTokens.textMuted,
                    size: 20,
                  ),
                  onPressed: () => notifier.toggleFavorite(song),
                ),
                // Download Button
                IconButton(
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: isDown
                      ? 'Downloaded (Click to remove)'
                      : isDownloading
                          ? 'Downloading...'
                          : 'Download for offline playback',
                  icon: isDownloading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: NewExperienceTokens.accentCyan,
                          ),
                        )
                      : Icon(
                          isDown ? Icons.download_done_rounded : Icons.download_rounded,
                          color: isDown
                              ? NewExperienceTokens.accentCyan
                              : NewExperienceTokens.textMuted,
                          size: 20,
                        ),
                  onPressed: () async {
                    if (isDown) {
                      await ref.read(downloadProvider.notifier).removeDownload(song);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Removed "${song.title}" from downloads')),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Downloading "${song.title}"...')),
                      );
                      final ok = await ref.read(downloadProvider.notifier).downloadSong(song);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? 'Downloaded "${song.title}"' : 'Download failed'),
                          ),
                        );
                      }
                    }
                  },
                ),
                // Share Button
                IconButton(
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Share track',
                  icon: const Icon(
                    Icons.share_outlined,
                    color: NewExperienceTokens.textMuted,
                    size: 19,
                  ),
                  onPressed: () {
                    final exp = DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch;
                    Share.share(
                      'Listening to "${song.title}" by ${song.artist} on It Feels Music! 🎧\nhttps://allrounder687.github.io/room/${song.id}?exp=$exp',
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Center: Transport Controls & Scrubber ──
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Transport buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Shuffle',
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: isShuffle
                            ? NewExperienceTokens.accentViolet
                            : NewExperienceTokens.textMuted,
                        size: 18,
                      ),
                      onPressed: () => notifier.toggleShuffle(),
                    ),
                    IconButton(
                      tooltip: 'Previous track',
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        color: NewExperienceTokens.textPrimary,
                        size: 24,
                      ),
                      onPressed: () => notifier.skipToPrevious(),
                    ),
                    const SizedBox(width: 8),
                    // Big Play/Pause Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => notifier.togglePlayPause(),
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: NewExperienceTokens.accentViolet,
                            boxShadow: [
                              BoxShadow(
                                color: NewExperienceTokens.accentViolet.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Next track',
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: NewExperienceTokens.textPrimary,
                        size: 24,
                      ),
                      onPressed: () => notifier.skipToNext(),
                    ),
                    IconButton(
                      tooltip: 'Repeat mode',
                      icon: Icon(
                        Icons.repeat_rounded,
                        color: isRepeat
                            ? NewExperienceTokens.accentViolet
                            : NewExperienceTokens.textMuted,
                        size: 18,
                      ),
                      onPressed: () => notifier.toggleRepeat(),
                    ),
                  ],
                ),

                // Scrubber Bar with drag buffering and isolated position stream
                _DesktopTrackScrubber(key: ValueKey('scrubber_${song.id}'), song: song, notifier: notifier),
              ],
            ),
          ),

          // ── Right: Volume, Sleep Timer, Lyrics, Queue, Expand ──
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Sleep Timer',
                  icon: Icon(
                    Icons.bedtime_outlined,
                    color: isSleepTimerActive
                        ? NewExperienceTokens.accentCyan
                        : NewExperienceTokens.textMuted,
                    size: 20,
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const SleepTimerSheet(),
                    );
                  },
                ),
                IconButton(
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Live Synchronized Lyrics',
                  icon: Icon(
                    Icons.lyrics_rounded,
                    color: widget.isLyricsActive
                        ? NewExperienceTokens.accentCyan
                        : NewExperienceTokens.textMuted,
                    size: 20,
                  ),
                  onPressed: widget.onToggleLyrics,
                ),
                IconButton(
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Up Next Queue',
                  icon: Icon(
                    Icons.queue_music_rounded,
                    color: widget.isQueueActive
                        ? NewExperienceTokens.accentViolet
                        : NewExperienceTokens.textMuted,
                    size: 20,
                  ),
                  onPressed: widget.onToggleQueue,
                ),
                IconButton(
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Track Story & Intelligence',
                  icon: Icon(
                    Icons.auto_stories_rounded,
                    color: widget.isStoryActive
                        ? NewExperienceTokens.accentCyan
                        : NewExperienceTokens.textMuted,
                    size: 19,
                  ),
                  onPressed: widget.onToggleStory,
                ),
                IconButton(
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Full Player View',
                  icon: const Icon(
                    Icons.open_in_full_rounded,
                    color: NewExperienceTokens.textMuted,
                    size: 18,
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const NewNowPlayingScreen(),
                    );
                  },
                ),
                const SizedBox(width: 6),
                Icon(
                  _volume == 0
                      ? Icons.volume_off_rounded
                      : _volume < 0.5
                          ? Icons.volume_down_rounded
                          : Icons.volume_up_rounded,
                  color: NewExperienceTokens.textMuted,
                  size: 20,
                ),
                SizedBox(
                  width: 85,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3.0,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                      activeTrackColor: NewExperienceTokens.textPrimary,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: _volume,
                      onChanged: (v) {
                        setState(() => _volume = v);
                        notifier.setVolume(v);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Isolated desktop scrubber with local drag buffering and seek dispatch on release.
class _DesktopTrackScrubber extends StatefulWidget {
  final Song song;
  final dynamic notifier;

  const _DesktopTrackScrubber({
    super.key,
    required this.song,
    required this.notifier,
  });

  @override
  State<_DesktopTrackScrubber> createState() => _DesktopTrackScrubberState();
}

class _DesktopTrackScrubberState extends State<_DesktopTrackScrubber> {
  bool _isDragging = false;
  double _dragMs = 0.0;

  @override
  Widget build(BuildContext context) {
    final total = Duration(seconds: widget.song.duration);
    final maxMs = total.inMilliseconds > 0 ? total.inMilliseconds.toDouble() : 1.0;

    return StreamBuilder<Duration>(
      stream: locator.isRegistered<AudioEngineService>()
          ? locator<AudioEngineService>().positionStream
          : const Stream.empty(),
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final posMs = _isDragging
            ? _dragMs.clamp(0.0, maxMs)
            : position.inMilliseconds.toDouble().clamp(0.0, maxMs);
        final displayPos = Duration(milliseconds: posMs.toInt());

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              StringUtils.formatDuration(displayPos),
              style: NewExperienceTokens.numericTimer(
                color: _isDragging ? NewExperienceTokens.accentCyan : NewExperienceTokens.textMuted,
              ).copyWith(fontSize: 11),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.5,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: _isDragging ? 7.5 : 5.5),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: _isDragging ? NewExperienceTokens.accentCyan : NewExperienceTokens.accentViolet,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: posMs,
                  max: maxMs,
                  onChangeStart: (val) {
                    setState(() {
                      _isDragging = true;
                      _dragMs = val;
                    });
                  },
                  onChanged: (val) {
                    setState(() {
                      _dragMs = val;
                    });
                  },
                  onChangeEnd: (val) {
                    setState(() {
                      _isDragging = false;
                    });
                    widget.notifier.seek(Duration(milliseconds: val.toInt()));
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              StringUtils.formatDuration(total),
              style: NewExperienceTokens.numericTimer(
                color: NewExperienceTokens.textMuted,
              ).copyWith(fontSize: 11),
            ),
          ],
        );
      },
    );
  }
}
