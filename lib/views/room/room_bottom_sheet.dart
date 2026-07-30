import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/audio_player_provider.dart';
import '../../core/theme/app_colors.dart';
import 'dart:ui';

class RoomBottomSheet extends StatefulWidget {
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
  State<RoomBottomSheet> createState() => _RoomBottomSheetState();
}

class _RoomBottomSheetState extends State<RoomBottomSheet> {
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
    setState(() => _isLoading = true);
    final audioProvider = Provider.of<AudioPlayerProvider>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await audioProvider.startBroadcasting(user.uid);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _joinSession() async {
    final pin = _pinController.text.trim();
    if (pin.length != 6) return;
    
    setState(() => _isLoading = true);
    final audioProvider = Provider.of<AudioPlayerProvider>(context, listen: false);
    await audioProvider.joinSession(pin);
    setState(() => _isLoading = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = Provider.of<AudioPlayerProvider>(context);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 40,
          top: 40,
          left: 24,
          right: 24,
        ),
        decoration: BoxDecoration(
          color: audioProvider.themeSurfaceColor.withOpacity(0.5),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
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
  }

  Widget _buildHostView(AudioPlayerProvider audioProvider) {
    final roomId = audioProvider.currentRoomId;
    
    if (roomId == null) {
      return const Text("Failed to create room.", style: TextStyle(color: Colors.white));
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
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7)),
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
        ElevatedButton(
          onPressed: () {
            audioProvider.leaveSession();
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent.withOpacity(0.2),
            foregroundColor: Colors.redAccent,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("Stop Broadcasting"),
        )
      ],
    );
  }

  Widget _buildGuestView(AudioPlayerProvider audioProvider) {
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
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7)),
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
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            hintText: "000000",
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
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
