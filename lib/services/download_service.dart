import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:background_downloader/background_downloader.dart';

import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'storage_service.dart';

class DownloadService {
  final MusicApiService apiService;
  bool _initialized = false;

  DownloadService({required this.apiService}) {
    _initDownloader();
  }

  Future<void> _initDownloader() async {
    if (_initialized) return;
    
    // Configure background OS notifications only for mobile platforms where it is supported cleanly
    if (Platform.isAndroid || Platform.isIOS) {
      FileDownloader().configureNotification(
        running: const TaskNotification('Downloading...', 'file: {filename}'),
        complete: const TaskNotification('Download Complete', 'file: {filename}'),
        error: const TaskNotification('Download Failed', 'file: {filename}'),
        progressBar: true,
      );
    }
    _initialized = true;
  }

  /// Returns the current directory where downloaded files are saved
  Future<String> getDownloadDirectoryPath() async {
    final settings = await StorageService.loadSettings();
    final customPath = settings['customDownloadPath'] ?? '';
    
    if (customPath.isNotEmpty) {
      return customPath;
    } else if (Platform.isAndroid) {
      return '/storage/emulated/0/Music/IT-Feels';
    } else {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/downloaded_music';
    }
  }

  /// Download a single song for offline playback via background OS task
  Future<bool> downloadSong(Song song, {Function(double)? onProgress}) async {
    try {
      Directory musicDir;
      final settings = await StorageService.loadSettings();
      final customPath = settings['customDownloadPath'] ?? '';
      
      if (customPath.isNotEmpty) {
        musicDir = Directory(customPath);
      } else if (Platform.isAndroid) {
        await Permission.storage.request();
        if (await Permission.manageExternalStorage.isDenied) {
          await Permission.manageExternalStorage.request();
        }
        await Permission.audio.request();
        // Request notification permission for Android 13+ background notifications
        await Permission.notification.request();
        
        musicDir = Directory('/storage/emulated/0/Music/IT-Feels');
      } else {
        final dir = await getApplicationDocumentsDirectory();
        musicDir = Directory('${dir.path}/downloaded_music');
      }

      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }

      final streamUrl = await apiService.getStreamUrl(song);
      if (streamUrl == null || streamUrl.isEmpty) {
        debugPrint('[DownloadService] Could not resolve stream URL for ${song.title}');
        return false;
      }

      // Sanitize ID
      final safeId = song.id.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final fileName = '$safeId.mp4';
      final savedFilePath = '${musicDir.path}/$fileName';

      // 1. Download Cover Art locally first (for external players)
      // We no longer overwrite the song's coverArt property with this local path.
      // We keep the HTTP URL so CachedNetworkImage can handle offline caching automatically,
      // avoiding Android 13+ READ_MEDIA_IMAGES permission issues.
      if (song.coverArt.isNotEmpty) {
        try {
          final coverResponse = await http.get(Uri.parse(song.coverArt));
          if (coverResponse.statusCode == 200) {
            final coverFile = File('${musicDir.path}/$safeId.jpg');
            await coverFile.writeAsBytes(coverResponse.bodyBytes);
          }
        } catch (_) {}
      }

      // 2. Configure Background Download Task
      final task = DownloadTask(
        url: streamUrl,
        filename: fileName,
        directory: musicDir.path,
        baseDirectory: BaseDirectory.root, // Important for absolute custom paths
        updates: Updates.statusAndProgress,
        retries: 3,
        allowPause: true,
        metaData: song.id,
      );

      // 3. Enqueue and wait for completion
      // We use .download() so we can await it and update our local database when done.
      // Even if the UI thread is busy, the actual download happens via native OS threads.
      final result = await FileDownloader().download(
        task,
        onProgress: (progress) {
          if (onProgress != null && progress >= 0.0) {
            onProgress(progress);
          }
        },
      );

      if (result.status == TaskStatus.complete) {
        // Create downloaded song entry
        final downloadedSong = Song(
          id: song.id,
          saavnId: song.saavnId,
          title: song.title,
          artist: song.artist,
          album: song.album,
          duration: song.duration,
          coverArt: song.coverArt, // Keep original HTTP URL for reliable offline caching
          encryptedMediaUrl: savedFilePath,
          hasLyrics: song.hasLyrics,
          addedAt: DateTime.now(),
        );

        final currentDownloads = await StorageService.loadDownloads();
        currentDownloads.removeWhere((s) => s.id == song.id);
        currentDownloads.add(downloadedSong);

        await StorageService.saveDownloads(currentDownloads);
        debugPrint('[DownloadService] Successfully downloaded via Background Task: ${song.title}');
        return true;
      } else {
        debugPrint('[DownloadService] Background download failed with status: ${result.status}');
        return false;
      }
    } catch (e) {
      debugPrint('[DownloadService] Download error for ${song.title}: $e');
      return false;
    }
  }

  /// Download an entire list of songs (playlist or album)
  Future<void> downloadBatch(List<Song> songs, {Function(int current, int total)? onBatchProgress}) async {
    for (int i = 0; i < songs.length; i++) {
      await downloadSong(songs[i]);
      if (onBatchProgress != null) {
        onBatchProgress(i + 1, songs.length);
      }
    }
  }
}
