import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:go_router/go_router.dart';
import 'package:it_feels_music/features/social/room_bottom_sheet.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

class RoomDeepLinkScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String? expStr;
  const RoomDeepLinkScreen({super.key, required this.roomId, this.expStr});

  @override
  ConsumerState<RoomDeepLinkScreen> createState() => _RoomDeepLinkScreenState();
}

class _RoomDeepLinkScreenState extends ConsumerState<RoomDeepLinkScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinAndRedirect();
    });
  }

  Future<void> _joinAndRedirect() async {
    try {
      if (widget.expStr != null) {
        final exp = int.tryParse(widget.expStr!);
        if (exp != null && DateTime.now().millisecondsSinceEpoch > exp) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This room invite link has expired.')),
            );
            context.go('/home');
          }
          return;
        }
      }

      await ref.read(audioPlayerProvider.notifier).joinSession(widget.roomId);
      if (mounted) {
        // Navigate to home and open full player or bottom sheet
        context.go('/home');
        RoomBottomSheet.show(context, isHost: false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join room: $e')),
        );
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.themeBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              "Joining Room...",
              style: TextStyle(
                color: context.themeTextColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
