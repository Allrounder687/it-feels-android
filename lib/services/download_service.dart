import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:background_downloader/background_downloader.dart';

import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'storage_service.dart';

class DownloadService {
  @visibleForTesting
  static http.Client httpClient = http.Client();

  final IMusicRepository apiService;
  final FileDownloader _downloader;
  bool _initialized = false;

  DownloadService({
    required this.apiService,
    @visibleForTesting FileDownloader? downloader,
  }) : _downloader = downloader ?? FileDownloader() {
    _initDownloader();
  }

  Future<void> _initDownloader() async {
    if (_initialized) return;
    
    // Configure background OS notifications only for mobile platforms where it is supported cleanly
    if (Platform.isAndroid || Platform.isIOS) {
      _downloader.configureNotification(
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
      try {
        final extDirs = await getExternalStorageDirectories(type: StorageDirectory.music);
        if (extDirs != null && extDirs.isNotEmpty) {
          return extDirs.first.path;
        }
      } catch (_) {}
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/downloaded_music';
    } else {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/downloaded_music';
    }
  }

  /// Download a single song for offline playback via background OS task with HTTP streaming fallback
  Future<bool> downloadSong(Song song, {Function(double)? onProgress}) async {
    try {
      Directory musicDir;
      final settings = await StorageService.loadSettings();
      final customPath = settings['customDownloadPath'] ?? '';
      
      if (customPath.isNotEmpty) {
        musicDir = Directory(customPath);
      } else if (Platform.isAndroid) {
        try {
          await Permission.notification.request();
        } catch (_) {}
        final path = await getDownloadDirectoryPath();
        musicDir = Directory(path);
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
      if (song.coverArt.isNotEmpty) {
        try {
          final coverResponse = await httpClient.get(Uri.parse(song.coverArt));
          if (coverResponse.statusCode == 200) {
            final coverFile = File('${musicDir.path}/$safeId.jpg');
            await coverFile.writeAsBytes(coverResponse.bodyBytes);
          }
        } catch (_) {}
      }

      bool downloadCompleted = false;

      // 2. Configure Background Download Task
      try {
        final task = DownloadTask(
          url: streamUrl,
          filename: fileName,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://www.jiosaavn.com/',
            'Accept': '*/*',
          },
          directory: musicDir.path,
          baseDirectory: BaseDirectory.root, // Important for absolute custom paths
          updates: Updates.statusAndProgress,
          retries: 2,
          allowPause: true,
          metaData: song.id,
        );

        final result = await _downloader.download(
          task,
          onProgress: (progress) {
            if (onProgress != null && progress >= 0.0) {
              onProgress(progress);
            }
          },
        );

        if (result.status == TaskStatus.complete) {
          final targetFile = File(savedFilePath);
          if (await targetFile.exists() && await targetFile.length() > 1024) {
            downloadCompleted = true;
          }
        }
      } catch (e) {
        debugPrint('[DownloadService] Background downloader error: $e');
      }

      // 3. Fallback: Direct Streaming Download if Background Downloader was unsuccessful
      if (!downloadCompleted) {
        debugPrint('[DownloadService] Attempting direct stream download fallback for: ${song.title}');
        try {
          final request = http.Request('GET', Uri.parse(streamUrl));
          request.headers.addAll({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://www.jiosaavn.com/',
            'Accept': '*/*',
          });
          final streamedResponse = await httpClient.send(request);
          if (streamedResponse.statusCode == 200) {
            final totalBytes = streamedResponse.contentLength ?? 0;
            int receivedBytes = 0;
            final file = File(savedFilePath);
            final sink = file.openWrite();
            await streamedResponse.stream.listen((chunk) {
              sink.add(chunk);
              receivedBytes += chunk.length;
              if (totalBytes > 0 && onProgress != null) {
                onProgress(receivedBytes / totalBytes);
              }
            }).asFuture();
            await sink.flush();
            await sink.close();

            if (await file.exists() && await file.length() > 1024) {
              downloadCompleted = true;
            }
          }
        } catch (e) {
          debugPrint('[DownloadService] Direct stream download fallback error: $e');
        }
      }

      if (downloadCompleted) {
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
        debugPrint('[DownloadService] Successfully downloaded: ${song.title} to $savedFilePath');
        return true;
      } else {
        debugPrint('[DownloadService] All download strategies failed for ${song.title}');
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
