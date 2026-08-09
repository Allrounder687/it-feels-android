import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/theme/app_dimensions.dart';
import 'package:it_feels_music/features/settings/storage_provider.dart';

class StorageScreen extends ConsumerWidget {
  const StorageScreen({super.key});

  String _formatBytesSimple(int bytes) {
    if (bytes >= 1073741824) {
      return "${(bytes / 1073741824).toStringAsFixed(2)} GB";
    } else if (bytes >= 1048576) {
      return "${(bytes / 1048576).toStringAsFixed(2)} MB";
    } else if (bytes >= 1024) {
      return "${(bytes / 1024).toStringAsFixed(2)} KB";
    } else {
      return "$bytes B";
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(storageProvider);
    final notifier = ref.read(storageProvider.notifier);

    return Scaffold(
      backgroundColor: context.themeBackgroundColor,
      appBar: AppBar(
        flexibleSpace: kIsWeb ? null : (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux ? null : const DragToMoveArea(child: SizedBox.expand())),
        backgroundColor: context.themeBackgroundColor,
        elevation: 0,
        title: Text(
          "Storage & Cache",
          style: GoogleFonts.outfit(
            color: context.themeTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.themeTextColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: state.isLoading
          ? Center(child: CircularProgressIndicator(color: context.themeAccentColor))
          : ListView(
              padding: EdgeInsets.only(left: 20, top: 20, right: 20, bottom: AppDimensions.bottomClearance + MediaQuery.of(context).viewPadding.bottom),
              children: [
                _buildStorageBar(context, state),
                const SizedBox(height: 32),
                _buildSectionHeader(context, "âš™ï¸ Auto-Download"),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("Auto-Download Favorites",
                      style: TextStyle(color: context.themeTextColor, fontWeight: FontWeight.w500)),
                  subtitle: Text("Silently download liked songs in the background.",
                      style: TextStyle(color: context.themeMutedTextColor, fontSize: 13)),
                  activeTrackColor: context.themeAccentColor,
                  value: state.autoDownload,
                  onChanged: (val) {
                    notifier.toggleAutoDownload(val);
                  },
                ),
                const SizedBox(height: 32),
                _buildSectionHeader(context, "🗑️ Smart Cache Manager"),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("Max Cache Size",
                      style: TextStyle(color: context.themeTextColor, fontWeight: FontWeight.w500)),
                  subtitle: Text(_formatBytesSimple(state.maxCacheSize),
                      style: TextStyle(color: context.themeMutedTextColor, fontSize: 13)),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, color: context.themeMutedTextColor, size: 16),
                  onTap: () => _showMaxCacheDialog(context, notifier),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    notifier.clearCache();
                  },
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                  label: const Text("Clear All Cache", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        color: context.themeTextColor,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStorageBar(BuildContext context, StorageState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.themeSurfaceColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Disk Usage",
              style: GoogleFonts.outfit(color: context.themeTextColor, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Expanded(
                  flex: state.downloadSize > 0 ? state.downloadSize : 1,
                  child: Container(height: 12, color: Colors.blueAccent),
                ),
                Expanded(
                  flex: state.cacheSize > 0 ? state.cacheSize : 1,
                  child: Container(height: 12, color: Colors.amberAccent),
                ),
                Expanded(
                  flex: state.maxCacheSize > 0 ? state.maxCacheSize : 1000,
                  child: Container(height: 12, color: context.themeCardColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildLegend(context, "Downloads", _formatBytesSimple(state.downloadSize), Colors.blueAccent),
              const Spacer(),
              _buildLegend(context, "Audio Cache", _formatBytesSimple(state.cacheSize), Colors.amberAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(BuildContext context, String title, String size, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: context.themeMutedTextColor, fontSize: 12)),
            Text(size, style: TextStyle(color: context.themeTextColor, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  void _showMaxCacheDialog(BuildContext context, StorageNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.themeSurfaceColor,
          title: Text("Set Max Cache Size", style: TextStyle(color: context.themeTextColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text("1 GB", style: TextStyle(color: context.themeTextColor)),
                onTap: () {
                  notifier.updateMaxCacheSize(1024);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: Text("2 GB", style: TextStyle(color: context.themeTextColor)),
                onTap: () {
                  notifier.updateMaxCacheSize(2048);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: Text("5 GB", style: TextStyle(color: context.themeTextColor)),
                onTap: () {
                  notifier.updateMaxCacheSize(5120);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

