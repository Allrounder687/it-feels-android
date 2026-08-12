import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'dart:ui';
import 'package:it_feels_music/core/providers/bottom_ui_provider.dart';

import 'package:it_feels_music/features/subscription/paywall_bottom_sheet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/features/social/social_service.dart';


class RoomBottomSheet extends ConsumerStatefulWidget {
  final bool isHost;
  const RoomBottomSheet({super.key, required this.isHost});

  static void show(BuildContext context, {required bool isHost}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RoomBottomSheet(isHost: isHost),
    );
  }

  @override
  ConsumerState<RoomBottomSheet> createState() => _RoomBottomSheetState();
}

class _RoomBottomSheetState extends ConsumerState<RoomBottomSheet> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isHost) {
      _startHosting();
    }
  }

  Future<void> _startHosting() async {
    final isPremium = ref.read(subscriptionProvider).isPremium;
    if (!isPremium) {
      if (mounted) {
        Navigator.pop(context);
        PaywallBottomSheet.show(context, featureName: "Listen Together");
      }
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await ref.read(audioPlayerProvider.notifier).startBroadcasting(user.uid);
      } catch (e) {
        debugPrint('Error starting broadcast: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create room: $e')),
          );
        }
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _joinSession() async {
    final pin = _pinController.text.trim();
    if (pin.length != 6) return;
    
    setState(() => _isLoading = true);
    try {
      await ref.read(audioPlayerProvider.notifier).joinSession(pin);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error joining session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join room: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = ref.watch(audioPlayerProvider);
    final bottomUiHeight = ref.watch(bottomUiProvider);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom + bottomUiHeight + 16.0;
    final settings = ref.watch(settingsProvider);

    final contentContainer = Container(
      padding: EdgeInsets.only(
        bottom: bottomPadding,
        top: 40,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        color: settings.isPerformanceMode 
            ? audioProvider.themeSurfaceColor 
            : audioProvider.themeSurfaceColor.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (_isLoading)
            const CircularProgressIndicator()
          else if (widget.isHost)
            _buildHostView(audioProvider)
          else
            _buildGuestView(audioProvider),
        ],
      ),
      ),
    );

    if (settings.isPerformanceMode) {
      return contentContainer;
    }

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: contentContainer,
    );
  }

  Widget _buildHostView(AudioPlayerState audioProvider) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.account_circle_outlined, size: 48, color: Colors.amber),
            const SizedBox(height: 12),
            const Text(
              "Account Required",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              "For Listen Together to work, users need to be logged in.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      );
    }

    final isPremium = ref.watch(subscriptionProvider).isPremium;
    if (!isPremium) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.workspace_premium_rounded, size: 48, color: Colors.amber),
            const SizedBox(height: 12),
            const Text(
              "Premium Required",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              "Only IT Feels Premium users can create and host Listen Together rooms.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                PaywallBottomSheet.show(context, featureName: "Listen Together");
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              child: const Text("Upgrade Now"),
            ),
          ],
        ),
      );
    }

    if (audioProvider.currentSong == null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.music_off_rounded, size: 48, color: Colors.amber),
            const SizedBox(height: 12),
            const Text(
              "No Track Playing",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              "Play a song first before starting a broadcast room.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      );
    }

    final roomId = audioProvider.currentRoomId;
    
    if (roomId == null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text(
              "Unable to Create Room",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              "Please check your internet connection and try again.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        const Text(
          "You are Broadcasting",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          "Have your friend scan this QR code or type the PIN.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: QrImageView(
            data: roomId,
            version: QrVersions.auto,
            size: 200.0,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          "OR ENTER PIN",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 2),
        ),
        const SizedBox(height: 12),
        Text(
          roomId,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            letterSpacing: 10,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
              label: const Text("Invite"),
              onPressed: () => _showInviteFriendsDialog(context, roomId),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.chat_bubble_rounded, size: 16),
              label: const Text("WhatsApp"),
              onPressed: () async {
                final currentSong = ref.read(audioPlayerProvider).currentSong;
                final songName = currentSong?.title ?? "music";
                final exp = DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch;
                final link = 'https://allrounder687.github.io/room/$roomId?exp=$exp';
                final text = Uri.encodeComponent('Come listen to $songName with me live on IT-Feels! \n\n$link');
                final url = 'whatsapp://send?text=$text';
                
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url));
                } else {
                  Share.share(
                    'Join my active listening room on It Feels Music: $roomId \n\n$link',
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent.shade400,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 8),

            ElevatedButton(
              onPressed: () {
                ref.read(audioPlayerProvider.notifier).leaveSession();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                foregroundColor: Colors.redAccent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Stop"),
            ),
          ],
        )
      ],
    );
  }

  void _showInviteFriendsDialog(BuildContext context, String roomId) {
    showDialog(
      context: context,
      builder: (ctx) {
        final socialService = locator<SocialService>();
        final user = FirebaseAuth.instance.currentUser;
        final myName = user?.displayName ?? user?.email?.split('@')[0] ?? 'Host';

        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text("Invite Friends to Room", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: StreamBuilder<DocumentSnapshot>(
              stream: socialService.getFriendsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data?.data() == null) {
                  return Center(child: Text("No friends found. Add friends first!", style: GoogleFonts.inter(color: Colors.white70)));
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final friends = List<String>.from(data['friends'] ?? []);

                if (friends.isEmpty) {
                  return Center(child: Text("No friends found. Add friends first!", style: GoogleFonts.inter(color: Colors.white70)));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friendUid = friends[index];
                    return FutureBuilder<Map<String, dynamic>?>(
                      future: socialService.getFriendDetails(friendUid),
                      builder: (context, friendSnapshot) {
                        if (!friendSnapshot.hasData) return const SizedBox.shrink();
                        final friendData = friendSnapshot.data!;
                        final friendName = friendData['name'] ?? friendData['username'] ?? 'Friend';

                        return ListTile(
                          title: Text(friendName, style: GoogleFonts.inter(color: Colors.white)),
                          subtitle: Text(friendData['username'] ?? '', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amberAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: const Text("Invite", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () {
                              socialService.sendRoomInvite(friendUid, roomId, myName);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Invitation sent to $friendName! 🚀")),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGuestView(AudioPlayerState audioProvider) {
    return Column(
      children: [
        const Text(
          "Join a Session",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          "Enter your friend's 6-digit PIN to listen together.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 8, color: Colors.white),
          decoration: InputDecoration(
            counterText: "",
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            hintText: "000000",
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
          ),
          onChanged: (val) {
            if (val.length == 6) {
              _joinSession();
            }
          },
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _pinController.text.length == 6 ? _joinSession : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: audioProvider.themeAccentColor,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text("Join Broadcast", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        )
      ],
    );
  }
}
