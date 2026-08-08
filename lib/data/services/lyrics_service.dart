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
  final String source;

  LyricsResult({this.staticLyrics, this.syncedLyrics = const [], this.source = 'Unknown'});

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

  final Map<String, Map<String, LyricsResult>> _lyricsCache = {};
  static String? _musixmatchToken;

  /// Check if lyrics are already cached
  bool isLyricsCached(String songId) => _lyricsCache.containsKey(songId) && _lyricsCache[songId]!.isNotEmpty;

  /// Preload lyrics into cache asynchronously
  Future<void> preloadLyrics(Song song) async {
    if (isLyricsCached(song.id)) return;
    fetchLyrics(song, onResult: (_) {});
  }

  /// Fetch lyrics for a song (Races Proxy, LRCLIB, Musixmatch and Saavn concurrently)
  void fetchLyrics(Song song, {Function(String)? onError, required void Function(LyricsResult) onResult}) {
    if (_lyricsCache.containsKey(song.id) && _lyricsCache[song.id]!.isNotEmpty) {
      for (final res in _lyricsCache[song.id]!.values) {
        onResult(res);
      }
      return;
    }

    _lyricsCache[song.id] = {};

    void tryComplete(LyricsResult? res) {
      if (res != null && (res.hasSynced || res.hasStatic)) {
        _lyricsCache[song.id]![res.source] = res;
        onResult(res);
      }
    }

    if (BackendApiService.useProxyBackend) {
      unawaited(_fetchProxy(song).then(tryComplete).catchError((_) {}));
    }
    
    unawaited(_fetchLrcLib(song).then(tryComplete).catchError((_) {}));
    unawaited(_fetchMusixmatch(song).then(tryComplete).catchError((_) {}));
    unawaited(_fetchSaavn(song, onError: onError).then(tryComplete).catchError((_) {}));
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
            source: 'Proxy',
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
            return LyricsResult(staticLyrics: HinglishTransliterator.transliterate(rawStatic), source: 'JioSaavn');
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
      
      if (song.duration > 0) {
        final getUrl = Uri.parse(
            'https://lrclib.net/api/get?track_name=${Uri.encodeComponent(cleanTitle)}&artist_name=${Uri.encodeComponent(cleanArtist)}&duration=${song.duration}');
        final getResponse = await http.get(getUrl).timeout(const Duration(seconds: 3));
        if (getResponse.statusCode == 200) {
          final data = await compute(jsonDecode, getResponse.body);
          final rawSynced = data['syncedLyrics']?.toString();
          if (rawSynced != null && rawSynced.isNotEmpty) {
            var syncedLrc = LrcParser.parse(rawSynced);
            syncedLrc = syncedLrc.map((line) => LyricLine(
                  time: line.time,
                  text: HinglishTransliterator.transliterate(line.text),
                )).toList();
            return LyricsResult(syncedLyrics: syncedLrc, source: 'LRCLIB');
          }
        }
      }

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
            return LyricsResult(syncedLyrics: syncedLrc, source: 'LRCLIB');
          }
        }
      }
    } catch (e) {
      debugPrint('[LyricsService] LRCLIB lyrics error: $e');
    }
    return null;
  }

  Future<LyricsResult?> _fetchMusixmatch(Song song) async {
    try {
      if (_musixmatchToken == null) {
        final tokenUrl = Uri.parse('https://apic-desktop.musixmatch.com/ws/1.1/token.get?app_id=web-desktop-app-v1.0');
        final tokenRes = await http.get(tokenUrl, headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 3));
        if (tokenRes.statusCode == 200) {
          final tokenData = await compute(jsonDecode, tokenRes.body);
          _musixmatchToken = tokenData['message']?['body']?['user_token'];
        }
      }
      
      if (_musixmatchToken == null) return null;

      final cleanTitle = song.title.replaceAll(RegExp(r'\s*\([^)]*\)'), '').replaceAll(RegExp(r'\s*\[[^\]]*\]'), '').trim();
      final cleanArtist = song.artist.split(',').first.split('&').first.trim();

      final searchUrl = Uri.parse('https://apic-desktop.musixmatch.com/ws/1.1/macro.subtitles.get?format=json&q_track=${Uri.encodeComponent(cleanTitle)}&q_artist=${Uri.encodeComponent(cleanArtist)}&user_language=en&namespace=lyrics_synched&f_subtitle_length_max_deviation=1&subtitle_format=lrc&app_id=web-desktop-app-v1.0&usertoken=$_musixmatchToken');
      final searchRes = await http.get(searchUrl, headers: {'User-Agent': 'Mozilla/5.0', 'Cookie': 'x-mxm-token-guid=$_musixmatchToken'}).timeout(const Duration(seconds: 4));

      if (searchRes.statusCode == 200) {
        final data = await compute(jsonDecode, searchRes.body);
        final macroCalls = data['message']?['body']?['macro_calls'];
        
        if (macroCalls != null) {
          final subtitles = macroCalls['track.subtitles.get']?['message']?['body']?['subtitle_list'];
          if (subtitles != null && subtitles is List && subtitles.isNotEmpty) {
            final rawSynced = subtitles[0]['subtitle']?['subtitle_body'];
            if (rawSynced != null && rawSynced.toString().isNotEmpty) {
              var syncedLrc = LrcParser.parse(rawSynced.toString());
              syncedLrc = syncedLrc.map((line) => LyricLine(
                    time: line.time,
                    text: HinglishTransliterator.transliterate(line.text),
                  )).toList();
              return LyricsResult(syncedLyrics: syncedLrc, source: 'Musixmatch');
            }
          }
          
          final lyrics = macroCalls['track.lyrics.get']?['message']?['body']?['lyrics'];
          if (lyrics != null) {
            final rawStatic = lyrics['lyrics_body'];
            if (rawStatic != null && rawStatic.toString().isNotEmpty) {
              String cleanedStatic = rawStatic.toString().replaceAll(RegExp(r'\*+\s*This Lyrics is NOT for Commercial use\s*\*+'), '').trim();
              return LyricsResult(staticLyrics: HinglishTransliterator.transliterate(cleanedStatic), source: 'Musixmatch');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[LyricsService] Musixmatch lyrics error: $e');
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
