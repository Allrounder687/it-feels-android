import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

class LyricsShareDialog extends StatefulWidget {
  final Song song;
  final String lyricText;

  const LyricsShareDialog({super.key, required this.song, required this.lyricText});

  @override
  State<LyricsShareDialog> createState() => _LyricsShareDialogState();
}

class _LyricsShareDialogState extends State<LyricsShareDialog> {
  final GlobalKey _globalKey = GlobalKey();
  bool _isProcessing = false;

  Future<void> _shareToInstagram() async {
    setState(() => _isProcessing = true);
    try {
      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0); // High quality
      final directory = (await getTemporaryDirectory()).path;
      
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();
      
      File imgFile = File('$directory/lyric_share.png');
      await imgFile.writeAsBytes(pngBytes);
      
      // Use share_plus to share the file
      await Share.shareXFiles(
        [XFile(imgFile.path)],
        text: 'Listening to ${widget.song.title} by ${widget.song.artist} on It Feels Music.',
      );
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            key: _globalKey,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [context.themeCardColor, context.themeBackgroundColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.themeInvertedTextColor.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Album Art
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 150,
                      height: 150,
                      child: widget.song.coverArt.isNotEmpty
                          ? CustomImageWidget(imageUrl: widget.song.coverArt, fit: BoxFit.cover)
                          : Container(color: AppColors.midnightPill),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Lyric
                  Text(
                    '"${widget.lyricText}"',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: context.themeTextColor,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Song Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.music_note_rounded, color: AppColors.midnightAccent, size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${widget.song.title} • ${widget.song.artist}',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.themeMutedTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // App Branding
                  Text(
                    'IT FEELS',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w900,
                      color: context.themeAccentColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Share Button
          GestureDetector(
            onTap: _isProcessing ? null : _shareToInstagram,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE1306C), Color(0xFFC13584)], // Insta-like colors
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: _isProcessing
                  ? Center(
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(color: context.themeTextColor, strokeWidth: 2),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.share_rounded, color: context.themeTextColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Share to Instagram Stories",
                          style: GoogleFonts.inter(
                            color: context.themeTextColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: GoogleFonts.inter(color: context.themeMutedTextColor)),
          )
        ],
      ),
    );
  }
}
