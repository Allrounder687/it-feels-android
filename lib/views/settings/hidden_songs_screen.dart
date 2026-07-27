import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/hidden_songs_provider.dart';

class HiddenSongsScreen extends StatelessWidget {
  const HiddenSongsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.midnightBackground,
        elevation: 0,
        title: Text(
          "Hidden Songs",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer<HiddenSongsProvider>(
        builder: (context, provider, child) {
          final hiddenSongs = provider.hiddenSongs.toList();

          if (hiddenSongs.isEmpty) {
            return Center(
              child: Text(
                "You haven't hidden any songs yet.",
                style: GoogleFonts.inter(color: AppColors.midnightTextMuted),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: hiddenSongs.length,
            itemBuilder: (context, index) {
              final song = hiddenSongs[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: AppColors.midnightCard,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    title: Text(
                      song.title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      "${song.artist} • Hidden from recommendations",
                      style: GoogleFonts.inter(
                        color: AppColors.midnightTextMuted,
                        fontSize: 12,
                      ),
                    ),
                    trailing: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.midnightPrimary,
                      ),
                      onPressed: () {
                        provider.unhideSong(song.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Song restored")),
                        );
                      },
                      child: const Text("UNHIDE"),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
