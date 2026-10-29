import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:it_feels_music/core/utils/string_utils.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/services/download_service.dart';
import 'package:it_feels_music/services/storage_service.dart';

/// Discovers, validates, and recursively indexes downloaded songs across device storage,
/// Scoped Storage paths, public Music directories, and custom folders.
class DownloadScannerService {
  /// Scans all local storage paths, Scoped Storage folders, public Music directories,
  /// and custom user paths to discover both bundled songs and legacy direct downloads.
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

    final Set<String> candidatePaths = {};

    // Candidate 0: Currently configured active download directory
    try {
      final activePath = await DownloadService.getDownloadDirectoryPathStatic();
      if (activePath.trim().isNotEmpty) {
        candidatePaths.add(activePath.trim());
      }
    } catch (_) {}

    // Candidate A: User custom path
    try {
      final settings = await StorageService.loadSettings();
      final customPath = settings['customDownloadPath']?.toString() ?? '';
      if (customPath.trim().isNotEmpty) {
        candidatePaths.add(customPath.trim());
      }
    } catch (_) {}

    // Candidate B: App-specific external storage directories
    if (Platform.isAndroid) {
      try {
        final extMusicDirs = await getExternalStorageDirectories(type: StorageDirectory.music);
        if (extMusicDirs != null) {
          for (final dir in extMusicDirs) {
            candidatePaths.add(dir.path);
          }
        }
      } catch (_) {}

      try {
        final extDownloadsDirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
        if (extDownloadsDirs != null) {
          for (final dir in extDownloadsDirs) {
            candidatePaths.add(dir.path);
          }
        }
      } catch (_) {}

      // Common Android music locations across current and past versions
      const androidCommonPaths = [
        '/storage/emulated/0/It Feels',
        '/storage/emulated/0/IT-Feels',
        '/storage/emulated/0/IT Feels',
        '/storage/emulated/0/It_Feels',
        '/storage/emulated/0/it_feels',
        '/sdcard/It Feels',
        '/sdcard/IT-Feels',
        '/sdcard/IT Feels',
        '/sdcard/Music/It Feels',
        '/sdcard/Music/IT-Feels',
        '/storage/emulated/0/Music/It Feels',
        '/storage/emulated/0/Music/IT-Feels',
        '/storage/emulated/0/Music/IT Feels',
        '/storage/emulated/0/Download/It Feels',
        '/storage/emulated/0/Download/IT-Feels',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Android/data/com.itfeels.music/files/Music',
        '/storage/emulated/0/Android/data/com.itfeels.music/files/Download',
        '/storage/emulated/0/Android/data/com.itfeels.music.debug/files/Music',
        '/storage/emulated/0/Android/data/com.itfeels.music.debug/files/Download',
        '/storage/emulated/0/Android/data/com.itfeels.it_feels/files/Music',
        '/storage/emulated/0/Android/data/com.itfeels.it_feels_alternate/files/Music',
      ];
      for (final p in androidCommonPaths) {
        candidatePaths.add(p);
      }
    }

    // Candidate C: App Documents Directory
    try {
      final docDir = await getApplicationDocumentsDirectory();
      candidatePaths.add(docDir.path);
      candidatePaths.add('${docDir.path}/downloaded_music');
      candidatePaths.add('${docDir.path}/Music');
      candidatePaths.add('${docDir.path}/It Feels');
    } catch (_) {}

    // Candidate D: Standard Downloads directory
    try {
      final dlDir = await getDownloadsDirectory();
      if (dlDir != null) {
        candidatePaths.add(dlDir.path);
        candidatePaths.add('${dlDir.path}/It Feels');
      }
    } catch (_) {}

    final audioExtensions = {'.mp4', '.m4a', '.mp3', '.aac', '.ogg', '.flac', '.wav', '.opus'};

    // 2. Scan every candidate directory recursively
    for (final pathStr in candidatePaths) {
      try {
        final dir = Directory(pathStr);
        if (!dir.existsSync()) continue;

        await _scanDirectoryRecursive(
          dir: dir,
          currentDepth: 0,
          maxDepth: 4,
          audioExtensions: audioExtensions,
          discoveredSongs: discoveredSongs,
          existingDownloads: existingDownloads,
        );
      } catch (e) {
        debugPrint('[DownloadScannerService] Error scanning candidate $pathStr: $e');
      }
    }

