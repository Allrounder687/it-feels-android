import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

class QueueBottomSheet extends ConsumerWidget {
  const QueueBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Consumer(builder: (context, ref, child) { final playerProvider = ref.watch(audioPlayerProvider); 
        final queue = playerProvider.queue;
        final currentIndex = playerProvider.currentIndex;
        final surfaceColor = playerProvider.themeSurfaceColor;

        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.themeTextColor24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Playback Queue",
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: context.themeTextColor,
                      ),
                    ),
                    Text(
                      "${queue.length} Tracks",
                      style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Autoplay Similar Songs",
                      style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 14),
                    ),
                    Switch(
                      value: playerProvider.isAutoplayEnabled,
                      onChanged: (val) {
                        ref.read(audioPlayerProvider.notifier).toggleAutoplay();
                      },
                      activeThumbColor: playerProvider.themeAccentColor,
                    ),
                  ],
                ),
              ),

              // Queue Items List
              Expanded(
                child: queue.isEmpty
                    ? Center(
                        child: Text(
                          "Queue is empty",
                          style: GoogleFonts.inter(color: context.themeMutedTextColor),
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: queue.length,
                        onReorder: (oldIndex, newIndex) {
                          ref.read(audioPlayerProvider.notifier).reorderQueue(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final song = queue[index];
                          final isCurrent = index == currentIndex;

                          return Padding(
                            key: ValueKey('${song.id}_$index'),
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Material(
                              color: isCurrent
                                  ? playerProvider.themeAccentColor.withValues(alpha: 0.15)
                                  : context.themeTextColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              child: ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: song.coverArt.isNotEmpty
                                        ? CustomImageWidget(
                                            imageUrl: song.coverArt,
                                            fit: BoxFit.cover,
                                          )
                                        : Icon(Icons.music_note, color: context.themeTextColor),
                                  ),
                                ),
                                title: Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: isCurrent ? playerProvider.themeAccentColor : context.themeTextColor,
                                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: context.themeMutedTextColor,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: isCurrent
                                    ? Icon(
                                        playerProvider.isPlaying
                                            ? Icons.equalizer_rounded
                                            : Icons.play_arrow_rounded,
                                        color: playerProvider.themeAccentColor,
                                      )
                                    : Icon(Icons.drag_handle_rounded, color: context.themeTextColor.withValues(alpha: 0.3)),
                                onTap: () {
                                  ref.read(audioPlayerProvider.notifier).playSong(song, queue: queue, index: index);
                                },
                              ),
                            ),
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
}
