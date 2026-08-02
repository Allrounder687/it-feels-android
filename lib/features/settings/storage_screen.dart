import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/services/smart_storage_service.dart';

class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ConsumerState<StorageScreen> {
  final SmartStorageService _storageService = locator<SmartStorageService>();
  
  bool _isLoading = true;
  int _cacheSize = 0;
  int _downloadSize = 0;
  int _maxCacheSize = 0;
  bool _autoDownload = false;

  @override
  void initState() {
    super.initState();
    _loadStorageData();
  }

  Future<void> _loadStorageData() async {
    setState(() => _isLoading = true);
    
    final cache = await _storageService.calculateCacheDirectorySize();
    final downloads = await _storageService.calculateDownloadsDirectorySize();
    final maxSize = await _storageService.getMaxCacheSize();
    final autoDownload = await _storageService.getAutoDownloadFavorites();

    if (mounted) {
      setState(() {
        _cacheSize = cache;
        _downloadSize = downloads;
        _maxCacheSize = maxSize;
        _autoDownload = autoDownload;
        _isLoading = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes.toDouble().log() / 1024.0.log()).floor();
    if (i >= suffixes.length) i = suffixes.length - 1;
    final value = bytes / (1024 * i).clamp(1, double.infinity);
    if (i == 0) return "${value.toStringAsFixed(0)} ${suffixes[i]}";
    // Using simple loop if log doesn't work for math dart library without import dart:math
    // Let's use a simpler way
    return _formatBytesSimple(bytes);
  }

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.themeBackgroundColor,
      appBar: AppBar(
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: context.themeAccentColor))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildStorageBar(context),
                const SizedBox(height: 32),
                _buildSectionHeader(context, "⚙️ Auto-Download"),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("Auto-Download Favorites",
                      style: TextStyle(color: context.themeTextColor, fontWeight: FontWeight.w500)),
                  subtitle: Text("Silently download liked songs in the background.",
                      style: TextStyle(color: context.themeMutedTextColor, fontSize: 13)),
                  activeColor: context.themeAccentColor,
                  value: _autoDownload,
                  onChanged: (val) async {
                    setState(() => _autoDownload = val);
                    await _storageService.setAutoDownloadFavorites(val);
                  },
                ),
                const SizedBox(height: 32),
                _buildSectionHeader(context, "🗑️ Smart Cache Manager"),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("Max Cache Size",
                      style: TextStyle(color: context.themeTextColor, fontWeight: FontWeight.w500)),
                  subtitle: Text(_formatBytesSimple(_maxCacheSize),
                      style: TextStyle(color: context.themeMutedTextColor, fontSize: 13)),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, color: context.themeMutedTextColor, size: 16),
                  onTap: _showMaxCacheDialog,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    setState(() => _isLoading = true);
                    await _storageService.clearAllCache();
                    await _loadStorageData();
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

  Widget _buildStorageBar(BuildContext context) {
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
                  flex: _downloadSize > 0 ? _downloadSize : 1,
                  child: Container(height: 12, color: Colors.blueAccent),
                ),
                Expanded(
                  flex: _cacheSize > 0 ? _cacheSize : 1,
                  child: Container(height: 12, color: Colors.amberAccent),
                ),
                Expanded(
                  flex: _maxCacheSize > 0 ? _maxCacheSize : 1000,
                  child: Container(height: 12, color: context.themeCardColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildLegend(context, "Downloads", _formatBytesSimple(_downloadSize), Colors.blueAccent),
              const Spacer(),
              _buildLegend(context, "Audio Cache", _formatBytesSimple(_cacheSize), Colors.amberAccent),
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

  void _showMaxCacheDialog() {
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
                  _storageService.setMaxCacheSize(1073741824);
                  Navigator.pop(ctx);
                  _loadStorageData();
                },
              ),
              ListTile(
                title: Text("2 GB", style: TextStyle(color: context.themeTextColor)),
                onTap: () {
                  _storageService.setMaxCacheSize(2147483648);
                  Navigator.pop(ctx);
                  _loadStorageData();
                },
              ),
              ListTile(
                title: Text("5 GB", style: TextStyle(color: context.themeTextColor)),
                onTap: () {
                  _storageService.setMaxCacheSize(5368709120);
                  Navigator.pop(ctx);
                  _loadStorageData();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
