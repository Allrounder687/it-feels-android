import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/data/services/audio_engine_service.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/core/utils/string_utils.dart';
import 'package:it_feels_music/features/player/sleep_timer_sheet.dart';
import 'package:it_feels_music/core/widgets/song_options_sheet.dart';
import 'package:it_feels_music/features/player/queue_bottom_sheet.dart';
import 'package:it_feels_music/features/player/lyrics_screen.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/new_ambient_canvas.dart';

class NewNowPlayingScreen extends ConsumerStatefulWidget {
  const NewNowPlayingScreen({super.key});

  @override
  ConsumerState<NewNowPlayingScreen> createState() => _NewNowPlayingScreenState();
}

class _NewNowPlayingScreenState extends ConsumerState<NewNowPlayingScreen> {
  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);
    final song = playerState.currentSong;

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

    final isFav = playerState.favoriteSongs.any((s) => s.id == song.id);

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
                      scale: playerState.isPlaying ? 1.0 : 0.94,
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
                            child: song.image.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: song.image,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) => const Icon(
                                      Icons.music_note_rounded,
                                      size: 80,
                                      color: NewExperienceTokens.textMuted,
                                    ),
                                  )
                                : const Icon(
                                    Icons.music_note_rounded,
                                    size: 80,
                                    color: NewExperienceTokens.textMuted,
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
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
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
                  ],
                ),

                const SizedBox(height: 12),

                // ── Seek Slider with Duration Timestamps ──
                StreamBuilder<Duration>(
                  stream: locator<AudioEngineService>().positionStream,
                  builder: (context, snapshot) {
                    final pos = snapshot.data ?? Duration.zero;
                    final total = Duration(seconds: song.duration);
                    final maxMs = total.inMilliseconds > 0 ? total.inMilliseconds.toDouble() : 1.0;
                    final posMs = pos.inMilliseconds.toDouble().clamp(0.0, maxMs);

                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4.0,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: posMs,
                            max: maxMs,
                            onChanged: (val) {
                              notifier.seek(Duration(milliseconds: val.toInt()));
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                StringUtils.formatDuration(pos),
                                style: NewExperienceTokens.numericTimer(color: Colors.white70),
                              ),
                              Text(
                                StringUtils.formatDuration(total),
                                style: NewExperienceTokens.numericTimer(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                        color: playerState.isShuffle
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
                            playerState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
                        color: playerState.isRepeat
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
                        color: playerState.isSleepTimerActive
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
