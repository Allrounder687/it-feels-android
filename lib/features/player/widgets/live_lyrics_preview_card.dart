import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/player/lyrics_screen.dart';
import 'package:it_feels_music/features/subscription/paywall_bottom_sheet.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

class LiveLyricsPreviewCard extends ConsumerWidget {
  final Song song;
  final Color surfaceColor;
  final Color accentColor;
  final bool isWide;

  const LiveLyricsPreviewCard({
    super.key,
    required this.song,
    required this.surfaceColor,
    required this.accentColor,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyricsState = ref.watch(lyricsProvider);

    final lyricsResult = lyricsState.lyricsResult;
    final isLoading = lyricsState.isLoading;
    final isNotFound = lyricsState.lyricsNotFound;

    return ExcludeSemantics(
      child: StreamBuilder<Duration>(
        stream: ref.read(audioPlayerProvider.notifier).engine.positionStream,
        initialData: ref.read(audioPlayerProvider.notifier).engine.position,
        builder: (context, snapshot) {
          final position = snapshot.data ?? Duration.zero;

          String prevLine = "";
          String currentLine = "";
          String nextLine = "";

          if (lyricsResult != null && lyricsResult.hasSynced) {
            final activeIdx = lyricsState.getActiveLineIndex(position);
            if (activeIdx >= 0 &&
                activeIdx < lyricsResult.syncedLyrics.length) {
              if (activeIdx > 0) {
                prevLine = lyricsResult.syncedLyrics[activeIdx - 1].text;
              }
              currentLine = lyricsResult.syncedLyrics[activeIdx].text;
              if (activeIdx + 1 < lyricsResult.syncedLyrics.length) {
                nextLine = lyricsResult.syncedLyrics[activeIdx + 1].text;
              }
            }
          } else if (lyricsResult != null &&
              lyricsResult.hasStatic &&
              lyricsResult.staticLyrics != null) {
            final lines = lyricsResult.staticLyrics!
                .split('\n')
                .where((l) => l.trim().isNotEmpty)
                .toList();
            if (lines.isNotEmpty) currentLine = lines.first;
            if (lines.length > 1) nextLine = lines[1];
          }

          return GestureDetector(
            onTap: () {
              final sub = ref.read(subscriptionProvider);
              if (sub.isPremium) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LyricsScreen()),
                );
              } else {
                PaywallBottomSheet.show(context, featureName: "Lyrics");
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: surfaceColor.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.mic_rounded, color: accentColor, size: 15),
                          const SizedBox(width: 6),
                          Text(
                            'LIVE LYRICS',
                            style: GoogleFonts.inter(
                              color: accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            'FULL SCREEN',
                            style: GoogleFonts.inter(
                              color: context.themeMutedTextColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.north_east_rounded,
                            color: context.themeMutedTextColor,
                            size: 12,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (isLoading)
                    Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Searching lyrics...',
                          style: GoogleFonts.inter(
                            color: context.themeMutedTextColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    )
                  else if (isNotFound || currentLine.isEmpty)
                    Text(
                      'Tap to view lyrics & sing along 🎶',
                      style: GoogleFonts.inter(
                        color: context.themeMutedTextColor,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    SizedBox(
                      height: isWide ? 150 : 100,
                      child: ExcludeSemantics(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final slideIn = Tween<Offset>(
                              begin: const Offset(0.0, 0.3),
                              end: Offset.zero,
                            ).animate(animation);
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: slideIn,
                                child: child,
                              ),
                            );
                          },
                          child: SingleChildScrollView(
                            key: ValueKey(currentLine),
                            physics: const NeverScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (prevLine.isNotEmpty)
                                Text(
                                  prevLine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: context.themeMutedTextColor.withValues(
                                      alpha: 0.35,
                                    ),
                                    fontSize: isWide ? 16 : 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              if (prevLine.isNotEmpty) const SizedBox(height: 3),
                              Text(
                                currentLine,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: context.themeTextColor,
                                  fontSize: isWide ? 24 : 17,
                                  fontWeight: FontWeight.w800,
                                  shadows: [
                                    BoxShadow(
                                      color: accentColor.withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              if (nextLine.isNotEmpty) const SizedBox(height: 3),
                              if (nextLine.isNotEmpty)
                                Text(
                                  nextLine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: context.themeMutedTextColor.withValues(
                                      alpha: 0.6,
                                    ),
                                    fontSize: isWide ? 18 : 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
