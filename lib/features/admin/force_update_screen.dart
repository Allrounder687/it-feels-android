import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class ForceUpdateScreen extends StatefulWidget {
  final String latestVersion;
  final String updateUrl;
  final String? releaseNotes;
  final String? iosUpdateUrl;
  final bool isSoftUpdate;

  const ForceUpdateScreen({
    super.key,
    required this.latestVersion,
    required this.updateUrl,
    this.releaseNotes,
    this.iosUpdateUrl,
    this.isSoftUpdate = false,
  });

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusMessage = "Update Now";

  Future<void> _downloadAndInstall() async {
    // Apple's Walled Garden explicitly blocks in-app IPA installations.
    if (Platform.isIOS) {
      final url = widget.iosUpdateUrl ?? widget.updateUrl;
      final uri = Uri.parse(url);
      
      // We must kick iOS users to Safari or AltStore/TestFlight links
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('[OTA] Could not launch iOS update URL');
      }
      return;
    }

    // Windows: Launch ms-appinstaller protocol for MSIX auto-update
    if (Platform.isWindows) {
      final appInstallerUrl = 'ms-appinstaller:?source=${Uri.encodeComponent(widget.updateUrl)}';
      try {
        await launchUrl(Uri.parse(appInstallerUrl));
      } catch (e) {
        // Fallback: open GitHub releases page in browser
        await launchUrl(Uri.parse(widget.updateUrl), mode: LaunchMode.externalApplication);
      }
      return;
    }

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
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _statusMessage = "Installing...";
          });
        }
      });

      // Trigger Android native package installer
      final result = await OpenFilex.open(savePath);
      
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

  String get _effectiveIosUrl {
    if (widget.iosUpdateUrl != null && widget.iosUpdateUrl!.isNotEmpty) {
      return widget.iosUpdateUrl!;
    }
    if (widget.updateUrl.endsWith('.apk')) {
      return widget.updateUrl.replaceAll('.apk', '.ipa');
    }
    return widget.updateUrl;
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
              else if (Platform.isIOS)
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        final url = _effectiveIosUrl;
                        final uri = Uri.parse('apple-magnifier://install?url=$url');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text("Install via TrollStore", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final url = _effectiveIosUrl;
                        final uri = Uri.parse('altstore://install?url=$url');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text("Install via AltStore", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => launchUrl(Uri.parse(_effectiveIosUrl), mode: LaunchMode.externalApplication),
                      child: Text(
                        "Download IPA (Safari)",
                        style: GoogleFonts.inter(fontSize: 16, color: Colors.white70, decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                )
              else if (Platform.isWindows)
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _downloadAndInstall,
                      icon: const Icon(Icons.system_update_alt_rounded),
                      label: Text(
                        "Update via App Installer",
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.midnightAccent,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse(widget.updateUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(
                        "Download from GitHub",
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.white70,
                          decoration: TextDecoration.underline,
                        ),
                      ),
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
                
              if (widget.isSoftUpdate && !_isDownloading) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Remind Me Later",
                    style: GoogleFonts.inter(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
