import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:it_feels_music/data/services/audio_engine_service.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import '../theme/new_experience_tokens.dart';
import '../widgets/new_glass_container.dart';

class NewMiniPlayer extends ConsumerWidget {
  final VoidCallback onTap;

  const NewMiniPlayer({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);
    final song = playerState.currentSong;

    if (song == null) {
      return const SizedBox.shrink();
    }

    final isFav = playerState.favoriteSongs.any((s) => s.id == song.id);

    return Dismissible(
      key: ValueKey('new_mini_player_${song.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          notifier.skipToNext();
        } else {
          notifier.skipToPrevious();
        }
        return false; // Do not dismiss widget, just trigger track change
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: NewGlassContainer(
            borderRadius: NewExperienceTokens.radiusLarge,
            blur: NewExperienceTokens.blurStandard,
            backgroundColor: NewExperienceTokens.cardSurface.withValues(alpha: 0.88),
            padding: const EdgeInsets.all(0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Micro-Progress Bar
                StreamBuilder<Duration>(
                  stream: locator<AudioEngineService>().positionStream,
                  builder: (context, snapshot) {
                    final pos = snapshot.data ?? Duration.zero;
                    final total = Duration(seconds: song.duration);
                    final progress = total.inMilliseconds > 0
                        ? (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
                        : 0.0;

                    return LinearProgressIndicator(
                      value: progress,
                      minHeight: 2.5,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        NewExperienceTokens.accentViolet,
                      ),
                    );
                  },
                ),

                // Main Pill Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      // Squircle Artwork
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(NewExperienceTokens.radiusSmall),
                          border: Border.all(color: NewExperienceTokens.specularBorder),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(NewExperienceTokens.radiusSmall),
                          child: song.image.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: song.image,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => const Icon(
                                    Icons.music_note_rounded,
                                    color: NewExperienceTokens.textMuted,
                                  ),
                                )
                              : const Icon(
                                  Icons.music_note_rounded,
                                  color: NewExperienceTokens.textMuted,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title & Artist
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: NewExperienceTokens.bodyMedium().copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: NewExperienceTokens.bodySmall(
                                color: NewExperienceTokens.textSecondary,
                              ).copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                      // Favorite Button
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? NewExperienceTokens.accentRose : NewExperienceTokens.textMuted,
                          size: 20,
                        ),
                        splashRadius: 20,
                        onPressed: () => notifier.toggleFavorite(song),
                      ),

                      // Play/Pause Button
                      IconButton(
                        icon: Icon(
                          playerState.isPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_fill_rounded,
                          color: NewExperienceTokens.accentViolet,
                          size: 34,
                        ),
                        splashRadius: 22,
                        onPressed: () => notifier.togglePlayPause(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
