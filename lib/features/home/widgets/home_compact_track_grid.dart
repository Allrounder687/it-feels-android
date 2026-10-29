import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:it_feels_music/core/widgets/song_options_sheet.dart';
import 'package:it_feels_music/core/widgets/tv_focusable_card.dart';
import 'package:it_feels_music/data/models/song_model.dart';

class HomeCompactTrackGrid extends ConsumerWidget {
  final List<Song> songs;
  final String? title;

  const HomeCompactTrackGrid({
    super.key,
    required this.songs,
    this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (songs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    final screenWidth = MediaQuery.of(context).size.width;
    final hPadding = screenWidth < 600 ? 16.0 : 32.0;

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: EdgeInsets.only(left: hPadding, right: hPadding, top: 48, bottom: 16),
              child: Text(
                title!,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.themeTextColor,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: hPadding),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: screenWidth >= 1400 ? 4 : (screenWidth >= 1000 ? 3 : (screenWidth >= 600 ? 2 : 1)),
              mainAxisExtent: 64,
              crossAxisSpacing: 16,
              mainAxisSpacing: 10,
            ),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];

              return TVFocusableCard(
                onTap: () => ref
                    .read(audioPlayerProvider.notifier)
                    .playSong(song, queue: songs, index: index),
                onLongPress: () => SongOptionsSheet.show(
                  context,
                  song,
                  playlistContext: songs,
                ),
                focusedScale: 1.02,
                borderRadius: 6.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: song.coverArt.isNotEmpty
                              ? CustomImageWidget(
                                  imageUrl: song.coverArt,
                                  fit: BoxFit.cover,
                                  size: 150,
                                )
                              : Container(color: context.themeSurfaceColor),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: context.themeTextColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: context.themeMutedTextColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.more_horiz_rounded,
                        color: context.themeMutedTextColor,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
