import 'package:flutter/material.dart';
import 'package:it_feels_music/core/theme/app_typography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/services/backend_api_service.dart';
import 'package:it_feels_music/features/subscription/subscription_provider.dart';
import 'package:it_feels_music/features/subscription/paywall_bottom_sheet.dart';
import 'package:it_feels_music/features/player/lyrics_screen.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

class NowPlayingActions extends ConsumerWidget {
  final Song currentSong;
  final bool isFav;
  final bool isDown;
  final bool isDownloading;
  final Color surfaceColor;
  final Color accentColor;

  const NowPlayingActions({
    super.key,
    required this.currentSong,
    required this.isFav,
    required this.isDown,
    required this.isDownloading,
    required this.surfaceColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => ref.read(audioPlayerProvider.notifier).toggleFavorite(currentSong),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: surfaceColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Icon(
                    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFav ? Colors.pinkAccent : context.themeMutedTextColor,
                    size: 18,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isFav ? "Liked" : "Like",
                    style: AppTypography.interSemiBold.copyWith(
                      color: context.themeTextColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () async {
              if (isDown) {
                await ref.read(downloadProvider.notifier).removeDownload(currentSong);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Removed ${currentSong.title} from downloads")),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Downloading ${currentSong.title}...")),
                );
                final ok = await ref.read(downloadProvider.notifier).downloadSong(currentSong);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? "Downloaded ${currentSong.title}" : "Download failed")),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: surfaceColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  isDownloading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: context.themeTextColor),
                        )
                      : Icon(
                          isDown ? Icons.download_done_rounded : Icons.file_download_outlined,
                          color: isDown ? accentColor : context.themeMutedTextColor,
                          size: 18,
                        ),
                  const SizedBox(width: 5),
                  Text(
                    isDown ? "Downloaded" : "Download",
                    style: AppTypography.interSemiBold.copyWith(
                      color: context.themeTextColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
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
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: surfaceColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lyrics_outlined, color: context.themeMutedTextColor, size: 18),
                  const SizedBox(width: 5),
                  Text(
                    "Lyrics",
                    style: AppTypography.interSemiBold.copyWith(
                      color: context.themeTextColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () {
              Share.share(
                'Listening to "${currentSong.title}" by ${currentSong.artist} on It Feels Music! 🎶',
                subject: 'Check out this song',
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: surfaceColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Icon(Icons.share_outlined, color: context.themeMutedTextColor, size: 18),
                  const SizedBox(width: 5),
                  Text(
                    "Share",
                    style: AppTypography.interSemiBold.copyWith(
                      color: context.themeTextColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
