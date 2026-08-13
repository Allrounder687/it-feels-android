import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/player/lyrics_provider.dart';
import 'package:it_feels_music/core/widgets/glass_shield_wrapper.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/core/widgets/wavy_seek_bar.dart';
import 'package:it_feels_music/features/player/lyrics_share_dialog.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

class LyricsScreen extends ConsumerStatefulWidget {
  const LyricsScreen({super.key});

  @override
  ConsumerState<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends ConsumerState<LyricsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final playerProv = ref.read(audioPlayerProvider);
      if (playerProv.currentSong != null) {
        ref
            .read(lyricsProvider.notifier)
            .loadLyricsIfNeeded(playerProv.currentSong!);
        ref.read(lyricsProvider.notifier).scrollToActiveIndex(force: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final lyricsProvLocal = ref.watch(lyricsProvider);
        final playerProvLocal = ref.watch(audioPlayerProvider);
        final settings = ref.watch(settingsProvider);
        final currentSong = playerProvLocal.currentSong;

        ref.listen(audioPlayerProvider.select((p) => p.currentSong), (
          previous,
          next,
        ) {
          if (next != null) {
            ref.read(lyricsProvider.notifier).loadLyricsIfNeeded(next);
          }
        });

        return GlassShieldWrapper(
          isGlassMode: context.isGlassTheme,
          child: Scaffold(
            backgroundColor: context.themeBackgroundColor,
            body: SafeArea(
            child: Column(
              children: [
                // Top Navigation Bar (Back Arrow, Title, Options)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.midnightPill,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: context.themeTextColor,
                            size: 20,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),

                      // Synced vs Static Mode Pill
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.midnightPill,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => ref
                                  .read(lyricsProvider.notifier)
                                  .setMode(LyricsMode.synced),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      lyricsProvLocal.mode == LyricsMode.synced
                                      ? context.themeAccentColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  "Synced",
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        lyricsProvLocal.mode ==
                                            LyricsMode.synced
                                        ? context.themeInvertedTextColor
                                        : context.themeMutedTextColor,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => ref
                                  .read(lyricsProvider.notifier)
                                  .setMode(LyricsMode.static),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      lyricsProvLocal.mode == LyricsMode.static
                                      ? context.themeAccentColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  "Static",
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        lyricsProvLocal.mode ==
                                            LyricsMode.static
                                        ? context.themeInvertedTextColor
                                        : context.themeMutedTextColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (lyricsProvLocal.activeProvider != null &&
                          lyricsProvLocal.activeProvider!.isNotEmpty)
                        _buildProviderSwitcher(context, ref, lyricsProvLocal),

                      // Font Selector Button (Cycle Fonts directly upon pressing without popups or toasts)
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.midnightPill,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.text_fields,
                            color: context.themeTextColor,
                            size: 20,
                          ),
                        ),
                        onPressed: () =>
                            ref.read(lyricsProvider.notifier).cycleFont(),
                      ),
                    ],
                  ),
                ),

