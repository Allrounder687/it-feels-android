import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/services/download_service.dart';
import 'package:it_feels_music/services/storage_service.dart';

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

      // 1. Direct Saavn ID lookup
      if (saavnId != null && saavnId.isNotEmpty) {
        final detailsUrl =
            'https://www.jiosaavn.com/api.php?__call=song.getDetails&pids=${Uri.encodeComponent(saavnId)}&_format=json&_marker=0&api_version=4&ctx=web6dot0';
        try {
          final res = await _httpClient.get(
            Uri.parse(detailsUrl),
            headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
          ).timeout(const Duration(seconds: 10));

          if (res.statusCode == 200) {
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
          }
        } catch (_) {}
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
          try {
            final res = await _httpClient.get(
              Uri.parse(searchUrl),
              headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
            ).timeout(const Duration(seconds: 10));

            if (res.statusCode == 200) {
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
                    final cRes = await _httpClient.get(
                      Uri.parse(candidateDetailsUrl),
                      headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
                    ).timeout(const Duration(seconds: 10));
                    if (cRes.statusCode == 200) {
                      final cData = jsonDecode(utf8.decode(cRes.bodyBytes));
                      if (cData is Map && cData.containsKey(candidateId)) {
                        songDetails = Map<String, dynamic>.from(cData[candidateId]);
                      }
                    }
                  }
                  songDetails ??= Map<String, dynamic>.from(candidate);
                }
              }
            }
          } catch (_) {}
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

      String localCoverPath = enrichedSong.coverArt;

      if (enrichedSong.coverArt.isNotEmpty && enrichedSong.coverArt.startsWith('http')) {
        try {
          final imgResp = await _httpClient.get(Uri.parse(enrichedSong.coverArt)).timeout(const Duration(seconds: 12));
          if (imgResp.statusCode == 200 && imgResp.bodyBytes.isNotEmpty) {
            bool savedLocally = false;
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
          final lyrResp = await _httpClient.get(lyricsUri, headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 10));
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
        debugPrint('[MetadataRestorationService] Lyrics download error: $e');
      }

      // 6. Update metadata.json bundled alongside the song
      if (parentDir != null && await parentDir.exists()) {
        try {
          final metaFile = File('${parentDir.path}/metadata.json');
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
          };
          await metaFile.writeAsString(const JsonEncoder.withIndent('  ').convert(metaMap));
        } catch (_) {}
      }

      final restoredSong = enrichedSong.copyWith(
        coverArt: localCoverPath,
        encryptedMediaUrl: song.encryptedMediaUrl,
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
}
