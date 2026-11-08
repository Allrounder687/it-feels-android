import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:it_feels_music/core/utils/string_utils.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/services/download_service.dart';
import 'package:it_feels_music/services/storage_service.dart';
import 'package:it_feels_music/services/database_service.dart';
import 'package:it_feels_music/services/metadata_restoration_service.dart';

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
      // On mobile platforms (Android/iOS), docDir is the app-private sandbox.
      // On desktop (Windows/macOS/Linux), docDir is the user's root Documents folder,
      // so we DO NOT scan docDir.path root to avoid scanning personal documents & sound recordings.
      if (Platform.isAndroid || Platform.isIOS) {
        candidatePaths.add(docDir.path);
      }
      candidatePaths.add('${docDir.path}/downloaded_music');
      candidatePaths.add('${docDir.path}/Music');
      candidatePaths.add('${docDir.path}/Music/It Feels');
      candidatePaths.add('${docDir.path}/It Feels');
    } catch (_) {}

    // Candidate D: Standard Downloads directory
    try {
      final dlDir = await getDownloadsDirectory();
      if (dlDir != null) {
        // Confine search to dedicated app folders, avoiding the entire general Downloads folder
        candidatePaths.add('${dlDir.path}/It Feels');
        candidatePaths.add('${dlDir.path}/downloaded_music');
        candidatePaths.add('${dlDir.path}/Music');
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

    // 3. Deduplicate and filter out spurious non-music files
    final Map<String, Song> uniqueDiscovered = {};
    for (final song in discoveredSongs.values) {
      final filePath = song.encryptedMediaUrl ?? song.localFilePath ?? '';
      if (filePath.isEmpty) continue;
      final file = File(filePath);
      if (!file.existsSync() || file.lengthSync() <= 0) continue;

      // Filter out files from non-music user folders (e.g. Sound Recordings, video torrents, root documents videos)
      final normPath = filePath.toLowerCase().replaceAll('\\', '/');
      if (normPath.contains('/sound recordings/') ||
          normPath.contains('/playtorrio/') ||
          (normPath.contains('/documents/') &&
              !normPath.contains('/downloaded_music/') &&
              !normPath.contains('/it feels/') &&
              !normPath.contains('/music/')) ||
          (normPath.contains('/downloads/') &&
              !normPath.contains('/it feels/') &&
              !normPath.contains('/downloaded_music/'))) {
        continue;
      }

      uniqueDiscovered[song.id] = song;
    }

    final finalSongsList = uniqueDiscovered.values.toList();
    debugPrint('[DownloadScannerService] scanAllDownloads completed. Total songs discovered: ${finalSongsList.length}');
    await StorageService.saveDownloads(finalSongsList);
    try {
      await DatabaseService().saveSongs(finalSongsList);
    } catch (e) {
      debugPrint('[DownloadScannerService] DatabaseService saveSongs error: $e');
    }
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

        final dotIdx = audioFile.path.lastIndexOf('.');
        final audioBase = dotIdx > 0 ? audioFile.path.substring(0, dotIdx) : audioFile.path;

        // Check for companion JSON: <song_name>.json OR metadata.json
        File? companionJson = File('$audioBase.json');
        if (!companionJson.existsSync() && metadataFile != null && metadataFile.existsSync()) {
          companionJson = metadataFile;
        }

        // Check for companion Cover Art: <song_name>.jpg/.png OR cover.jpg/png in folder
        File? companionCover;
        for (final ext in ['.jpg', '.png', '.jpeg']) {
          final f = File('$audioBase$ext');
          if (f.existsSync()) {
            companionCover = f;
            break;
          }
        }
        companionCover ??= (coverFile != null && coverFile.existsSync()) ? coverFile : null;

        // Check for companion Lyrics: <song_name>.lrc/.txt OR lyrics.lrc/txt in folder
        File? companionLyrics = File('$audioBase.lrc');
        if (!companionLyrics.existsSync()) companionLyrics = File('$audioBase.txt');
        if (!companionLyrics.existsSync()) {
          companionLyrics = (lyricsLrcFile != null && lyricsLrcFile.existsSync()) ? lyricsLrcFile : null;
        }

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
          Song existing = matchedExisting;
          // If existing metadata was missing/garbled and we now have companionJson, restore it
          if (MetadataRestorationService.isSongMissingDetails(existing) &&
              companionJson != null &&
              companionJson.existsSync()) {
            try {
              final jsonStr = companionJson.readAsStringSync();
              final meta = jsonDecode(jsonStr);
              if (meta is Map<String, dynamic>) {
                existing = Song.fromJson(meta).copyWith(
                  encryptedMediaUrl: audioFile.path,
                  localFilePath: audioFile.path,
                  offlineStatus: OfflineStatus.downloaded,
                );
              }
            } catch (_) {}
          }

          final localCover = companionCover?.path ?? existing.coverArt;
          final updatedCover = (companionCover != null && (existing.coverArt.isEmpty || existing.coverArt.startsWith('http')))
              ? companionCover.path
              : localCover;
          final updatedLyrics = existing.hasLyrics || companionLyrics != null;
          final upgraded = existing.copyWith(
            coverArt: updatedCover,
            hasLyrics: updatedLyrics,
          );
          discoveredSongs[audioFile.path] = upgraded;
          continue;
        }

        // Case A: companionJson or metadata.json exists
        if (companionJson != null && companionJson.existsSync()) {
          try {
            final jsonStr = companionJson.readAsStringSync();
            final meta = jsonDecode(jsonStr);
            if (meta is Map<String, dynamic>) {
              final song = Song.fromJson(meta).copyWith(
                encryptedMediaUrl: audioFile.path,
                localFilePath: audioFile.path,
                coverArt: companionCover?.path ?? (meta['coverArt']?.toString() ?? ''),
                hasLyrics: companionLyrics != null || meta['hasLyrics'] == true,
                offlineStatus: OfflineStatus.downloaded,
              );
              discoveredSongs[audioFile.path] = song;
              continue;
            }
          } catch (_) {}
        }

        // Case B: Loose audio file without companion JSON
        final fileName = audioFile.path.split(RegExp(r'[\\/]')).last;
        final (parsedTitle, parsedArtist) = _parseTitleAndArtist(fileName);

        String derivedSaavnId = '';
        if (fileName.startsWith('saavn_')) {
          final match = RegExp(r'saavn_([a-zA-Z0-9_-]+)').firstMatch(fileName);
          if (match != null) {
            derivedSaavnId = match.group(1) ?? '';
            if (derivedSaavnId.startsWith('native_')) {
              derivedSaavnId = derivedSaavnId.replaceFirst('native_', '');
            }
          }
        }

        final fallbackSong = Song(
          id: derivedSaavnId.isNotEmpty ? 'saavn:$derivedSaavnId' : 'local_${audioFile.path.hashCode}',
          saavnId: derivedSaavnId,
          title: parsedTitle,
          artist: parsedArtist,
          album: 'Downloaded',
          duration: 0,
          coverArt: companionCover?.path ?? '',
          encryptedMediaUrl: audioFile.path,
          localFilePath: audioFile.path,
          hasLyrics: companionLyrics != null,
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
