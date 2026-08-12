import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

class WelcomePermissionsSheet extends StatefulWidget {
  final VoidCallback onComplete;
  
  const WelcomePermissionsSheet({super.key, required this.onComplete});

  @override
  State<WelcomePermissionsSheet> createState() => _WelcomePermissionsSheetState();
}

class _WelcomePermissionsSheetState extends State<WelcomePermissionsSheet> {
  bool _requesting = false;

  Future<void> _requestPermissions() async {
    setState(() => _requesting = true);
    
    // Request Audio & Notification permissions
    await [
      Permission.notification,
      Permission.audio, // For Android 13+
      Permission.storage, // For older Androids
    ].request();
    
    setState(() => _requesting = false);
    
    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.themeBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: context.themeTextColor10)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.amber.withValues(alpha: 0.1),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              size: 64,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            "Stay in Sync",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: context.themeTextColor,
              shadows: context.themeTextShadow,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "We need permission to send notifications so you can control playback in the background and receive Room invites from friends.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: context.themeMutedTextColor,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _requesting ? null : _requestPermissions,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.themeTextColor,
                foregroundColor: context.themeInvertedTextColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: _requesting
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.themeInvertedTextColor,
                      ),
                    )
                  : const Text(
                      "Allow Access",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              widget.onComplete();
            },
            child: Text(
              "Maybe Later",
              style: TextStyle(
                color: context.themeMutedTextColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
