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
  Future<Map<String, String>> _fetchLyricsForSong(Song song) async {
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
  Future<String> getDownloadDirectoryPath() async {
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
        final lyrics = await _fetchLyricsForSong(song);
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
  /// (title placeholder, unknown artist, missing duration, or missing cover art).
  static bool isSongMissingDetails(Song song) {
    final title = song.title.trim().toLowerCase();
    if (title.isEmpty ||
        title.startsWith('downloaded track') ||
        title.startsWith('saavn_') ||
        title == 'unknown track' ||
        title == 'unknown') {
      return true;
    }
    final artist = song.artist.trim().toLowerCase();
    if (artist.isEmpty || artist == 'unknown artist' || artist == 'unknown') {
      return true;
    }
    if (song.duration <= 0) {
      return true;
    }
    if (song.coverArt.trim().isEmpty) {
      return true;
    }
    if (!song.coverArt.startsWith('http://') && !song.coverArt.startsWith('https://')) {
      final cleanPath = song.coverArt.startsWith('file://')
          ? song.coverArt.replaceFirst('file://', '')
          : song.coverArt;
      try {
        if (!File(cleanPath).existsSync()) return true;
      } catch (_) {
        return true;
      }
    }
    return false;
  }

  /// Queries JioSaavn (via Saavn ID or autocomplete search) to restore full metadata,
  /// 500x500 album art, and lyrics for downloaded songs that have missing details.
  Future<Song?> restoreSongMetadata(Song song) async {
    try {
      String? saavnId = song.saavnId.isNotEmpty ? song.saavnId : null;
      if (saavnId == null || saavnId.isEmpty) {
        if (song.id.startsWith('saavn_')) {
          saavnId = song.id.replaceFirst('saavn_', '');
        } else if (song.id.startsWith('saavn:')) {
          saavnId = song.id.replaceFirst('saavn:', '');
        }
      }

      // Check if audio filename or media url has saavn_XYZ
      if (saavnId == null || saavnId.isEmpty) {
        if (song.encryptedMediaUrl != null) {
          final m = RegExp(r'saavn_([a-zA-Z0-9_-]+)').firstMatch(song.encryptedMediaUrl!);
          if (m != null) {
            saavnId = m.group(1);
          }
        }
      }

      // Check if title has (saavnId) placeholder e.g. "Downloaded Track (xNVbUezC)"
      if (saavnId == null || saavnId.isEmpty) {
        final m = RegExp(r'\(([a-zA-Z0-9_-]{6,16})\)').firstMatch(song.title);
        if (m != null) {
          saavnId = m.group(1);
        }
      }

      Map<String, dynamic>? songDetails;

      // 1. Attempt direct lookup by Saavn ID if available
      if (saavnId != null && saavnId.isNotEmpty) {
        try {
          final uri = Uri.parse(
            'https://www.jiosaavn.com/api.php?__call=song.getDetails&pids=$saavnId&_format=json&_marker=0&api_version=4&ctx=web6dot0',
          );
          final resp = await httpClient.get(uri, headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          }).timeout(const Duration(seconds: 12));

          if (resp.statusCode == 200) {
            final data = jsonDecode(utf8.decode(resp.bodyBytes));
            if (data is Map && data['songs'] is List && (data['songs'] as List).isNotEmpty) {
              songDetails = (data['songs'] as List).first as Map<String, dynamic>;
            } else if (data is Map && data[saavnId] is Map) {
              songDetails = data[saavnId] as Map<String, dynamic>;
            }
          }
        } catch (e) {
          debugPrint('[DownloadService] song.getDetails lookup error for $saavnId: $e');
        }
      }

      // 2. If no saavnId or lookup failed, attempt search by query
      if (songDetails == null) {
        String searchQuery = '';
        if (song.title.isNotEmpty && !song.title.startsWith('Downloaded Track') && !song.title.startsWith('saavn_')) {
          searchQuery = song.title;
          if (song.artist.isNotEmpty && song.artist.toLowerCase() != 'unknown artist') {
            searchQuery += ' ${song.artist}';
          }
        } else if (song.encryptedMediaUrl != null && song.encryptedMediaUrl!.isNotEmpty) {
          final file = File(song.encryptedMediaUrl!);
          final baseName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : '';
          final parentName = file.parent.uri.pathSegments.where((s) => s.isNotEmpty).isNotEmpty
              ? file.parent.uri.pathSegments.where((s) => s.isNotEmpty).last
              : '';

          if (parentName.isNotEmpty &&
              parentName.contains(' - ') &&
              !parentName.toLowerCase().contains('download') &&
              !parentName.toLowerCase().contains('it-feels')) {
            searchQuery = parentName.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ');
          } else {
            final cleanBase = baseName
                .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
                .replaceFirst('saavn_', '')
                .replaceAll(RegExp(r'[_-]'), ' ')
                .trim();
            if (cleanBase.isNotEmpty) {
              searchQuery = cleanBase;
            }
          }
        }

        if (searchQuery.isNotEmpty) {
          try {
            // First try autocomplete.get
            final searchUri = Uri.parse(
              'https://www.jiosaavn.com/api.php?__call=autocomplete.get&query=${Uri.encodeComponent(searchQuery)}&_format=json&_marker=0&ctx=android',
            );
            final searchResp = await httpClient.get(searchUri, headers: {
              'User-Agent': 'Mozilla/5.0',
            }).timeout(const Duration(seconds: 10));

            if (searchResp.statusCode == 200) {
              final searchData = jsonDecode(utf8.decode(searchResp.bodyBytes));
              if (searchData is Map && searchData['songs'] is Map && searchData['songs']['data'] is List) {
                final list = searchData['songs']['data'] as List;
                if (list.isNotEmpty) {
                  final firstMatch = list.first as Map;
                  final matchId = firstMatch['id']?.toString();
                  if (matchId != null && matchId.isNotEmpty) {
                    final detailUri = Uri.parse(
                      'https://www.jiosaavn.com/api.php?__call=song.getDetails&pids=$matchId&_format=json&_marker=0&api_version=4&ctx=web6dot0',
                    );
                    final dResp = await httpClient.get(detailUri, headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 10));
                    if (dResp.statusCode == 200) {
                      final dData = jsonDecode(utf8.decode(dResp.bodyBytes));
                      if (dData is Map && dData['songs'] is List && (dData['songs'] as List).isNotEmpty) {
                        songDetails = (dData['songs'] as List).first as Map<String, dynamic>;
                      }
                    }
                  }
                }
              }
            }

            // Fallback to search.getResults if autocomplete didn't yield details
            if (songDetails == null) {
              final getResultsUri = Uri.parse(
                'https://www.jiosaavn.com/api.php?__call=search.getResults&q=${Uri.encodeComponent(searchQuery)}&_format=json&p=1&n=5',
              );
              final rResp = await httpClient.get(getResultsUri, headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 10));
              if (rResp.statusCode == 200) {
                final rData = jsonDecode(utf8.decode(rResp.bodyBytes));
                if (rData is Map && rData['results'] is List && (rData['results'] as List).isNotEmpty) {
                  final firstMatch = (rData['results'] as List).first as Map;
                  final matchId = firstMatch['id']?.toString();
                  if (matchId != null && matchId.isNotEmpty) {
                    final detailUri = Uri.parse(
                      'https://www.jiosaavn.com/api.php?__call=song.getDetails&pids=$matchId&_format=json&_marker=0&api_version=4&ctx=web6dot0',
                    );
                    final dResp = await httpClient.get(detailUri, headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 10));
                    if (dResp.statusCode == 200) {
                      final dData = jsonDecode(utf8.decode(dResp.bodyBytes));
                      if (dData is Map && dData['songs'] is List && (dData['songs'] as List).isNotEmpty) {
                        songDetails = (dData['songs'] as List).first as Map<String, dynamic>;
                      }
                    }
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('[DownloadService] Search lookup error: $e');
          }
        }
      }

      if (songDetails == null) return null;

      // 3. Parse enriched song metadata using Song.fromJson
      final enrichedSong = Song.fromJson(songDetails);

      // Determine local directory paths safely
      final audioFilePath = song.encryptedMediaUrl;
      File? audioFile;
      Directory? parentDir;
      if (audioFilePath != null && audioFilePath.isNotEmpty) {
        audioFile = File(audioFilePath);
        parentDir = audioFile.parent;
      }

      // Default localCoverPath to the high-res 500x500 CDN URL immediately!
      // This guarantees that coverArt is NEVER empty and the UI displays artwork even if disk write is blocked!
      String localCoverPath = enrichedSong.coverArt;

      if (enrichedSong.coverArt.isNotEmpty && enrichedSong.coverArt.startsWith('http')) {
        try {
          final imgResp = await httpClient.get(Uri.parse(enrichedSong.coverArt)).timeout(const Duration(seconds: 12));
          if (imgResp.statusCode == 200 && imgResp.bodyBytes.isNotEmpty) {
            bool savedLocally = false;
            // First attempt to save in the song's parent directory
            if (parentDir != null && await parentDir.exists()) {
              try {
                final isDedicatedFolder = parentDir.uri.pathSegments.where((s) => s.isNotEmpty).last.toLowerCase() != 'music' &&
                    parentDir.uri.pathSegments.where((s) => s.isNotEmpty).last.toLowerCase() != 'download' &&
                    parentDir.uri.pathSegments.where((s) => s.isNotEmpty).last.toLowerCase() != 'it-feels';

                final File targetCover = isDedicatedFolder
                    ? File('${parentDir.path}/cover.jpg')
                    : File('${parentDir.path}/${audioFile!.uri.pathSegments.last.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')}.jpg');
                await targetCover.writeAsBytes(imgResp.bodyBytes);
                localCoverPath = targetCover.path;
                savedLocally = true;
              } catch (_) {}
            }

            // Fallback: If external storage was write-restricted (Android 11+ Scoped Storage),
            // save cover into app documents directory which is ALWAYS 100% writable!
            if (!savedLocally) {
              try {
                final appDocs = await getApplicationDocumentsDirectory();
                final coversDir = Directory('${appDocs.path}/download_covers');
                if (!await coversDir.exists()) await coversDir.create(recursive: true);
                final safeId = enrichedSong.id.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
                final File appDocCover = File('${coversDir.path}/$safeId.jpg');
                await appDocCover.writeAsBytes(imgResp.bodyBytes);
                localCoverPath = appDocCover.path;
                savedLocally = true;
              } catch (_) {}
            }
          }
        } catch (e) {
          debugPrint('[DownloadService] Cover download error: $e');
        }
      }

      // 5. Fetch and save lyrics
      bool hasLyrics = enrichedSong.hasLyrics;
      try {
        final moreInfo = songDetails['more_info'];
        final hasLyricsFlag = moreInfo != null && (moreInfo['has_lyrics'] == 'true' || moreInfo['has_lyrics'] == true);
        if (hasLyricsFlag) {
          final cleanLyricsId = enrichedSong.saavnId.isNotEmpty
              ? enrichedSong.saavnId
              : enrichedSong.id.replaceFirst('saavn:', '');
          final lyricsUri = Uri.parse(
            'https://www.jiosaavn.com/api.php?__call=lyrics.getLyrics&lyrics_id=$cleanLyricsId&_format=json&ctx=web6dot0',
          );
          final lyrResp = await httpClient.get(lyricsUri, headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 10));
          if (lyrResp.statusCode == 200) {
            final lyrData = jsonDecode(utf8.decode(lyrResp.bodyBytes));
            final rawLyrics = lyrData['lyrics']?.toString();
            if (rawLyrics != null && rawLyrics.trim().isNotEmpty) {
              hasLyrics = true;
              if (parentDir != null && await parentDir.exists()) {
                try {
                  final targetLrc = File('${parentDir.path}/lyrics.txt');
                  await targetLrc.writeAsString(rawLyrics.replaceAll('<br>', '\n').replaceAll('&quot;', '"'));
                } catch (_) {}
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[DownloadService] Lyrics download error: $e');
      }

      // 6. Save or update metadata.json if directory is writable
      if (parentDir != null && await parentDir.exists()) {
        try {
          final metaFile = File('${parentDir.path}/metadata.json');
          final metadata = {
            'id': enrichedSong.id,
            'saavnId': enrichedSong.saavnId.isNotEmpty ? enrichedSong.saavnId : enrichedSong.id,
            'title': enrichedSong.title,
            'artist': enrichedSong.artist,
            'album': enrichedSong.album,
            'duration': enrichedSong.duration,
            'durationFormatted': formatDuration(enrichedSong.duration),
            'coverArt': localCoverPath,
            'audioFile': audioFile != null ? audioFile.uri.pathSegments.last : null,
            'coverFile': localCoverPath.endsWith('.jpg') ? 'cover.jpg' : null,
            'hasLyrics': hasLyrics,
            'downloadedAt': song.addedAt.toIso8601String(),
            'restoredAt': DateTime.now().toIso8601String(),
            'app': 'IT-Feels',
          };
          await metaFile.writeAsString(const JsonEncoder.withIndent('  ').convert(metadata));
        } catch (_) {}
      }

      // 7. Construct final restored song
      final restored = Song(
        id: song.id,
        saavnId: enrichedSong.saavnId.isNotEmpty ? enrichedSong.saavnId : (saavnId ?? enrichedSong.id),
        title: enrichedSong.title.isNotEmpty ? enrichedSong.title : song.title,
        artist: enrichedSong.artist.isNotEmpty ? enrichedSong.artist : song.artist,
        album: enrichedSong.album.isNotEmpty ? enrichedSong.album : song.album,
        duration: enrichedSong.duration > 0 ? enrichedSong.duration : song.duration,
        coverArt: localCoverPath.isNotEmpty ? localCoverPath : (enrichedSong.coverArt.isNotEmpty ? enrichedSong.coverArt : song.coverArt),
        encryptedMediaUrl: audioFilePath,
        hasLyrics: hasLyrics || song.hasLyrics,
        addedAt: song.addedAt,
      );

      return restored;
    } catch (e) {
      debugPrint('[DownloadService] restoreSongMetadata failed for ${song.title}: $e');
      return null;
    }
  }

  /// Restores missing metadata, covers, and lyrics across all downloaded songs in background.
  Future<int> restoreAllMissingMetadata({
    List<Song>? candidateSongs,
    Function(int current, int total, Song song)? onProgress,
  }) async {
    final existingDownloads = candidateSongs ?? await StorageService.loadDownloads();
    final toRestore = existingDownloads.where(isSongMissingDetails).toList();
    if (toRestore.isEmpty) return 0;

    int restoredCount = 0;
    final Map<String, Song> registry = {
      for (final s in existingDownloads) s.id: s,
    };

    for (int i = 0; i < toRestore.length; i++) {
      final song = toRestore[i];
      onProgress?.call(i + 1, toRestore.length, song);

      final restored = await restoreSongMetadata(song);
      if (restored != null) {
        registry[song.id] = restored;
        restoredCount++;
        await StorageService.saveDownloads(registry.values.toList());
      }

      await Future.delayed(const Duration(milliseconds: 150));
    }

    return restoredCount;
  }
  Future<List<Song>> scanAllDownloads() async {
    final Map<String, Song> discoveredSongs = {};

    // 1. Load currently tracked downloads
    final existingDownloads = await StorageService.loadDownloads();
    for (final song in existingDownloads) {
      if (song.encryptedMediaUrl != null && song.encryptedMediaUrl!.isNotEmpty) {
        try {
          final f = File(song.encryptedMediaUrl!);
          if (f.existsSync() && f.lengthSync() > 1024) {
            discoveredSongs[f.path] = song;
          }
        } catch (_) {}
      }
    }

    // 2. Assemble candidate directories to scan
    final Set<String> candidatePaths = {};

    // Primary download directory
    try {
      final primary = await getDownloadDirectoryPath();
      candidatePaths.add(primary);
    } catch (_) {}

    // Custom download path from user settings (unconditionally, without requiring write permission)
    try {
      final settings = await StorageService.loadSettings();
      final customPath = settings['customDownloadPath']?.toString().trim();
      if (customPath != null && customPath.isNotEmpty) {
        candidatePaths.add(customPath);
      }
    } catch (_) {}

    // Android external storage directories & storage roots
    if (Platform.isAndroid) {
      final roots = ['/storage/emulated/0', '/sdcard'];
      final folderNames = [
        'It Feels',
        'IT-Feels',
        'IT Feels',
        'IT_Feels',
        'it_feels',
        'it_feels_alternate',
        'IT-Feels-Alternate',
        'ITFeels',
        'downloaded_music',
      ];

      for (final root in roots) {
        for (final folder in folderNames) {
          candidatePaths.add('$root/$folder');
          candidatePaths.add('$root/Music/$folder');
          candidatePaths.add('$root/Download/$folder');
          candidatePaths.add('$root/Downloads/$folder');
          candidatePaths.add('$root/Documents/$folder');
        }
        candidatePaths.add('$root/Music');
        candidatePaths.add('$root/Download');
      }

      try {
        final extMusic = await getExternalStorageDirectories(type: StorageDirectory.music);
        if (extMusic != null) {
          for (final dir in extMusic) {
            candidatePaths.add(dir.path);
          }
        }
      } catch (_) {}

      try {
        final extDownloads = await getExternalStorageDirectories(type: StorageDirectory.downloads);
        if (extDownloads != null) {
          for (final dir in extDownloads) {
            candidatePaths.add(dir.path);
          }
        }
      } catch (_) {}

      try {
        final extRoot = await getExternalStorageDirectory();
        if (extRoot != null) {
          candidatePaths.add(extRoot.path);
          candidatePaths.add('${extRoot.path}/Music');
          candidatePaths.add('${extRoot.path}/downloaded_music');
        }
      } catch (_) {}

      // Package data and media paths across all package variants (debug, release, alternate)
      final packageNames = [
        'com.itfeels.music',
        'com.itfeels.music.debug',
        'com.itfeels.it_feels',
        'com.itfeels.it_feels.debug',
        'com.itfeels.it_feels_alternate',
        'com.example.it_feels_music',
        'com.example.it_feels',
      ];
      for (final pkg in packageNames) {
        candidatePaths.add('/storage/emulated/0/Android/data/$pkg/files/Music');
        candidatePaths.add('/storage/emulated/0/Android/data/$pkg/files/downloaded_music');
        candidatePaths.add('/storage/emulated/0/Android/data/$pkg/files');
        candidatePaths.add('/storage/emulated/0/Android/media/$pkg');
      }
    }

    // Documents & Support paths across all platforms
    try {
      final appDocs = await getApplicationDocumentsDirectory();
      candidatePaths.add('${appDocs.path}/downloaded_music');
      candidatePaths.add('${appDocs.path}/Music');
    } catch (_) {}

    try {
      final appSupport = await getApplicationSupportDirectory();
      candidatePaths.add('${appSupport.path}/downloaded_music');
      candidatePaths.add('${appSupport.path}/Music');
    } catch (_) {}

    const audioExtensions = ['.m4a', '.mp3', '.mp4', '.flac', '.wav', '.ogg', '.opus', '.aac'];

    // 3. Recursively scan candidate directories up to depth 4
    for (final dirPath in candidatePaths) {
      final dir = Directory(dirPath);
      await _scanDirectoryRecursive(
        dir: dir,
        currentDepth: 0,
        maxDepth: 4,
        audioExtensions: audioExtensions,
        discoveredSongs: discoveredSongs,
        existingDownloads: existingDownloads,
      );
    }

    // 4. Deduplicate by song.id and audio path
    final Map<String, Song> uniqueById = {};
    for (final song in discoveredSongs.values) {
      if (!uniqueById.containsKey(song.id)) {
        uniqueById[song.id] = song;
      } else {
        final existing = uniqueById[song.id]!;
        if (song.duration > existing.duration || (existing.coverArt.isEmpty && song.coverArt.isNotEmpty)) {
          uniqueById[song.id] = song;
        }
      }
    }

    final resultList = uniqueById.values.toList();
    resultList.sort((a, b) => b.addedAt.compareTo(a.addedAt));

    // 5. Persist back to storage
    await StorageService.saveDownloads(resultList);
    return resultList;
  }

  /// Safely traverses candidate directory trees up to [maxDepth],
  /// discovering bundled song directories, audio files, companion covers, and lyrics.
  Future<void> _scanDirectoryRecursive({
    required Directory dir,
    required int currentDepth,
    required int maxDepth,
    required List<String> audioExtensions,
    required Map<String, Song> discoveredSongs,
    required List<Song> existingDownloads,
  }) async {
    if (currentDepth > maxDepth) return;
    try {
      if (!dir.existsSync()) return;

      final entities = dir.listSync(followLinks: false);
      File? metaFile;
      File? coverFile;
      File? lrcFile;
      final List<File> audioFilesInDir = [];
      final List<Directory> subDirs = [];

      for (final entity in entities) {
        if (entity is File) {
          final name = entity.uri.pathSegments.last.toLowerCase();
          if (name == 'metadata.json') {
            metaFile = entity;
          } else if (name == 'cover.jpg' || name == 'cover.png' || name == 'album.jpg') {
            coverFile = entity;
          } else if (name == 'lyrics.lrc' || name == 'lyrics.txt') {
            lrcFile = entity;
          } else if (audioExtensions.any((ext) => name.endsWith(ext))) {
            try {
              if (entity.lengthSync() > 1024) {
                audioFilesInDir.add(entity);
              }
            } catch (_) {}
          }
        } else if (entity is Directory) {
          subDirs.add(entity);
        }
      }

      if (audioFilesInDir.isNotEmpty) {
        for (final audioFile in audioFilesInDir) {
          if (discoveredSongs.containsKey(audioFile.path)) continue;

          final fileName = audioFile.uri.pathSegments.last;
          final baseName = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;

          File? companionCover = coverFile;
          if (companionCover == null) {
            final testJpg = File('${audioFile.parent.path}/$baseName.jpg');
            final testPng = File('${audioFile.parent.path}/$baseName.png');
            if (testJpg.existsSync()) {
              companionCover = testJpg;
            } else if (testPng.existsSync()) {
              companionCover = testPng;
            }
          }

          Song? matchedExisting = existingDownloads.cast<Song?>().firstWhere(
            (s) =>
                s?.id == baseName ||
                s?.saavnId == baseName ||
                (s?.encryptedMediaUrl != null && s!.encryptedMediaUrl == audioFile.path) ||
                (s?.encryptedMediaUrl != null && s!.encryptedMediaUrl!.endsWith(fileName)),
            orElse: () => null,
          );

          Song? songResult;
          if (metaFile != null && metaFile.existsSync()) {
            try {
              final meta = jsonDecode(metaFile.readAsStringSync());
              if (meta is Map) {
                songResult = Song(
                  id: meta['id']?.toString() ?? 'scanned_${audioFile.path.hashCode.abs()}',
                  saavnId: meta['saavnId']?.toString() ?? '',
                  title: meta['title']?.toString() ?? _extractTitleFromFileName(audioFile.path),
                  artist: meta['artist']?.toString() ?? 'Unknown Artist',
                  album: meta['album']?.toString() ?? '',
                  duration: int.tryParse(meta['duration']?.toString() ?? meta['durationSeconds']?.toString() ?? '0') ?? 0,
                  coverArt: companionCover != null ? companionCover.path : (meta['coverArt']?.toString() ?? ''),
                  encryptedMediaUrl: audioFile.path,
                  hasLyrics: meta['hasLyrics'] == true || lrcFile != null,
                  addedAt: DateTime.tryParse(meta['downloadedAt']?.toString() ?? '') ?? audioFile.lastModifiedSync(),
                );
              }
            } catch (_) {}
          }

          if (songResult == null && matchedExisting != null) {
            songResult = Song(
              id: matchedExisting.id,
              saavnId: matchedExisting.saavnId,
              title: matchedExisting.title,
              artist: matchedExisting.artist,
              album: matchedExisting.album,
              duration: matchedExisting.duration,
              coverArt: companionCover != null ? companionCover.path : matchedExisting.coverArt,
              encryptedMediaUrl: audioFile.path,
              hasLyrics: matchedExisting.hasLyrics || lrcFile != null,
              addedAt: matchedExisting.addedAt,
            );
          }

          if (songResult == null) {
            final folderName = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
            final (parsedTitle, parsedArtist) = _parseTitleAndArtist(
              baseName.startsWith('saavn_') ? baseName : (folderName.contains(' - ') ? folderName : baseName),
            );

            String extractedSaavnId = '';
            if (baseName.startsWith('saavn_')) {
              extractedSaavnId = baseName.replaceFirst('saavn_', '');
            }

            songResult = Song(
              id: extractedSaavnId.isNotEmpty ? 'saavn_$extractedSaavnId' : 'scanned_${audioFile.path.hashCode.abs()}',
              saavnId: extractedSaavnId,
              title: parsedTitle,
              artist: parsedArtist,
              album: '',
              duration: 0,
              coverArt: companionCover != null ? companionCover.path : '',
              encryptedMediaUrl: audioFile.path,
              hasLyrics: lrcFile != null,
              addedAt: audioFile.lastModifiedSync(),
            );
          }

          discoveredSongs[audioFile.path] = songResult;
        }
      }

      for (final subDir in subDirs) {
        final dirName = subDir.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (dirName.startsWith('.')) continue;

        await _scanDirectoryRecursive(
          dir: subDir,
          currentDepth: currentDepth + 1,
          maxDepth: maxDepth,
          audioExtensions: audioExtensions,
          discoveredSongs: discoveredSongs,
          existingDownloads: existingDownloads,
        );
      }
    } catch (_) {}
  }

  static (String, String) _parseTitleAndArtist(String name) {
    String clean = StringUtils.cleanText(name);
    final dotIndex = clean.lastIndexOf('.');
    if (dotIndex > 0) {
      clean = clean.substring(0, dotIndex);
    }
    if (clean.startsWith('saavn_')) {
      final shortId = clean.replaceFirst('saavn_', '');
      final idDisplay = shortId.length > 8 ? shortId.substring(0, 8) : shortId;
      return ('Downloaded Track ($idDisplay)', 'Unknown Artist');
    }

    if (clean.contains(' - ')) {
      final parts = clean.split(' - ');
      final title = parts[0].trim();
      final artist = parts.sublist(1).join(' - ').trim();
      return (title.isNotEmpty ? title : 'Unknown Track', artist.isNotEmpty ? artist : 'Unknown Artist');
    }
    return (clean.isNotEmpty ? clean : 'Unknown Track', 'Unknown Artist');
  }

  static String _extractTitleFromFileName(String path) {
    try {
      final seg = path.split(RegExp(r'[\\/]')).last;
      final dot = seg.lastIndexOf('.');
      final name = dot > 0 ? seg.substring(0, dot) : seg;
      return StringUtils.cleanText(name);
    } catch (_) {
      return 'Downloaded Track';
    }
  }
}
