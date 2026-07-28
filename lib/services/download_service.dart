import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/models/song_model.dart';
import '../data/services/music_api_service.dart';
import 'storage_service.dart';

class DownloadService {
  final MusicApiService apiService;

  DownloadService({required this.apiService});

  /// Download a single song for offline playback
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

      // Sanitize ID to avoid illegal characters like colons in the filename
      final safeId = song.id.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      // Download audio file
      final audioFile = File('${musicDir.path}/$safeId.mp4');
      final request = http.Request('GET', Uri.parse(streamUrl));
      final response = await http.Client().send(request);

      final totalBytes = response.contentLength ?? 0;
      int downloadedBytes = 0;
      final List<int> bytes = [];

      await for (var chunk in response.stream) {
        bytes.addAll(chunk);
        downloadedBytes += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(downloadedBytes / totalBytes);
        }
      }

      await audioFile.writeAsBytes(bytes);

      // Download cover art locally if available
      String localCover = song.coverArt;
      List<int>? coverBytes;
      if (song.coverArt.isNotEmpty) {
        try {
          final coverResponse = await http.get(Uri.parse(song.coverArt));
          if (coverResponse.statusCode == 200) {
            final coverFile = File('${musicDir.path}/$safeId.jpg');
            await coverFile.writeAsBytes(coverResponse.bodyBytes);
            localCover = coverFile.path;
            coverBytes = coverResponse.bodyBytes;
          }
        } catch (_) {}
      }

      // Write ID3 tags
      // Removed audiotags due to iOS arm64 FFI linker issues
      /*
      try {
        final tag = Tag(
          title: song.title,
          trackArtist: song.artist,
          album: song.album,
          pictures: coverBytes != null ? [
            Picture(
              bytes: Uint8List.fromList(coverBytes),
              mimeType: null,
              pictureType: PictureType.coverFront,
            )
          ] : [],
        );
        await AudioTags.write(audioFile.path, tag);
      } catch (e) {
        debugPrint('[DownloadService] ID3 Tag error: $e');
      }
      */

      // Create downloaded song entry
      final downloadedSong = Song(
        id: song.id,
        saavnId: song.saavnId,
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: song.duration,
        coverArt: localCover,
        encryptedMediaUrl: audioFile.path, // Local file path
        hasLyrics: song.hasLyrics,
        addedAt: DateTime.now(),
      );

      final currentDownloads = await StorageService.loadDownloads();
      currentDownloads.removeWhere((s) => s.id == song.id);
      currentDownloads.add(downloadedSong);

      await StorageService.saveDownloads(currentDownloads);
      debugPrint('[DownloadService] Successfully downloaded: ${song.title}');
      return true;
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
