import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/data/services/audio_engine_service.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/core/utils/hinglish_transliterator.dart';
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
  final ItemScrollController _lyricsScrollController = ItemScrollController();
  int _currentActiveIndex = -1;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerProvider);
    final lyricsState = ref.watch(lyricsProvider);
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
                if (_currentTab == ContextualPanelTab.lyrics) ...[
                  const SizedBox(width: 8),
                  // Romanized English Toggle Button
                  Tooltip(
                    message: lyricsState.showRomanized
                        ? 'Romanized English (Active - Click for Original Hindi)'
                        : 'Romanized English (Click to Enable)',
                    child: InkWell(
                      onTap: () => ref.read(lyricsProvider.notifier).toggleRomanized(),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: lyricsState.showRomanized
                              ? NewExperienceTokens.accentCyan.withValues(alpha: 0.16)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: lyricsState.showRomanized
                                ? NewExperienceTokens.accentCyan.withValues(alpha: 0.5)
                                : NewExperienceTokens.specularBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Aa',
                              style: TextStyle(
                                color: lyricsState.showRomanized
                                    ? NewExperienceTokens.accentCyan
                                    : NewExperienceTokens.textMuted,
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Roman',
                              style: TextStyle(
                                color: lyricsState.showRomanized
                                    ? NewExperienceTokens.accentCyan
                                    : NewExperienceTokens.textMuted,
                                fontWeight: FontWeight.w600,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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
    final staticText = lyricsState.lyricsResult?.staticLyrics;

    if (lines.isEmpty) {
      if (staticText != null && staticText.trim().isNotEmpty) {
        final displayText = lyricsState.showRomanized
            ? HinglishTransliterator.transliterate(staticText)
            : staticText;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'UNSYNCED LYRICS',
                  style: NewExperienceTokens.captionMuted(color: NewExperienceTokens.textMuted),
                ),
              ),
              Text(
                displayText,
                style: NewExperienceTokens.bodyMedium(
                  color: NewExperienceTokens.textPrimary,
                ).copyWith(height: 1.8),
              ),
              if (lyricsState.showRomanized && staticText != displayText) ...[
                const SizedBox(height: 20),
                Divider(color: NewExperienceTokens.subtleDivider),
                const SizedBox(height: 12),
                Text(
                  'ORIGINAL SCRIPT',
                  style: NewExperienceTokens.captionMuted(color: NewExperienceTokens.textMuted),
                ),
                const SizedBox(height: 8),
                Text(
                  staticText,
                  style: NewExperienceTokens.bodySmall(
                    color: NewExperienceTokens.textSecondary.withValues(alpha: 0.7),
                  ).copyWith(height: 1.8),
                ),
              ],
            ],
          ),
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lyrics_outlined, size: 36, color: NewExperienceTokens.textMuted),
              const SizedBox(height: 8),
              Text(
                lyricsState.lyricsNotFound
                    ? 'No lyrics found for this track'
                    : 'Searching for lyrics...',
                textAlign: TextAlign.center,
                style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<Duration>(
      stream: locator.isRegistered<AudioEngineService>()
          ? locator<AudioEngineService>().positionStream
          : const Stream.empty(),
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final activeIndex = lyricsState.getActiveLineIndex(position);

        if (activeIndex != _currentActiveIndex && activeIndex >= 0) {
          _currentActiveIndex = activeIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_lyricsScrollController.isAttached && activeIndex < lines.length) {
              _lyricsScrollController.scrollTo(
                index: activeIndex,
                alignment: 0.35,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
              );
            }
          });
        }

        return ScrollablePositionedList.builder(
          itemScrollController: _lyricsScrollController,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          itemCount: lines.length,
          itemBuilder: (context, index) {
            final line = lines[index];
            final isCurrentLine = index == activeIndex;
            final showRoman = lyricsState.showRomanized && line.transliteration != null;
            final primaryText = showRoman ? line.transliteration! : line.text;
            final secondaryText = showRoman ? line.text : (line.translation);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    ref.read(audioPlayerProvider.notifier).seek(line.time);
                  },
                  borderRadius: BorderRadius.circular(10),
                  hoverColor: Colors.white.withValues(alpha: 0.05),
                  splashColor: NewExperienceTokens.accentCyan.withValues(alpha: 0.15),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrentLine
                          ? NewExperienceTokens.accentCyan.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isCurrentLine
                          ? const Border(
                              left: BorderSide(
                                color: NewExperienceTokens.accentCyan,
                                width: 3.5,
                              ),
                            )
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          primaryText,
                          style: TextStyle(
                            fontSize: isCurrentLine ? 16.5 : 14.5,
                            fontWeight: isCurrentLine ? FontWeight.bold : FontWeight.w500,
                            color: isCurrentLine
                                ? NewExperienceTokens.accentCyan
                                : NewExperienceTokens.textSecondary.withValues(alpha: 0.8),
                            height: 1.35,
                          ),
                        ),
                        if (secondaryText != null && secondaryText.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            secondaryText,
                            style: TextStyle(
                              fontSize: isCurrentLine ? 13 : 11.5,
                              fontWeight: FontWeight.w400,
                              color: isCurrentLine
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : NewExperienceTokens.textMuted.withValues(alpha: 0.7),
                              height: 1.25,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
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

              // Title & Artist
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
                      style: NewExperienceTokens.numericTimer(
                        color: NewExperienceTokens.textMuted,
                      ).copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Play / Status
              if (isCurrent)
                const Icon(
                  Icons.equalizer_rounded,
                  color: NewExperienceTokens.accentViolet,
                  size: 18,
                )
              else
                IconButton(
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    color: NewExperienceTokens.textMuted,
                    size: 18,
                  ),
                  splashRadius: 16,
                  onPressed: () => notifier.playSong(song, queue: queue, index: index),
                ),
            ],
          ),
        );
      },
    );
  }
}
