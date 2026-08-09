import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:it_feels_music/services/config_service.dart';
import 'package:url_launcher/url_launcher.dart';

class InAppBroadcastListener extends StatefulWidget {
  final Widget child;

  const InAppBroadcastListener({super.key, required this.child});

  @override
  State<InAppBroadcastListener> createState() => _InAppBroadcastListenerState();
}

class _InAppBroadcastListenerState extends State<InAppBroadcastListener> {
  static const String _lastBroadcastKey = 'last_seen_broadcast_id';
  StreamSubscription? _premiumSubscription;
  bool _wasPremium = false;

  @override
  void initState() {
    super.initState();
    _listenForBroadcasts();
    _listenForPremiumUpgrades();
    _checkForSoftUpdates();
  }

  void _checkForSoftUpdates() async {
    final config = await ConfigService.fetchRemoteConfig();
    if (config == null) return;
    
    final hasUpdate = await ConfigService.hasSoftUpdate(config);
    if (hasUpdate && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.system_update, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Update Available (v${config.latestVersion})",
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
              if (config.releaseNotes != null && config.releaseNotes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  config.releaseNotes!,
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
          backgroundColor: Colors.blueAccent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 10,
          action: SnackBarAction(
            label: 'UPDATE',
            textColor: Colors.white,
            onPressed: () async {
              String targetUrl = config.updateUrl;
              if (Platform.isIOS) {
                if (config.iosUpdateUrl != null && config.iosUpdateUrl!.isNotEmpty) {
                  targetUrl = config.iosUpdateUrl!;
                } else if (config.updateUrl.endsWith('.apk')) {
                  targetUrl = config.updateUrl.replaceAll('.apk', '.ipa');
                }
              }
              final url = Uri.parse(targetUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ),
      );
    }
  }

  void _listenForPremiumUpgrades() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool isInitialized = false;

    _premiumSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final isPremiumNow = data['isPremiumFamily'] == true;
          
          if (!isInitialized) {
             _wasPremium = isPremiumNow;
             isInitialized = true;
             return;
          }
          
          if (isPremiumNow && !_wasPremium) {
            _wasPremium = true;
            
            if (mounted) {
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "You've been upgraded to Premium courtesy of Developer: FaiXal! 🎉",
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    duration: const Duration(seconds: 8),
                    backgroundColor: Colors.amber,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  )
                );
              } catch (_) {}
            }
          } else if (!isPremiumNow && _wasPremium) {
             _wasPremium = false;
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _premiumSubscription?.cancel();
    super.dispose();
  }

  void _listenForBroadcasts() {
    FirebaseFirestore.instance
        .collection('broadcasts')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final prefs = await SharedPreferences.getInstance();
        final lastSeenId = prefs.getString(_lastBroadcastKey);

        if (doc.id != lastSeenId) {
          // New broadcast received!
          final data = doc.data();
          final title = data['title'] ?? 'Announcement';
          final message = data['message'] ?? '';

          if (mounted) {
            _showBroadcastBanner(title, message);
          }
          await prefs.setString(_lastBroadcastKey, doc.id);
        }
      }
    });
  }

  void _showBroadcastBanner(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: context.themeAccentColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 10,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
