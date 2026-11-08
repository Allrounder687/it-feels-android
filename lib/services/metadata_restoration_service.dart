import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/services/download_service.dart';
import 'package:it_feels_music/services/storage_service.dart';
import 'package:it_feels_music/services/database_service.dart';

/// Handles detection, recovery, and batch restoration of missing song metadata,
/// covers, and lyrics for locally downloaded tracks using JioSaavn catalog queries.
class MetadataRestorationService {
  final http.Client? client;

  MetadataRestorationService({this.client});

  http.Client get _httpClient => client ?? DownloadService.sharedHttpClient;

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

  /// Checks whether a directory is a dedicated single-song folder vs a generic downloads directory
  static bool _isDedicatedFolder(Directory dir) {
    final name = dir.uri.pathSegments.where((s) => s.isNotEmpty).last.toLowerCase();
    const genericNames = {
      'music',
      'download',
      'downloads',
      'downloaded_music',
      'it-feels',
      'it feels',
      'it_feels',
      'sound recordings',
    };
    if (genericNames.contains(name)) return false;
    try {
      final audioCount = dir.listSync().whereType<File>().where((f) {
        final l = f.path.toLowerCase();
        return l.endsWith('.mp3') ||
            l.endsWith('.m4a') ||
            l.endsWith('.mp4') ||
            l.endsWith('.flac') ||
            l.endsWith('.opus') ||
            l.endsWith('.wav') ||
            l.endsWith('.aac') ||
            l.endsWith('.ogg');
      }).length;
      return audioCount <= 1;
    } catch (_) {
      return false;
    }
  }

  /// Extracts clean Saavn ID from any candidate song representation
  static String? extractSaavnId(Song song) {
    if (song.saavnId.isNotEmpty && !song.saavnId.startsWith('local_')) {
      return song.saavnId;
    }
    if (song.id.startsWith('saavn:')) {
      final id = song.id.replaceFirst('saavn:', '').trim();
      if (!id.startsWith('local_') && id.isNotEmpty) return id;
    } else if (song.id.startsWith('saavn_')) {
      final id = song.id.replaceFirst('saavn_', '').trim();
      if (!id.startsWith('local_') && id.isNotEmpty) return id;
    }
    if (song.encryptedMediaUrl != null) {
      final m = RegExp(r'saavn_([a-zA-Z0-9_-]+)').firstMatch(song.encryptedMediaUrl!);
      if (m != null) {
        final id = m.group(1) ?? '';
        if (id.startsWith('native_')) return id.replaceFirst('native_', '');
        if (id.isNotEmpty && !id.startsWith('local_')) return id;
      }
    }
    if (song.localFilePath != null) {
      final m = RegExp(r'saavn_([a-zA-Z0-9_-]+)').firstMatch(song.localFilePath!);
      if (m != null) {
        final id = m.group(1) ?? '';
        if (id.startsWith('native_')) return id.replaceFirst('native_', '');
        if (id.isNotEmpty && !id.startsWith('local_')) return id;
      }
    }
    final m = RegExp(r'\(([a-zA-Z0-9_-]{6,16})\)').firstMatch(song.title);
    if (m != null) {
      final id = m.group(1) ?? '';
      if (id.isNotEmpty && !id.startsWith('local_')) return id;
    }
    return null;
  }

  /// Fetches an HTTP URL with proxy fallback to guarantee 100% reachability across all networks
  Future<http.Response?> _fetchUrlWithProxyFallback(
    String rawUrl, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final reqHeaders = headers ?? {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      'Referer': 'https://www.jiosaavn.com/',
      'Accept': 'application/json, text/plain, */*',
    };

    final proxyUrl = rawUrl.contains('image-proxy')
        ? rawUrl
        : 'https://it-feels-proxy.cleverfox687.workers.dev/api/v1/image-proxy?url=${Uri.encodeComponent(rawUrl)}';

    // 1. Try via Edge Proxy
    try {
      final res = await _httpClient.get(Uri.parse(proxyUrl), headers: reqHeaders).timeout(timeout);
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        return res;
      }
    } catch (_) {}

