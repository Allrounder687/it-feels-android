import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/data/services/audio_engine_service.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/features/player/sleep_timer_sheet.dart';
import 'package:it_feels_music/core/widgets/song_options_sheet.dart';
import 'package:it_feels_music/features/player/queue_bottom_sheet.dart';
import 'package:it_feels_music/features/player/lyrics_screen.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/new_ambient_canvas.dart';
import '../widgets/new_artwork_image.dart';
import '../widgets/new_audio_scrubber.dart';
import '../player/new_equalizer_sheet.dart';
import '../track/new_track_detail_screen.dart';
import '../artist/new_artist_detail_screen.dart';

class NewNowPlayingScreen extends ConsumerStatefulWidget {
  const NewNowPlayingScreen({super.key});

  @override
  ConsumerState<NewNowPlayingScreen> createState() => _NewNowPlayingScreenState();
}

class _NewNowPlayingScreenState extends ConsumerState<NewNowPlayingScreen> {
  @override
  Widget build(BuildContext context) {
    // Granular selectors: prevent rebuilds during external queue mutations or slider ticks
    final song = ref.watch(audioPlayerProvider.select((s) => s.currentSong));
    final notifier = ref.read(audioPlayerProvider.notifier);

    if (song == null) {
      return Scaffold(
        backgroundColor: NewExperienceTokens.obsidianBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text('No song selected', style: TextStyle(color: NewExperienceTokens.textMuted)),
        ),
      );
    }

    final isPlaying = ref.watch(audioPlayerProvider.select((s) => s.isPlaying));
    final isShuffle = ref.watch(audioPlayerProvider.select((s) => s.isShuffle));
    final isRepeat = ref.watch(audioPlayerProvider.select((s) => s.isRepeat));
    final isSleepTimerActive = ref.watch(audioPlayerProvider.select((s) => s.isSleepTimerActive));
    final isFav = ref.watch(audioPlayerProvider.select((s) => s.favoriteSongs.any((item) => item.id == song.id)));
    final isDown = ref.watch(downloadProvider.select((s) => s.isDownloaded(song.id)));
    final isDownloading = ref.watch(downloadProvider.select((s) => s.isDownloading(song.id)));

    return NewAmbientCanvas(
      intensity: 0.65,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 30),
            onPressed: () => Navigator.of(context).pop(),
          ),
          centerTitle: true,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PLAYING FROM PLAYLIST',
                style: NewExperienceTokens.eyebrowLabel(
                  color: Colors.white.withValues(alpha: 0.7),
                ).copyWith(fontSize: 10),
              ),
              const SizedBox(height: 2),
              Text(
                'IT Feels Next-Gen',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '10-Band Equalizer & Audio FX',
              icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 24),
              onPressed: () {
                HapticFeedback.lightImpact();
                NewEqualizerSheet.show(context);
              },
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 24),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) => SongOptionsSheet(song: song),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // ── Big Album Artwork Squircle ──
                Flexible(
                  flex: 8,
                  child: Center(
                    child: AnimatedScale(
                      scale: isPlaying ? 1.0 : 0.94,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 340, maxHeight: 340),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 36,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: AspectRatio(
                            aspectRatio: 1.0,
                            child: NewArtworkImage(
                              imageUrl: song.image,
                              width: 340,
                              height: 340,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(28),
                              iconSize: 80,
                              fallbackTitle: song.title,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Title, Artist & Favorite Toggle ──
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => NewArtistDetailScreen(artistName: song.artist),
                                ),
                              );
                            },
                            child: Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: Colors.white.withValues(alpha: 0.85),
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.white38,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: Colors.white24, width: 0.5),
                            ),
                            child: Text(
                              isDown ? 'OFFLINE • 320 KBPS' : '320 KBPS • AAC STEREO',
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: isDown ? NewExperienceTokens.accentCyan : Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
                      icon: Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFav ? NewExperienceTokens.accentRose : Colors.white70,
                        size: 26,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        notifier.toggleFavorite(song);
                      },
                    ),
                    IconButton(
                      tooltip: isDown
                          ? 'Downloaded (Click to remove)'
                          : isDownloading
                              ? 'Downloading...'
                              : 'Download for offline playback',
                      icon: isDownloading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              isDown ? Icons.download_done_rounded : Icons.download_rounded,
                              color: isDown ? NewExperienceTokens.accentCyan : Colors.white70,
                              size: 25,
                            ),
                      onPressed: () async {
                        HapticFeedback.lightImpact();
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
                  ],
                ),

                const SizedBox(height: 12),

                // ── High-Precision Audio Scrubber ──
                StreamBuilder<Duration>(
                  stream: locator<AudioEngineService>().positionStream,
                  builder: (context, snapshot) {
                    final pos = snapshot.data ?? Duration.zero;
                    final total = Duration(seconds: song.duration);

                    return NewAudioScrubber(
                      currentPosition: pos,
                      totalDuration: total,
                      onSeek: (target) {
                        notifier.seek(target);
                      },
                    );
                  },
                ),

                const SizedBox(height: 12),

                // ── Transport Controls ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: isShuffle
                            ? NewExperienceTokens.accentCyan
                            : Colors.white54,
                        size: 24,
                      ),
                      onPressed: () => notifier.toggleShuffle(),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                      onPressed: () => notifier.skipToPrevious(),
                    ),
                    // Big Play/Pause Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          notifier.togglePlayPause();
                        },
                        borderRadius: BorderRadius.circular(34),
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 38,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                      onPressed: () => notifier.skipToNext(),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.repeat_rounded,
                        color: isRepeat
                            ? NewExperienceTokens.accentCyan
                            : Colors.white54,
                        size: 24,
                      ),
                      onPressed: () => notifier.toggleRepeat(),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Bottom Utility Drawer Icons ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Lyrics Button
                    IconButton(
                      tooltip: 'Lyrics',
                      icon: const Icon(Icons.lyrics_rounded, color: Colors.white70, size: 22),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (context) => const LyricsScreen(),
                        );
                      },
                    ),

                    // Sleep Timer
                    IconButton(
                      tooltip: 'Sleep Timer',
                      icon: Icon(
                        Icons.bedtime_rounded,
                        color: isSleepTimerActive
                            ? NewExperienceTokens.accentCyan
                            : Colors.white70,
                        size: 22,
                      ),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const SleepTimerSheet(),
                        );
                      },
                    ),

                    // Up Next Queue
                    IconButton(
                      tooltip: 'Queue',
                      icon: const Icon(Icons.queue_music_rounded, color: Colors.white70, size: 22),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (context) => const QueueBottomSheet(),
                        );
                      },
                    ),

                    // Track Story & Credits
                    IconButton(
                      tooltip: 'Track Story & Credits',
                      icon: const Icon(Icons.auto_stories_rounded, color: Colors.white70, size: 22),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => NewTrackDetailScreen(song: song),
                          ),
                        );
                      },
                    ),

                    // Share Button
                    IconButton(
                      tooltip: 'Share',
                      icon: const Icon(Icons.share_outlined, color: Colors.white70, size: 22),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        final exp = DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch;
                        Share.share(
                          'Listening to "${song.title}" by ${song.artist} on It Feels Music! 🎧\nhttps://allrounder687.github.io/room/${song.id}?exp=$exp',
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
