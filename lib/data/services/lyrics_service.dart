import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/utils/hinglish_transliterator.dart';
import '../../core/utils/lrc_parser.dart';
import '../models/song_model.dart';
import '../../services/backend_api_service.dart';

import 'package:string_similarity/string_similarity.dart';

class LyricsResult {
  final String? staticLyrics;
  final List<LyricLine> syncedLyrics;

  LyricsResult({this.staticLyrics, this.syncedLyrics = const []});

  bool get hasSynced => syncedLyrics.isNotEmpty;
  bool get hasStatic => staticLyrics != null && staticLyrics!.isNotEmpty;
}

class LyricsService {
  static const String _saavnBaseUrl = 'https://www.jiosaavn.com/api.php';
  static final Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json',
  };

  /// Fetch lyrics for a song (Proxy API -> LRCLIB / Saavn Fallback)
  Future<LyricsResult> fetchLyrics(Song song, {Function(String)? onError}) async {
    // 0. Try Backend Proxy API if enabled
    if (BackendApiService.useProxyBackend) {
      try {
        final proxyResult = await BackendApiService.getLyrics(
          song.title,
          song.artist,
          album: song.album,
          duration: song.duration,
        );

        if (proxyResult != null) {
          final syncedStr = proxyResult['synced'];
          final plainStr = proxyResult['plain'];

          List<LyricLine> parsedSynced = [];
          if (syncedStr != null && syncedStr.isNotEmpty) {
            parsedSynced = LrcParser.parse(syncedStr)
                .map((l) => LyricLine(
                      time: l.time,
                      text: HinglishTransliterator.transliterate(l.text),
                    ))
                .toList();
          }

          final staticText = (plainStr != null && plainStr.isNotEmpty)
              ? HinglishTransliterator.transliterate(plainStr)
              : null;

          if (parsedSynced.isNotEmpty || staticText != null) {
            return LyricsResult(
              staticLyrics: staticText,
              syncedLyrics: parsedSynced,
            );
          }
        }
      } catch (e) {
        debugPrint('[LyricsService] Backend proxy lyrics error: $e');
      }
    }

    String? staticLrc;
    List<LyricLine> syncedLrc = [];

    // 1. Try Music API static lyrics
    try {
      final saavnUrl = Uri.parse(
          '$_saavnBaseUrl?__call=lyrics.getLyrics&_format=json&ctx=web6dot0&api_version=4&lyrics_id=${song.saavnId}');
      final response = await http.get(saavnUrl, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['lyrics'] != null) {
          final rawStatic = _cleanText(data['lyrics'].toString());
          staticLrc = HinglishTransliterator.transliterate(rawStatic);
        }
      }
    } catch (e) {
      debugPrint('[LyricsService] Music API lyrics error: $e');
      if (onError != null) onError('Failed to load Music API lyrics');
    }

    // 2. Try LRCLIB for synced LRC lyrics
    try {
      final query = '${song.artist} ${song.title}'.trim();
      final lrclibUrl = Uri.parse(
          'https://lrclib.net/api/search?q=${Uri.encodeComponent(query)}');
      final response = await http.get(lrclibUrl);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          String? bestLrc;
          for (var item in data) {
            final trackName = item['trackName']?.toString() ?? '';
            final artistName = item['artistName']?.toString() ?? '';
            
            // Clean strings for comparison
            final cleanTrack = trackName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
            final cleanSongTitle = song.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
            final cleanArtist = artistName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
            final cleanSongArtist = song.artist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

            // Calculate similarity
            final titleSimilarity = cleanTrack.similarityTo(cleanSongTitle);
            final artistSimilarity = cleanArtist.similarityTo(cleanSongArtist);

            // Skip if the result is completely unrelated to our song
            if (titleSimilarity < 0.4 && artistSimilarity < 0.3) {
              continue;
            }

            final rawSynced = item['syncedLyrics']?.toString();
            if (rawSynced != null && rawSynced.isNotEmpty) {
              if (!HinglishTransliterator.hasDevanagari(rawSynced)) {
                bestLrc = rawSynced;
                break;
              } else {
                bestLrc ??= rawSynced;
              }
            }
          }

          if (bestLrc != null) {
            syncedLrc = LrcParser.parse(bestLrc);
            syncedLrc = syncedLrc
                .map((line) => LyricLine(
                      time: line.time,
                      text: HinglishTransliterator.transliterate(line.text),
                    ))
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('[LyricsService] LRCLIB synced lyrics error: $e');
    }

    return LyricsResult(
      staticLyrics: staticLrc,
      syncedLyrics: syncedLrc,
    );
  }

  static String _cleanText(String input) {
    return input
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('<br/>', '\n')
        .replaceAll('<br />', '\n')
        .replaceAll('<br>', '\n')
        .replaceAll('&nbsp;', ' ');
  }
}
