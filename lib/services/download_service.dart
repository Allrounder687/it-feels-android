import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:background_downloader/background_downloader.dart';

import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/core/utils/string_utils.dart';
import 'storage_service.dart';
import 'package:it_feels_music/services/metadata_restoration_service.dart';
import 'package:it_feels_music/services/download_scanner_service.dart';

class DownloadService {
  @visibleForTesting
  static http.Client httpClient = http.Client();

  /// Shared HTTP client for internal download and metadata services
  static http.Client get sharedHttpClient => httpClient;

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
    
    // Configure background OS notifications to display original song names
    if (Platform.isAndroid || Platform.isIOS) {
      _downloader.configureNotification(
        running: const TaskNotification('Downloading...', '{displayName}'),
        complete: const TaskNotification('Download Complete', '{displayName}'),
        error: const TaskNotification('Download Failed', '{displayName}'),
        progressBar: true,
      );
    }
    _initialized = true;
  }

  /// Sanitizes text for cross-platform filesystems (Android/Linux/Windows/exFAT/FAT32)
  static String sanitizeFileName(String input) {
    String cleaned = StringUtils.cleanText(input);
    // Replace slashes and colons with natural hyphens
    cleaned = cleaned.replaceAll(RegExp(r'[/\\:]'), ' - ');
    // Remove characters forbidden on filesystems (* ? " < > |)
    cleaned = cleaned.replaceAll(RegExp(r'[*?"<>|]'), '');
    // Condense multiple spaces and hyphens
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'(\s*-\s*){2,}'), ' - ');
    // Strip control characters
    cleaned = cleaned.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    // Trim leading/trailing dots and spaces
    cleaned = cleaned.trim().replaceAll(RegExp(r'^\.+|\.+$'), '').trim();
    if (cleaned.isEmpty) {
      return 'Unknown';
    }
    // Limit to 90 chars for filesystem path safety
    if (cleaned.length > 90) {
      cleaned = cleaned.substring(0, 90).trim().replaceAll(RegExp(r'^\.+|\.+$'), '').trim();
    }
    return cleaned;
  }

  /// Resolves the audio container extension from stream URL or defaults to .m4a
  static String _resolveAudioExtension(String streamUrl) {
    try {
      final uri = Uri.parse(streamUrl);
      final path = uri.path.toLowerCase();
      if (path.endsWith('.mp3')) return '.mp3';
      if (path.endsWith('.flac')) return '.flac';
      if (path.endsWith('.wav')) return '.wav';
      if (path.endsWith('.ogg')) return '.ogg';
      if (path.endsWith('.opus')) return '.opus';
      if (path.endsWith('.aac')) return '.aac';
      if (path.endsWith('.m4a')) return '.m4a';
      if (path.endsWith('.mp4')) return '.mp4';
    } catch (_) {}
    return '.m4a';
  }

  /// Format duration helper (e.g. 233s -> "3:53")
  static String formatDuration(int seconds) {
    if (seconds <= 0) return '0:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Fetches synced and plain lyrics for offline bundling
  Future<Map<String, String>> fetchLyricsForSong(Song song) async {
    String? syncedLyrics;
    String? plainLyrics;

    // 1. Try Addon / API service
    try {
      final lyricsData = await apiService.getLyrics(
        song.title,
        song.artist,
        album: song.album,
        duration: song.duration,
      );
      if (lyricsData != null) {
        if (lyricsData['synced'] != null && lyricsData['synced'].toString().trim().isNotEmpty) {
          syncedLyrics = lyricsData['synced'].toString().trim();
        }
        if (lyricsData['plain'] != null && lyricsData['plain'].toString().trim().isNotEmpty) {
          plainLyrics = lyricsData['plain'].toString().trim();
        }
      }
    } catch (e) {
      debugPrint('[DownloadService] getLyrics error from API: $e');
    }

    // 2. Fallback to LRCLIB if synced lyrics not found
    if (syncedLyrics == null || syncedLyrics.isEmpty) {
      try {
        final cleanTitle = song.title
            .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
            .replaceAll(RegExp(r'\s*\[[^\]]*\]'), '')
            .trim();
        final cleanArtist = song.artist.split(',').first.split('&').first.trim();
        if (cleanTitle.isNotEmpty) {
          final queryParams = 'track_name=${Uri.encodeComponent(cleanTitle)}&artist_name=${Uri.encodeComponent(cleanArtist)}${song.duration > 0 ? '&duration=${song.duration}' : ''}';
          final url = Uri.parse('https://lrclib.net/api/get?$queryParams');
          final response = await httpClient.get(url).timeout(const Duration(seconds: 4));
          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            if (data is Map) {
              if (data['syncedLyrics'] != null && data['syncedLyrics'].toString().trim().isNotEmpty) {
                syncedLyrics = data['syncedLyrics'].toString().trim();
              }
              if (plainLyrics == null && data['plainLyrics'] != null && data['plainLyrics'].toString().trim().isNotEmpty) {
                plainLyrics = data['plainLyrics'].toString().trim();
              }
            }
          }
        }
      } catch (_) {}
    }

    final result = <String, String>{};
    if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
      result['synced'] = syncedLyrics;
    }
    if (plainLyrics != null && plainLyrics.isNotEmpty) {
      result['plain'] = plainLyrics;
    }
    return result;
  }

  /// Validates whether the application has write permissions to the specified directory
  static Future<bool> isPathWritable(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final testFile = File('${dir.path}/.perm_test_${DateTime.now().millisecondsSinceEpoch}');
      await testFile.writeAsString('test');
      if (await testFile.exists()) {
        await testFile.delete();
        return true;
      }
    } catch (e) {
      debugPrint('[DownloadService] Path $path is not writable: $e');
    }
    return false;
  }

  /// Returns the current directory where downloaded files are saved, safely falling back to Scoped Storage
  static Future<String> getDownloadDirectoryPathStatic() async {
    final settings = await StorageService.loadSettings();
    final customPath = settings['customDownloadPath'] ?? '';
    
    if (customPath.isNotEmpty && await isPathWritable(customPath)) {
      return customPath;
    }
    
    if (Platform.isAndroid) {
      try {
        final extDirs = await getExternalStorageDirectories(type: StorageDirectory.music);
        if (extDirs != null && extDirs.isNotEmpty) {
          final scopedPath = extDirs.first.path;
          if (await isPathWritable(scopedPath)) {
            return scopedPath;
          }
        }
      } catch (_) {}
    }
    
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/downloaded_music';
  }

  /// Returns the current directory where downloaded files are saved, safely falling back to Scoped Storage
  Future<String> getDownloadDirectoryPath() => getDownloadDirectoryPathStatic();

  /// Download a single song into its own dedicated folder containing audio, cover, lyrics, and metadata
  Future<bool> downloadSong(Song song, {Function(double)? onProgress}) async {
    try {
      if (Platform.isAndroid) {
        try {
          await Permission.notification.request();
        } catch (_) {}
      }
      final path = await getDownloadDirectoryPath();
      final musicDir = Directory(path);

      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }

      final streamUrl = await apiService.getStreamUrl(song);
      if (streamUrl == null || streamUrl.isEmpty) {
        debugPrint('[DownloadService] Could not resolve stream URL for ${song.title}');
        return false;
      }

      // Generate clean titles for folder and notification
      final cleanTitle = sanitizeFileName(song.title);
      final cleanArtist = (song.artist.isNotEmpty && song.artist != 'Unknown Artist')
          ? sanitizeFileName(song.artist)
          : '';
      
      final displayTitle = cleanArtist.isNotEmpty
          ? '${song.title} • ${song.artist}'
          : song.title;

      final folderName = cleanArtist.isNotEmpty
          ? '$cleanTitle - $cleanArtist'
          : cleanTitle;

      // Create dedicated folder for this song
      Directory songDir = Directory('${musicDir.path}/$folderName');
      if (await songDir.exists()) {
        final existingMeta = File('${songDir.path}/metadata.json');
        if (await existingMeta.exists()) {
          try {
            final meta = jsonDecode(await existingMeta.readAsString());
            if (meta is Map && meta['id'] != null && meta['id'] != song.id) {
              // Colliding title from another track - append unique suffix
              final safeId = song.id.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
              songDir = Directory('${musicDir.path}/${folderName}_$safeId');
            }
          } catch (_) {}
        }
      }

      if (!await songDir.exists()) {
        await songDir.create(recursive: true);
      }

      final extension = _resolveAudioExtension(streamUrl);
      final audioFileName = '$folderName$extension';
      final savedFilePath = '${songDir.path}/$audioFileName';

      // 1. Download Album Cover locally into the song folder
      bool hasCover = false;
      if (song.coverArt.isNotEmpty) {
        try {
          final coverResponse = await httpClient.get(Uri.parse(song.coverArt)).timeout(const Duration(seconds: 5));
          if (coverResponse.statusCode == 200) {
            final coverFile = File('${songDir.path}/cover.jpg');
            await coverFile.writeAsBytes(coverResponse.bodyBytes);
            hasCover = true;
          }
        } catch (e) {
          debugPrint('[DownloadService] Cover art download error: $e');
        }
      }

      // 2. Fetch & Save Lyrics locally into the song folder
      bool hasLyricsFile = false;
      bool hasSynced = false;
      bool hasPlain = false;
      try {
        final lyrics = await fetchLyricsForSong(song);
        if (lyrics['synced'] != null && lyrics['synced']!.isNotEmpty) {
          final lrcFile = File('${songDir.path}/lyrics.lrc');
          await lrcFile.writeAsString(lyrics['synced']!);
          hasLyricsFile = true;
          hasSynced = true;
        }
        if (lyrics['plain'] != null && lyrics['plain']!.isNotEmpty) {
          final txtFile = File('${songDir.path}/lyrics.txt');
          await txtFile.writeAsString(lyrics['plain']!);
          hasLyricsFile = true;
          hasPlain = true;
        }
      } catch (e) {
        debugPrint('[DownloadService] Lyrics download error: $e');
      }

      // 3. Save comprehensive metadata.json in the song folder
      try {
        final metadata = {
          'id': song.id,
          'saavnId': song.saavnId,
          'title': song.title,
          'artist': song.artist,
          'album': song.album,
          'duration': song.duration,
          'durationFormatted': formatDuration(song.duration),
          'coverArt': song.coverArt,
          'audioFile': audioFileName,
          'coverFile': hasCover ? 'cover.jpg' : null,
          'syncedLyricsFile': hasSynced ? 'lyrics.lrc' : null,
          'plainLyricsFile': hasPlain ? 'lyrics.txt' : null,
          'hasLyrics': hasLyricsFile || song.hasLyrics,
          'downloadedAt': DateTime.now().toIso8601String(),
          'app': 'IT-Feels',
        };
        final metaFile = File('${songDir.path}/metadata.json');
        await metaFile.writeAsString(const JsonEncoder.withIndent('  ').convert(metadata));
      } catch (e) {
        debugPrint('[DownloadService] Metadata writing error: $e');
      }

      bool downloadCompleted = false;

      // 4. Configure Background Download Task with original song name notifications
      try {
        final task = DownloadTask(
          url: streamUrl,
          filename: audioFileName,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://www.jiosaavn.com/',
            'Accept': '*/*',
          },
          directory: songDir.path,
          baseDirectory: BaseDirectory.root,
          updates: Updates.statusAndProgress,
          retries: 2,
          allowPause: true,
          metaData: song.id,
          displayName: displayTitle,
        );

        if (Platform.isAndroid || Platform.isIOS) {
          _downloader.configureNotificationForTask(
            task,
            running: TaskNotification('Downloading...', displayTitle),
            complete: TaskNotification('Download Complete', displayTitle),
            error: TaskNotification('Download Failed', displayTitle),
            progressBar: true,
          );
        }

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

      // 5. Fallback: Direct Streaming Download if Background Downloader was unsuccessful
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
        final coverLocalPath = '${songDir.path}/cover.jpg';
        final downloadedSong = Song(
          id: song.id,
          saavnId: song.saavnId,
          title: song.title,
          artist: song.artist,
          album: song.album,
          duration: song.duration,
          coverArt: hasCover ? coverLocalPath : song.coverArt,
          encryptedMediaUrl: savedFilePath,
          hasLyrics: hasLyricsFile || song.hasLyrics,
          addedAt: DateTime.now(),
        );

        final currentDownloads = await StorageService.loadDownloads();
        final cleanSongId = song.id.startsWith('saavn:') ? song.id.substring(6) : (song.id.startsWith('youtube:') ? song.id.substring(8) : song.id);
        currentDownloads.removeWhere((s) {
          if (s.id == song.id) return true;
          final sClean = s.id.startsWith('saavn:') ? s.id.substring(6) : (s.id.startsWith('youtube:') ? s.id.substring(8) : s.id);
          if (sClean == cleanSongId) return true;
          if (s.saavnId.isNotEmpty && (s.saavnId == song.id || s.saavnId == cleanSongId)) return true;
          return false;
        });
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

  /// Checks whether a downloaded song is missing crucial metadata or assets
  static bool isSongMissingDetails(Song song) =>
      MetadataRestorationService.isSongMissingDetails(song);

  /// Queries JioSaavn to restore full metadata, 500x500 album art, and lyrics
  Future<Song?> restoreSongMetadata(Song song) =>
      MetadataRestorationService().restoreSongMetadata(song);

  /// Restores missing metadata, covers, and lyrics across all downloaded songs in background.
  Future<int> restoreAllMissingMetadata({
    List<Song>? candidateSongs,
    Function(int current, int total, Song song)? onProgress,
  }) =>
      MetadataRestorationService().restoreAllMissingMetadata(
        candidateSongs: candidateSongs,
        onProgress: onProgress,
      );

  /// Discovers, validates, and recursively indexes downloaded songs across device storage.
  Future<List<Song>> scanAllDownloads() =>
      DownloadScannerService().scanAllDownloads();
}