                // Timing Offset Compensation Bar (Sleek Micro Pill)
                if (lyricsProvLocal.mode == LyricsMode.synced &&
                    lyricsProvLocal.result.hasSynced)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.themeCardColor.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: context.themeMutedTextColor.withValues(
                            alpha: 0.15,
                          ),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => ref
                                .read(lyricsProvider.notifier)
                                .adjustSyncOffset(-100),
                            child: Icon(
                              Icons.remove_circle_outline,
                              size: 16,
                              color: context.themeMutedTextColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Sync Offset: ${lyricsProvLocal.syncOffsetMs >= 0 ? '+' : ''}${lyricsProvLocal.syncOffsetMs}ms",
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.themeMutedTextColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => ref
                                .read(lyricsProvider.notifier)
                                .adjustSyncOffset(100),
                            child: Icon(
                              Icons.add_circle_outline,
                              size: 16,
                              color: context.themeMutedTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Main Lyrics View Container
                Expanded(
                  child: lyricsProvLocal.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.midnightAccent,
                          ),
                        )
                      : lyricsProvLocal.mode == LyricsMode.synced &&
                            lyricsProvLocal.result.hasSynced
                      ? ScrollablePositionedList.builder(
                          itemScrollController: ref
                              .read(lyricsProvider.notifier)
                              .itemScrollController,
                          padding: EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: MediaQuery.of(context).size.height * 0.3,
                          ),
                          itemCount: lyricsProvLocal.result.syncedLyrics.length,
                          itemBuilder: (context, index) {
                            final line =
                                lyricsProvLocal.result.syncedLyrics[index];
                            final isActive =
                                index == lyricsProvLocal.activeIndex;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                style: _getLyricsTextStyle(
                                  lyricsProvLocal.fontFamily,
                                  fontSize: isActive ? 28 : 21,
                                  fontWeight: isActive
                                      ? FontWeight.w900
                                      : FontWeight.w500,
                                  color: isActive
                                      ? context.themeTextColor
                                      : context.themeTextColor.withValues(
                                          alpha: 0.35,
                                        ),
                                  height: 1.35,
                                  shadows: isActive
                                      ? [
                                          BoxShadow(
                                            color: AppColors.midnightAccent
                                                .withValues(alpha: 0.5),
                                            blurRadius: 18,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    ref
                                        .read(audioPlayerProvider.notifier)
                                        .seek(line.time);
                                  },
                                  onLongPress: () {
                                    if (currentSong != null) {
                                      showDialog(
                                        context: context,
                                        builder: (_) => LyricsShareDialog(
                                          song: currentSong,
                                          lyricText: line.text,
                                        ),
                                      );
                                    }
                                  },
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: Text(
                                      line.text,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 36,
                              ),
                              child: Text(
                                !settings.useProxyBackend
                                    ? "⚠️ Please turn on the 'Use Serverless Proxy Backend' option in Advanced Server Settings for better lyrics extraction.\n\n${lyricsProvLocal.result.staticLyrics ?? "Oopsies! 🙈 The lyrics for this track are playing hide and seek."}"
                                    : (lyricsProvLocal.result.staticLyrics ??
                                          "Oopsies! 🙈 The lyrics for this track are playing hide and seek."),
                                textAlign: TextAlign.center,
                                style: _getLyricsTextStyle(
                                  lyricsProvLocal.fontFamily,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: context.themeMutedTextColor,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),

                // Bottom Floating Mini Control Bar Overlay
                if (currentSong != null)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: context.themeCardColor.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: context.themeInvertedTextColor.withValues(
                            alpha: 0.4,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: currentSong.coverArt.isNotEmpty
                                ? CustomImageWidget(
                                    imageUrl: currentSong.coverArt,
                                    fit: BoxFit.cover,
                                  )
                                : Icon(
                                    Icons.music_note,
                                    color: context.themeTextColor,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentSong.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: context.themeTextColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              ExcludeSemantics(
                                child: StreamBuilder<Duration>(
                                  stream: ref
                                      .read(audioPlayerProvider.notifier)
                                      .audioHandler
                                      .player
                                      .positionStream,
                                  initialData: playerProvLocal.position,
                                  builder: (context, snapshot) {
                                    final currentPos =
                                        snapshot.data ??
                                        playerProvLocal.position;
                                    return WavySeekBar(
                                      position: currentPos,
                                      duration: playerProvLocal.duration,
                                      activeColor: AppColors.midnightAccent,
                                      inactiveColor: context.themeTextColor24,
                                      onSeek: (pos) => ref
                                          .read(audioPlayerProvider.notifier)
                                          .seek(pos),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        GestureDetector(
                          onTap: () => ref
                              .read(audioPlayerProvider.notifier)
                              .togglePlayPause(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: context.themeAccentColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              playerProvLocal.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: context.themeInvertedTextColor,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ));
      },
    );
  }

  TextStyle _getLyricsTextStyle(
    String font, {
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? height,
    List<Shadow>? shadows,
  }) {
    switch (font) {
      case 'Syne':
        return GoogleFonts.syne(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: height,
          shadows: shadows,
        );
      case 'Space Grotesk':
        return GoogleFonts.spaceGrotesk(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: height,
          shadows: shadows,
        );
      case 'Outfit':
        return GoogleFonts.outfit(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: height,
          shadows: shadows,
        );
      case 'Plus Jakarta Sans':
      default:
        return GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: height,
          shadows: shadows,
        );
    }
  }

  Widget _buildProviderSwitcher(
    BuildContext context,
    WidgetRef ref,
    LyricsState state,
  ) {
    final providers = state.availableLyrics.keys.toList();
    if (providers.length <= 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: context.themeTextColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          state.activeProvider ?? '',
          style: GoogleFonts.inter(
            color: context.themeMutedTextColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return PopupMenuButton<String>(
      initialValue: state.activeProvider,
      onSelected: (String provider) {
        ref.read(lyricsProvider.notifier).switchProvider(provider);
      },
      color: context.themeCardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      offset: const Offset(0, 32),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: context.themeTextColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.activeProvider ?? '',
              style: GoogleFonts.inter(
                color: context.themeTextColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 14,
              color: context.themeTextColor,
            ),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) {
        return providers.map((String provider) {
          final isSelected = provider == state.activeProvider;
          return PopupMenuItem<String>(
            value: provider,
            child: Text(
              provider,
              style: GoogleFonts.inter(
                color: isSelected
                    ? context.themeAccentColor
                    : context.themeTextColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          );
        }).toList();
      },
    );
  }
}
