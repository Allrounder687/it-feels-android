import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/features/cast/cast_service.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

class CastBottomSheet extends ConsumerWidget {
  const CastBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.themeSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const CastBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final castService = locator<CastService>();
    final accentColor = context.themeAccentColor;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                castService.isConnected ? Icons.cast_connected_rounded : Icons.cast_rounded,
                color: castService.isConnected ? accentColor : context.themeTextColor,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                'Cast Audio',
                style: GoogleFonts.plusJakartaSans(
                  color: context.themeTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (castService.isConnected)
                TextButton(
                  onPressed: () {
                    castService.disconnect();
                    Navigator.pop(context);
                  },
                  child: const Text('Disconnect', style: TextStyle(color: Colors.redAccent)),
                )
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<dynamic>>(
            future: castService.searchDevices(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final devices = snapshot.data ?? [];
              if (devices.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      "No Cast devices found on your network.\nMake sure you're connected to Wi-Fi.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: context.themeMutedTextColor),
                    ),
                  ),
                );
              }
              return Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return ListTile(
                      leading: const Icon(Icons.tv_rounded),
                      title: Text(device.name, style: GoogleFonts.inter(color: context.themeTextColor)),
                      subtitle: Text(device.host, style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12)),
                      onTap: () async {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connecting to ${device.name}...')));
                        await castService.connectToDevice(device);
                        
                        final song = ref.read(audioPlayerProvider).currentSong;
                        if (song != null) {
                          ref.read(audioPlayerProvider.notifier).playSong(song);
                        }
                      },
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
