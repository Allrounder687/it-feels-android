import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/data/services/audio_engine_service.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/core/utils/string_utils.dart';
import '../theme/new_experience_tokens.dart';

enum ContextualPanelTab { lyrics, queue }

class NewContextualPanel extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final ContextualPanelTab initialTab;

  const NewContextualPanel({
    super.key,
    required this.onClose,
    this.initialTab = ContextualPanelTab.lyrics,
  });

  @override
  ConsumerState<NewContextualPanel> createState() => _NewContextualPanelState();
}

class _NewContextualPanelState extends ConsumerState<NewContextualPanel> {
  late ContextualPanelTab _currentTab;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerProvider);
    final song = playerState.currentSong;

    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: NewExperienceTokens.midnightSurface,
        border: Border(
          left: BorderSide(color: NewExperienceTokens.specularBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header with Tab Switcher & Close Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: NewExperienceTokens.subtleDivider),
              ),
            ),
            child: Row(
              children: [
                _buildTabButton('Lyrics', ContextualPanelTab.lyrics),
                const SizedBox(width: 8),
                _buildTabButton('Queue', ContextualPanelTab.queue),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: NewExperienceTokens.textSecondary,
                    size: 20,
                  ),
                  splashRadius: 18,
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // Body Content
          Expanded(
            child: song == null
                ? const Center(
                    child: Text(
                      'No song playing',
                      style: TextStyle(color: NewExperienceTokens.textMuted),
                    ),
                  )
                : _currentTab == ContextualPanelTab.lyrics
                    ? _buildLyricsView(song.id)
                    : _buildQueueView(playerState),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, ContextualPanelTab tab) {
    final isSelected = _currentTab == tab;
    return InkWell(
      onTap: () => setState(() => _currentTab = tab),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? NewExperienceTokens.accentViolet.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? NewExperienceTokens.accentViolet.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: NewExperienceTokens.bodySmall(
            color: isSelected
                ? NewExperienceTokens.accentViolet
                : NewExperienceTokens.textSecondary,
          ).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildLyricsView(String songId) {
    final lyricsState = ref.watch(lyricsProvider);

    if (lyricsState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: NewExperienceTokens.accentViolet),
      );
    }

    final lines = lyricsState.lyricsResult?.syncedLyrics ?? [];
    if (lines.isEmpty) {
      return Center(
        child: Text(
          lyricsState.lyricsNotFound
              ? 'No lyrics found for this track'
              : 'No synchronized lyrics available',
          style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
        ),
      );
    }

    return StreamBuilder<Duration>(
      stream: locator<AudioEngineService>().positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: lines.length,
          itemBuilder: (context, index) {
            final line = lines[index];
            final isCurrentLine = line.time <= position &&
                (index == lines.length - 1 || lines[index + 1].time > position);

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                line.text,
                style: TextStyle(
                  fontSize: isCurrentLine ? 16 : 14,
                  fontWeight: isCurrentLine ? FontWeight.bold : FontWeight.w500,
                  color: isCurrentLine
                      ? NewExperienceTokens.accentCyan
                      : NewExperienceTokens.textSecondary.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQueueView(AudioPlayerState playerState) {
    final queue = playerState.queue;
    final notifier = ref.read(audioPlayerProvider.notifier);

    if (queue.isEmpty) {
      return Center(
        child: Text(
          'Queue is empty',
          style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: queue.length,
      itemBuilder: (context, index) {
        final song = queue[index];
        final isCurrent = index == playerState.currentIndex;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isCurrent
                ? NewExperienceTokens.accentViolet.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(NewExperienceTokens.radiusSmall),
          ),
          child: Row(
            children: [
              // Cover
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: song.image.isNotEmpty
                      ? CachedNetworkImage(imageUrl: song.image, fit: BoxFit.cover)
                      : const Icon(Icons.music_note_rounded, size: 16),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NewExperienceTokens.bodySmall(
                        color: isCurrent
                            ? NewExperienceTokens.accentViolet
                            : NewExperienceTokens.textPrimary,
                      ).copyWith(fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500),
                    ),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NewExperienceTokens.captionMuted(),
                    ),
                  ],
                ),
              ),
              Text(
                StringUtils.formatDuration(Duration(seconds: song.duration)),
                style: NewExperienceTokens.numericTimer(
                  color: isCurrent
                      ? NewExperienceTokens.accentViolet
                      : NewExperienceTokens.textMuted,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.play_circle_outline_rounded,
                  size: 18,
                  color: NewExperienceTokens.textSecondary,
                ),
                onPressed: () => notifier.playSong(song, index: index),
              ),
            ],
          ),
        );
      },
    );
  }
}
