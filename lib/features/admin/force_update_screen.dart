import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:http/http.dart' as http;

class ForceUpdateScreen extends StatefulWidget {
  final String latestVersion;
  final String updateUrl;
  final String? releaseNotes;

  const ForceUpdateScreen({
    super.key,
    required this.latestVersion,
    required this.updateUrl,
    this.releaseNotes,
  });

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusMessage = "Update Now";

  Future<void> _downloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _statusMessage = "Starting Download...";
    });

    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/it_feels_update_v${widget.latestVersion}.apk';

      // Download using standard HTTP to track bytes
      final request = http.Request('GET', Uri.parse(widget.updateUrl));
      final response = await http.Client().send(request);
      
      final contentLength = response.contentLength ?? 0;
      int downloaded = 0;
      
      final file = File(savePath);
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        
        if (contentLength > 0) {
          setState(() {
            _progress = downloaded / contentLength;
            _statusMessage = "Downloading... ${(_progress * 100).toStringAsFixed(1)}%";
          });
        }
      }
      
      await sink.close();

      setState(() {
        _statusMessage = "Installing...";
        _progress = 1.0;
      });

      // Trigger Android native package installer
      final result = await OpenFile.open(savePath);
      
      if (result.type != ResultType.done) {
        setState(() {
          _isDownloading = false;
          _statusMessage = "Install Failed. Try Again.";
        });
      }

    } catch (e) {
      setState(() {
        _isDownloading = false;
        _statusMessage = "Download Failed. Tap to Retry.";
      });
      debugPrint('[OTA Update] Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnightSurface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.system_update_rounded,
                color: AppColors.midnightAccent,
                size: 100,
              ),
              const SizedBox(height: 32),
              Text(
                "Time for an Update!",
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Version ${widget.latestVersion} is now available. We've added some great new features and fixed bugs to improve your experience.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              if (widget.releaseNotes != null && widget.releaseNotes!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "What's New:",
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.releaseNotes!,
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 40),
              
              if (_isDownloading)
                Column(
                  children: [
                    LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      color: AppColors.midnightAccent,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusMessage,
                      style: GoogleFonts.inter(color: AppColors.midnightAccent, fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              else
                ElevatedButton(
                  onPressed: _downloadAndInstall,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.midnightAccent,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _statusMessage,
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