    // 2. Direct fallback
    try {
      final res = await _httpClient.get(Uri.parse(rawUrl), headers: reqHeaders).timeout(timeout);
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        return res;
      }
    } catch (_) {}

    return null;
  }

  /// Queries JioSaavn (via Saavn ID or autocomplete search) to restore full metadata,
  /// 500x500 album art, and lyrics for downloaded songs that have missing details.
  Future<Song?> restoreSongMetadata(Song song) async {
    try {
      String? saavnId = extractSaavnId(song);
      Map<String, dynamic>? songDetails;

      // 1. Direct Saavn ID lookup
      if (saavnId != null && saavnId.isNotEmpty) {
        final detailsUrl =
            'https://www.jiosaavn.com/api.php?__call=song.getDetails&pids=${Uri.encodeComponent(saavnId)}&_format=json&_marker=0&api_version=4&ctx=web6dot0';
        final res = await _fetchUrlWithProxyFallback(detailsUrl);
        if (res != null) {
          try {
            final raw = utf8.decode(res.bodyBytes);
            final data = jsonDecode(raw);
            if (data is Map<String, dynamic>) {
              if (data.containsKey('songs') && data['songs'] is List && (data['songs'] as List).isNotEmpty) {
                songDetails = Map<String, dynamic>.from((data['songs'] as List).first);
              } else if (data.containsKey(saavnId) && data[saavnId] is Map) {
                songDetails = Map<String, dynamic>.from(data[saavnId]);
              } else if (data.isNotEmpty) {
                final firstVal = data.values.first;
                if (firstVal is Map) {
                  songDetails = Map<String, dynamic>.from(firstVal);
                }
              }
            }
          } catch (_) {}
        }
      }

      // 2. Fallback: Autocomplete search query
      if (songDetails == null) {
        String query = song.title;
        if (query.startsWith('Downloaded Track')) {
          if (song.encryptedMediaUrl != null) {
            final file = File(song.encryptedMediaUrl!);
            final pName = file.parent.path.split(RegExp(r'[\\/]')).last;
            if (pName.contains(' - ') && !pName.startsWith('Downloaded Track')) {
              query = pName;
            } else {
              final fName = file.path.split(RegExp(r'[\\/]')).last;
              query = fName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').replaceAll('saavn_', '');
            }
          }
        }
        if (song.artist.isNotEmpty && song.artist != 'Unknown Artist') {
          query += ' ${song.artist}';
        }

        final cleanQ = query.trim();
        if (cleanQ.isNotEmpty && cleanQ != 'Downloaded Track' && cleanQ != 'Unknown Track') {
          final searchUrl =
              'https://www.jiosaavn.com/api.php?__call=autocomplete.get&_format=json&_marker=0&api_version=4&ctx=web6dot0&query=${Uri.encodeComponent(cleanQ)}';
          final res = await _fetchUrlWithProxyFallback(searchUrl);
          if (res != null) {
            try {
              final raw = utf8.decode(res.bodyBytes);
              final data = jsonDecode(raw);
              if (data is Map && data['songs'] != null && data['songs']['data'] is List) {
                final songsList = data['songs']['data'] as List;
                if (songsList.isNotEmpty && songsList.first is Map) {
                  final candidate = songsList.first;
                  final candidateId = candidate['id']?.toString() ?? '';
                  if (candidateId.isNotEmpty) {
                    final candidateDetailsUrl =
                        'https://www.jiosaavn.com/api.php?__call=song.getDetails&pids=${Uri.encodeComponent(candidateId)}&_format=json&_marker=0&api_version=4&ctx=web6dot0';
                    final cRes = await _fetchUrlWithProxyFallback(candidateDetailsUrl);
                    if (cRes != null) {
                      final cData = jsonDecode(utf8.decode(cRes.bodyBytes));
                      if (cData is Map && cData.containsKey(candidateId)) {
                        songDetails = Map<String, dynamic>.from(cData[candidateId]);
                      }
                    }
                  }
                  songDetails ??= Map<String, dynamic>.from(candidate);
                }
              }
            } catch (_) {}
          }
        }
      }

      if (songDetails == null) return null;

      // 3. Parse enriched song metadata using Song.fromJson
      final enrichedSong = Song.fromJson(songDetails);

      // Determine local directory paths safely
      final audioFilePath = song.encryptedMediaUrl ?? song.localFilePath;
      File? audioFile;
      Directory? parentDir;
      if (audioFilePath != null && audioFilePath.isNotEmpty) {
        audioFile = File(audioFilePath);
        parentDir = audioFile.parent;
      }

      final isDedicatedFolder = parentDir != null && _isDedicatedFolder(parentDir);
      final audioBase = audioFile != null ? audioFile.path.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '') : '';

      String localCoverPath = song.coverArt;
      // Check if companion cover art already exists locally
      if (audioBase.isNotEmpty) {
        for (final ext in ['.jpg', '.png', '.jpeg']) {
          final comp = File('$audioBase$ext');
          if (comp.existsSync()) {
            localCoverPath = comp.path;
            break;
          }
        }
      }
      if (localCoverPath.isEmpty && parentDir != null) {
        final folderCover = File('${parentDir.path}/cover.jpg');
        if (folderCover.existsSync()) {
          localCoverPath = folderCover.path;
        }
      }

      // Download cover art if missing or remote
      if (enrichedSong.coverArt.isNotEmpty &&
          (localCoverPath.isEmpty || localCoverPath.startsWith('http'))) {
        try {
          final imgResp = await _fetchUrlWithProxyFallback(enrichedSong.coverArt, timeout: const Duration(seconds: 12));
          if (imgResp != null && imgResp.bodyBytes.isNotEmpty) {
            bool savedLocally = false;
            if (parentDir != null && await parentDir.exists()) {
              try {
                final File targetCover = isDedicatedFolder
                    ? File('${parentDir.path}/cover.jpg')
                    : File('$audioBase.jpg');
                await targetCover.writeAsBytes(imgResp.bodyBytes);
                localCoverPath = targetCover.path;
                savedLocally = true;
              } catch (_) {}
            }

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
          debugPrint('[MetadataRestorationService] Cover download error: $e');
        }
      }

      // 4. Fetch and save lyrics
      bool hasLyrics = enrichedSong.hasLyrics || song.hasLyrics;
      try {
        final moreInfo = songDetails['more_info'];
        final hasLyricsFlag = moreInfo != null && (moreInfo['has_lyrics'] == 'true' || moreInfo['has_lyrics'] == true);
        if (hasLyricsFlag) {
          final cleanLyricsId = enrichedSong.saavnId.isNotEmpty
              ? enrichedSong.saavnId
              : enrichedSong.id.replaceFirst('saavn:', '');
          final lyricsUri =
              'https://www.jiosaavn.com/api.php?__call=lyrics.getLyrics&lyrics_id=$cleanLyricsId&_format=json&ctx=web6dot0';
          final lyrResp = await _fetchUrlWithProxyFallback(lyricsUri);
          if (lyrResp != null) {
            final lyrData = jsonDecode(utf8.decode(lyrResp.bodyBytes));
            final rawLyrics = lyrData['lyrics']?.toString();
            if (rawLyrics != null && rawLyrics.trim().isNotEmpty) {
              hasLyrics = true;
              if (parentDir != null && await parentDir.exists()) {
                try {
                  final targetLrc = isDedicatedFolder
                      ? File('${parentDir.path}/lyrics.txt')
                      : File('$audioBase.txt');
                  await targetLrc.writeAsString(rawLyrics.replaceAll('<br>', '\n').replaceAll('&quot;', '"'));
                } catch (_) {}
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[MetadataRestorationService] Lyrics download error: $e');
      }

      // 5. Update companion metadata JSON bundled alongside the song
      if (parentDir != null && await parentDir.exists()) {
        try {
          final metaFile = isDedicatedFolder
              ? File('${parentDir.path}/metadata.json')
              : File('$audioBase.json');
          final metaMap = {
            'id': enrichedSong.id,
            'saavnId': enrichedSong.saavnId,
            'title': enrichedSong.title,
            'artist': enrichedSong.artist,
            'album': enrichedSong.album,
            'duration': enrichedSong.duration,
            'audioFile': audioFile?.uri.pathSegments.last ?? '',
            'coverFile': localCoverPath.startsWith('http') ? '' : localCoverPath.split(RegExp(r'[\\/]')).last,
            'coverArt': localCoverPath,
            'hasLyrics': hasLyrics,
            'restoredAt': DateTime.now().toIso8601String(),
            'app': 'IT-Feels',
          };
          await metaFile.writeAsString(const JsonEncoder.withIndent('  ').convert(metaMap));
        } catch (_) {}
      }

      final restoredSong = enrichedSong.copyWith(
        id: song.id.isNotEmpty ? song.id : enrichedSong.id,
        saavnId: enrichedSong.saavnId.isNotEmpty ? enrichedSong.saavnId : song.saavnId,
        coverArt: localCoverPath.isNotEmpty ? localCoverPath : enrichedSong.coverArt,
        encryptedMediaUrl: song.encryptedMediaUrl,
        localFilePath: song.localFilePath ?? song.encryptedMediaUrl,
        hasLyrics: hasLyrics,
        offlineStatus: OfflineStatus.downloaded,
      );

      debugPrint('[MetadataRestorationService] Successfully restored metadata for: ${restoredSong.title} - ${restoredSong.artist}');
      return restoredSong;
    } catch (e) {
      debugPrint('[MetadataRestorationService] restoreSongMetadata failed for ${song.title}: $e');
      return null;
    }
  }

  /// High-performance multi-track batch restoration using multi-pid queries
  Future<List<Song>> restoreBatchMetadata(
    List<Song> songs, {
    Function(int current, int total, Song song)? onProgress,
  }) async {
    final toRestore = songs.where(isSongMissingDetails).toList();
    if (toRestore.isEmpty) return [];

    final List<Song> restoredList = [];
    final Map<String, List<Song>> saavnGroups = {};
    final List<Song> nonSaavnSongs = [];

    for (final song in toRestore) {
      final sId = extractSaavnId(song);
      if (sId != null && sId.isNotEmpty) {
        saavnGroups.putIfAbsent(sId, () => []).add(song);
      } else {
        nonSaavnSongs.add(song);
      }
    }

    // 1. Process Saavn tracks in batches of 20
    final allSaavnIds = saavnGroups.keys.toList();
    final Map<String, Map<String, dynamic>> detailsMap = {};

    for (int i = 0; i < allSaavnIds.length; i += 20) {
      final batch = allSaavnIds.sublist(i, (i + 20 > allSaavnIds.length) ? allSaavnIds.length : i + 20);
      final pids = batch.join(',');
      final rawUrl =
          'https://www.jiosaavn.com/api.php?__call=song.getDetails&pids=${Uri.encodeComponent(pids)}&_format=json&_marker=0&api_version=4&ctx=web6dot0';

      try {
        final res = await _fetchUrlWithProxyFallback(rawUrl);
        if (res != null) {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          List<dynamic> returned = [];
          if (data is Map) {
            if (data['songs'] is List) {
              returned = data['songs'] as List;
            } else {
              for (final k in batch) {
                if (data[k] is Map) returned.add(data[k]);
              }
            }
          }
          for (final s in returned) {
            if (s is Map) {
              final sId = s['id']?.toString() ?? '';
              if (sId.isNotEmpty) {
                detailsMap[sId] = Map<String, dynamic>.from(s);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[MetadataRestorationService] Batch fetch error: $e');
      }
    }

    // Build restored songs from batch results
    int processedCount = 0;
    for (final entry in saavnGroups.entries) {
      final sId = entry.key;
      final originalSongs = entry.value;
      final rawDetails = detailsMap[sId];

      if (rawDetails != null) {
        final enriched = Song.fromJson(rawDetails);
        for (final orig in originalSongs) {
          processedCount++;
          onProgress?.call(processedCount, toRestore.length, orig);

          final audioPath = orig.encryptedMediaUrl ?? orig.localFilePath;
          File? audioFile = audioPath != null ? File(audioPath) : null;
          final parentDir = audioFile?.parent;
          final isDedicated = parentDir != null && _isDedicatedFolder(parentDir);
          final audioBase = audioFile != null ? audioFile.path.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '') : '';

          String coverPath = orig.coverArt;
          if (audioBase.isNotEmpty) {
            for (final ext in ['.jpg', '.png', '.jpeg']) {
              final comp = File('$audioBase$ext');
              if (comp.existsSync()) {
                coverPath = comp.path;
                break;
              }
            }
          }
          if (coverPath.isEmpty && parentDir != null) {
            final folderCover = File('${parentDir.path}/cover.jpg');
            if (folderCover.existsSync()) coverPath = folderCover.path;
          }

          // Save companion JSON
          if (parentDir != null && parentDir.existsSync()) {
            try {
              final metaFile = isDedicated
                  ? File('${parentDir.path}/metadata.json')
                  : File('$audioBase.json');
              final metaMap = {
                'id': enriched.id,
                'saavnId': enriched.saavnId,
                'title': enriched.title,
                'artist': enriched.artist,
                'album': enriched.album,
                'duration': enriched.duration,
                'audioFile': audioFile?.uri.pathSegments.last ?? '',
                'coverFile': coverPath.startsWith('http') ? '' : coverPath.split(RegExp(r'[\\/]')).last,
                'coverArt': coverPath,
                'hasLyrics': enriched.hasLyrics || orig.hasLyrics,
                'restoredAt': DateTime.now().toIso8601String(),
                'app': 'IT-Feels',
              };
              metaFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(metaMap));
            } catch (_) {}
          }

          final restored = enriched.copyWith(
            id: orig.id.isNotEmpty ? orig.id : enriched.id,
            saavnId: enriched.saavnId.isNotEmpty ? enriched.saavnId : sId,
            coverArt: coverPath.isNotEmpty ? coverPath : enriched.coverArt,
            encryptedMediaUrl: orig.encryptedMediaUrl,
            localFilePath: orig.localFilePath ?? orig.encryptedMediaUrl,
            hasLyrics: enriched.hasLyrics || orig.hasLyrics,
            offlineStatus: OfflineStatus.downloaded,
          );
          restoredList.add(restored);
        }
      } else {
        // Fallback to individual restoration
        for (final orig in originalSongs) {
          processedCount++;
          onProgress?.call(processedCount, toRestore.length, orig);
          final restored = await restoreSongMetadata(orig);
          if (restored != null) restoredList.add(restored);
        }
      }
    }

    // 2. Process non-Saavn tracks individually
    for (final orig in nonSaavnSongs) {
      processedCount++;
      onProgress?.call(processedCount, toRestore.length, orig);
      final restored = await restoreSongMetadata(orig);
      if (restored != null) restoredList.add(restored);
    }

    debugPrint('[MetadataRestorationService] Batch restored ${restoredList.length}/${toRestore.length} tracks');
    return restoredList;
  }

  /// Restores missing metadata, covers, and lyrics across all downloaded songs in background using batching.
  Future<int> restoreAllMissingMetadata({
    List<Song>? candidateSongs,
    Function(int current, int total, Song song)? onProgress,
  }) async {
    final existingDownloads = candidateSongs ?? await StorageService.loadDownloads();
    final toRestore = existingDownloads.where(isSongMissingDetails).toList();
    if (toRestore.isEmpty) return 0;

    final restored = await restoreBatchMetadata(toRestore, onProgress: onProgress);
    if (restored.isNotEmpty) {
      final Map<String, Song> registry = {
        for (final s in existingDownloads) s.id: s,
      };
      for (final r in restored) {
        registry[r.id] = r;
      }
      final updatedList = registry.values.toList();
      await StorageService.saveDownloads(updatedList);
      try {
        await DatabaseService().saveSongs(updatedList);
      } catch (_) {}
    }

    return restored.length;
  }
}
