import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/widgets/animated_equalizer.dart';
import 'package:it_feels_music/core/widgets/song_options_sheet.dart';
import 'package:it_feels_music/core/utils/string_utils.dart';
import '../theme/new_experience_tokens.dart';
import 'new_artwork_image.dart';

class NewMediaTile extends ConsumerStatefulWidget {
  final Song song;
  final int? index;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteToggle;
  final bool showArtwork;
  final bool showIndex;

  const NewMediaTile({
    super.key,
    required this.song,
    this.index,
    required this.onTap,
    this.onFavoriteToggle,
    this.showArtwork = true,
    this.showIndex = true,
  });

  @override
  ConsumerState<NewMediaTile> createState() => _NewMediaTileState();
}

class _NewMediaTileState extends ConsumerState<NewMediaTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Highly isolated selector: only triggers when this specific song becomes current or stops being current
    final isCurrent = ref.watch(audioPlayerProvider.select((s) => s.currentSong?.id == widget.song.id));
    // Only subscribe to isPlaying updates if this tile is the current active track
    final isPlaying = isCurrent && ref.watch(audioPlayerProvider.select((s) => s.isPlaying));

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onSecondaryTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (context) => SongOptionsSheet(song: widget.song),
            );
          },
          onLongPress: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (context) => SongOptionsSheet(song: widget.song),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isCurrent
                  ? NewExperienceTokens.accentViolet.withValues(alpha: 0.12)
                  : _isHovered
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(NewExperienceTokens.radiusMedium),
              border: Border.all(
                color: isCurrent
                    ? NewExperienceTokens.accentViolet.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                // Index or Equalizer
                if (widget.showIndex) ...[
                  SizedBox(
                    width: 28,
                    child: Center(
                      child: isCurrent && isPlaying
                          ? const AnimatedEqualizer(
                              color: NewExperienceTokens.accentViolet,
                            )
                          : Text(
                              widget.index != null ? '${widget.index! + 1}' : '',
                              style: NewExperienceTokens.numericTimer(
                                color: isCurrent
                                    ? NewExperienceTokens.accentViolet
                                    : NewExperienceTokens.textMuted,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Artwork Thumbnail
                if (widget.showArtwork) ...[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(NewExperienceTokens.radiusSmall),
                      border: Border.all(color: NewExperienceTokens.specularBorder),
                    ),
                    child: NewArtworkImage(
                      imageUrl: widget.song.image,
                      width: 44,
                      height: 44,
                      borderRadius: BorderRadius.circular(NewExperienceTokens.radiusSmall),
                      iconSize: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // Song Title & Artists
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NewExperienceTokens.bodyMedium(
                          color: isCurrent
                              ? NewExperienceTokens.accentViolet
                              : NewExperienceTokens.textPrimary,
                        ).copyWith(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NewExperienceTokens.bodySmall(
                          color: NewExperienceTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Duration
                Text(
                  StringUtils.formatDuration(Duration(seconds: widget.song.duration)),
                  style: NewExperienceTokens.numericTimer(
                    color: isCurrent
                        ? NewExperienceTokens.accentViolet
                        : NewExperienceTokens.textMuted,
                  ),
                ),

                const SizedBox(width: 8),

                // Options 3-dot menu
                IconButton(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: NewExperienceTokens.textMuted,
                    size: 18,
                  ),
                  splashRadius: 20,
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) => SongOptionsSheet(song: widget.song),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