    final finalSongsList = discoveredSongs.values.toList();
    debugPrint('[DownloadScannerService] scanAllDownloads completed. Total songs discovered: ${finalSongsList.length}');
    await StorageService.saveDownloads(finalSongsList);
    return finalSongsList;
  }

  /// Recursively walks directories up to maxDepth discovering audio files & bundled metadata.
  Future<void> _scanDirectoryRecursive({
    required Directory dir,
    required int currentDepth,
    required int maxDepth,
    required Set<String> audioExtensions,
    required Map<String, Song> discoveredSongs,
    required List<Song> existingDownloads,
  }) async {
    if (currentDepth > maxDepth) return;

    try {
      final entities = dir.listSync(followLinks: false);
      final List<File> audioFiles = [];
      File? metadataFile;
      File? coverFile;
      File? lyricsLrcFile;

      final List<Directory> subDirs = [];

      for (final entity in entities) {
        if (entity is File) {
          final nameLower = entity.path.split(RegExp(r'[\\/]')).last.toLowerCase();
          if (nameLower == 'metadata.json') {
            metadataFile = entity;
          } else if (nameLower == 'cover.jpg' || nameLower == 'cover.png' || nameLower == 'album.jpg') {
            coverFile = entity;
          } else if (nameLower == 'lyrics.lrc' || nameLower.endsWith('.lrc')) {
            lyricsLrcFile = entity;
          } else {
            for (final ext in audioExtensions) {
              if (nameLower.endsWith(ext)) {
                audioFiles.add(entity);
                break;
              }
            }
          }
        } else if (entity is Directory) {
          final dirName = entity.path.split(RegExp(r'[\\/]')).last;
          if (!dirName.startsWith('.')) {
            subDirs.add(entity);
          }
        }
      }

      // If we found an audio file in this directory
      for (final audioFile in audioFiles) {
        if (discoveredSongs.containsKey(audioFile.path)) {
          continue;
        }

        final fileSize = audioFile.lengthSync();
        if (fileSize <= 0) continue; // Skip empty files

        Song? matchedExisting;
        final normPath = audioFile.path.replaceAll('\\', '/');
        for (final s in existingDownloads) {
          if (s.encryptedMediaUrl != null &&
              s.encryptedMediaUrl!.replaceAll('\\', '/').toLowerCase() == normPath.toLowerCase()) {
            matchedExisting = s;
            break;
          }
        }

        if (matchedExisting != null) {
          discoveredSongs[audioFile.path] = matchedExisting;
          continue;
        }

        // Case A: metadata.json exists
        if (metadataFile != null && metadataFile.existsSync()) {
          try {
            final jsonStr = metadataFile.readAsStringSync();
            final meta = jsonDecode(jsonStr);
            if (meta is Map<String, dynamic>) {
              final songId = meta['id']?.toString() ?? 'local_${audioFile.path.hashCode}';
              final saavnId = meta['saavnId']?.toString() ?? (songId.contains(':') ? songId.split(':').last : songId);
              final coverPath = coverFile?.path ?? meta['coverArt']?.toString() ?? '';
              
              final song = Song(
                id: songId,
                saavnId: saavnId,
                title: StringUtils.cleanText(meta['title']?.toString() ?? _extractTitleFromFileName(audioFile.path)),
                artist: StringUtils.cleanText(meta['artist']?.toString() ?? 'Unknown Artist'),
                album: StringUtils.cleanText(meta['album']?.toString() ?? 'Downloaded'),
                duration: int.tryParse(meta['duration']?.toString() ?? '0') ?? 0,
                coverArt: coverPath,
                encryptedMediaUrl: audioFile.path,
                hasLyrics: lyricsLrcFile != null || meta['hasLyrics'] == true,
                addedAt: meta['downloadedAt'] != null ? DateTime.tryParse(meta['downloadedAt']) ?? DateTime.now() : DateTime.now(),
                offlineStatus: OfflineStatus.downloaded,
                searchVector: Song.generateSearchVector(
                  meta['title']?.toString() ?? '',
                  meta['artist']?.toString() ?? '',
                  meta['album']?.toString() ?? '',
                ),
              );
              discoveredSongs[audioFile.path] = song;
              continue;
            }
          } catch (_) {}
        }

        // Case B: Loose audio file without metadata.json
        final fileName = audioFile.path.split(RegExp(r'[\\/]')).last;
        final (parsedTitle, parsedArtist) = _parseTitleAndArtist(fileName);

        // Check for companion cover art: <song_name>.jpg
        String foundCover = coverFile?.path ?? '';
        if (foundCover.isEmpty) {
          final dotIdx = audioFile.path.lastIndexOf('.');
          if (dotIdx > 0) {
            final companionJpg = File('${audioFile.path.substring(0, dotIdx)}.jpg');
            if (companionJpg.existsSync()) {
              foundCover = companionJpg.path;
            }
          }
        }

        String derivedSaavnId = '';
        if (fileName.startsWith('saavn_')) {
          final match = RegExp(r'saavn_([a-zA-Z0-9_-]+)').firstMatch(fileName);
          if (match != null) {
            derivedSaavnId = match.group(1) ?? '';
          }
        }

        final fallbackSong = Song(
          id: derivedSaavnId.isNotEmpty ? 'saavn:$derivedSaavnId' : 'local_${audioFile.path.hashCode}',
          saavnId: derivedSaavnId,
          title: parsedTitle,
          artist: parsedArtist,
          album: 'Downloaded',
          duration: 0,
          coverArt: foundCover,
          encryptedMediaUrl: audioFile.path,
          hasLyrics: lyricsLrcFile != null,
          addedAt: audioFile.lastModifiedSync(),
          offlineStatus: OfflineStatus.downloaded,
          searchVector: Song.generateSearchVector(parsedTitle, parsedArtist, 'Downloaded'),
        );

        discoveredSongs[audioFile.path] = fallbackSong;
      }

      // Recurse into subdirectories
      for (final subDir in subDirs) {
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
