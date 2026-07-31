import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:it_feels_music/core/utils/hinglish_transliterator.dart';
import 'package:it_feels_music/core/utils/lrc_parser.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/services/backend_api_service.dart';

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

  final Map<String, LyricsResult> _lyricsCache = {};

  /// Check if lyrics are already cached
  bool isLyricsCached(String songId) => _lyricsCache.containsKey(songId);

  /// Preload lyrics into cache asynchronously
  Future<void> preloadLyrics(Song song) async {
    if (_lyricsCache.containsKey(song.id)) return;
    try {
      final res = await fetchLyrics(song);
      _lyricsCache[song.id] = res;
    } catch (_) {}
  }

  /// Fetch lyrics for a song (Races Proxy, LRCLIB, and Saavn concurrently)
  Future<LyricsResult> fetchLyrics(Song song, {Function(String)? onError}) async {
    if (_lyricsCache.containsKey(song.id)) {
      return _lyricsCache[song.id]!;
    }

    final completer = Completer<LyricsResult?>();
    int pendingCount = 0;

    void tryComplete(LyricsResult? res) {
      if (!completer.isCompleted) {
        if (res != null && (res.hasSynced || res.hasStatic)) {
          completer.complete(res);
        } else {
          pendingCount--;
          if (pendingCount <= 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        }
      }
    }

    if (BackendApiService.useProxyBackend) {
      pendingCount++;
      _fetchProxy(song).then(tryComplete).catchError((_) => tryComplete(null));
    }
    
    pendingCount++;
    _fetchLrcLib(song).then(tryComplete).catchError((_) => tryComplete(null));
    
    pendingCount++;
    _fetchSaavn(song, onError: onError).then(tryComplete).catchError((_) => tryComplete(null));

    if (pendingCount == 0) return LyricsResult();

    final result = await completer.future ?? LyricsResult();
    _lyricsCache[song.id] = result;
    return result;
  }

  Future<LyricsResult?> _fetchProxy(Song song) async {
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
    return null;
  }

  Future<LyricsResult?> _fetchSaavn(Song song, {Function(String)? onError}) async {
    try {
      final saavnId = song.saavnId.isNotEmpty ? song.saavnId : (song.id.startsWith('saavn:') ? song.id.split(':')[1] : song.id);
      if (saavnId.isNotEmpty && saavnId.length > 3 && !saavnId.startsWith('youtube:')) {
        final saavnUrl = Uri.parse(
            '$_saavnBaseUrl?__call=lyrics.getLyrics&_format=json&ctx=web6dot0&api_version=4&lyrics_id=$saavnId');
        final response = await http.get(saavnUrl, headers: _headers).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = await compute(jsonDecode, response.body);
          if (data['lyrics'] != null) {
            final rawStatic = _cleanText(data['lyrics'].toString());
            return LyricsResult(staticLyrics: HinglishTransliterator.transliterate(rawStatic));
          }
        }
      }
    } catch (e) {
      debugPrint('[LyricsService] Music API lyrics error: $e');
    }
    return null;
  }

  Future<LyricsResult?> _fetchLrcLib(Song song) async {
    try {
      final cleanTitle = song.title.replaceAll(RegExp(r'\s*\([^)]*\)'), '').replaceAll(RegExp(r'\s*\[[^\]]*\]'), '').trim();
      final cleanArtist = song.artist.split(',').first.split('&').first.trim();
      final query = '$cleanArtist $cleanTitle'.trim();
      if (query.isEmpty) return null;
      
      final lrclibUrl = Uri.parse(
          'https://lrclib.net/api/search?q=${Uri.encodeComponent(query)}');
      final response = await http.get(lrclibUrl).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = await compute(jsonDecode, response.body);
        if (data is List && data.isNotEmpty) {
          String? bestLrc;
          for (var item in data) {
            final trackName = item['trackName']?.toString() ?? '';
            final artistName = item['artistName']?.toString() ?? '';
            
            final targetTrack = trackName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
            final targetSongTitle = cleanTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
            final targetArtist = artistName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
            final targetSongArtist = cleanArtist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

            final titleSimilarity = targetTrack.similarityTo(targetSongTitle);
            final artistSimilarity = targetArtist.similarityTo(targetSongArtist);

            if (titleSimilarity < 0.3 && artistSimilarity < 0.2) continue;

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
            var syncedLrc = LrcParser.parse(bestLrc);
            syncedLrc = syncedLrc
                .map((line) => LyricLine(
                      time: line.time,
                      text: HinglishTransliterator.transliterate(line.text),
                    ))
                .toList();
            return LyricsResult(syncedLyrics: syncedLrc);
          }
        }
      }
    } catch (e) {
      debugPrint('[LyricsService] LRCLIB synced lyrics error: $e');
    }
    return null;
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
