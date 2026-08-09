import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/theme/app_dimensions.dart';

class HiddenSongsScreen extends ConsumerWidget {
  const HiddenSongsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.themeBackgroundColor,
      appBar: AppBar(
        flexibleSpace: kIsWeb ? null : (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux ? null : const DragToMoveArea(child: SizedBox.expand())),
        backgroundColor: context.themeBackgroundColor,
        elevation: 0,
        title: Text(
          "Hidden Songs",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: context.themeTextColor,
          ),
        ),
        iconTheme: IconThemeData(color: context.themeTextColor),
      ),
      body: Consumer(builder: (context, ref, child) { final provider = ref.watch(hiddenSongsProvider); 
          final hiddenSongs = provider.hiddenSongs.toList();

          if (hiddenSongs.isEmpty) {
            return Center(
              child: Text(
                "You haven't hidden any songs yet.",
                style: GoogleFonts.inter(color: context.themeMutedTextColor),
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: AppDimensions.bottomClearance + MediaQuery.of(context).viewPadding.bottom),
            itemCount: hiddenSongs.length,
            itemBuilder: (context, index) {
              final song = hiddenSongs[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: context.themeCardColor,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    title: Text(
                      song.title,
                      style: GoogleFonts.inter(
                        color: context.themeTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      "${song.artist} â€¢ Hidden from recommendations",
                      style: GoogleFonts.inter(
                        color: context.themeMutedTextColor,
                        fontSize: 12,
                      ),
                    ),
                    trailing: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: context.themeAccentColor,
                      ),
                      onPressed: () {
                        ref.read(hiddenSongsProvider.notifier).unhideSong(song.id);
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

