import 'package:pixel_player_saavn/views/widgets/custom_image_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/audio_player_provider.dart';

class QueueBottomSheet extends StatelessWidget {
  const QueueBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerProvider>(
      builder: (context, playerProvider, child) {
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
                  color: Colors.white24,
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
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "${queue.length} Tracks",
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
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
                          style: GoogleFonts.inter(color: Colors.white54),
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: queue.length,
                        onReorder: (oldIndex, newIndex) {
                          playerProvider.reorderQueue(oldIndex, newIndex);
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
                                  : Colors.white.withValues(alpha: 0.05),
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
                                        : const Icon(Icons.music_note, color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: isCurrent ? playerProvider.themeAccentColor : Colors.white,
                                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: Colors.white60,
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
                                    : const Icon(Icons.drag_handle_rounded, color: Colors.white30),
                                onTap: () {
                                  playerProvider.playSong(song, queue: queue, index: index);
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
