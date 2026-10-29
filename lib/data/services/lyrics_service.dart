import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:it_feels_music/core/utils/hinglish_transliterator.dart';
import 'package:it_feels_music/core/utils/lrc_parser.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/services/backend_api_service.dart';

import 'package:string_similarity/string_similarity.dart';
import 'package:it_feels_music/services/database_service.dart';
import 'package:it_feels_music/data/models/cache_models.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';

class LyricsResult {
  final String? staticLyrics;
  final List<LyricLine> syncedLyrics;
  final String source;

  LyricsResult({this.staticLyrics, this.syncedLyrics = const [], this.source = 'Unknown'});

  bool get hasSynced => syncedLyrics.isNotEmpty;
  bool get hasStatic => staticLyrics != null && staticLyrics!.isNotEmpty;
}

class LyricsService {
  final Map<String, Map<String, LyricsResult>> _lyricsCache = {};
  int _currentSessionId = 0;

  void _enforceCacheLimit<K, V>(Map<K, V> cache, int maxSize) {
    while (cache.length > maxSize) {
      cache.remove(cache.keys.first);
    }
  }

  /// Check if lyrics are already cached
  bool isLyricsCached(String songId) => _lyricsCache.containsKey(songId) && _lyricsCache[songId]!.isNotEmpty;

  /// Preload lyrics into cache asynchronously
  Future<void> preloadLyrics(Song song) async {
    if (isLyricsCached(song.id)) return;
    fetchLyrics(song, onResult: (_) {});
  }

  /// Fetch lyrics for a song (Races Proxy, LRCLIB, Musixmatch and Saavn concurrently)
  /// Short-circuits: once a synced result is found, subsequent results are cached but deprioritized.
  void fetchLyrics(Song song, {Function(String)? onError, required void Function(LyricsResult) onResult}) {
    _currentSessionId++;
    final int sessionId = _currentSessionId;

    if (_lyricsCache.containsKey(song.id) && _lyricsCache[song.id]!.isNotEmpty) {
      for (final res in _lyricsCache[song.id]!.values) {
        onResult(res);
      }
      return;
    }

    _lyricsCache[song.id] = {};
    _enforceCacheLimit(_lyricsCache, 100);

    unawaited(_checkIsarAndFetch(song, sessionId, onResult, onError));
  }

  Future<void> _checkIsarAndFetch(Song song, int sessionId, void Function(LyricsResult) onResult, Function(String)? onError) async {
    final cached = await locator<DatabaseService>().getCachedLyrics(song.id);
    if (cached != null && sessionId == _currentSessionId) {
      try {
        List<LyricLine> synced = [];
        if (cached.syncedLyricsJson.isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(cached.syncedLyricsJson);
          synced = jsonList.map((e) => LyricLine.fromJson(e as Map<String, dynamic>)).toList();
        }
        
        final res = LyricsResult(
          staticLyrics: cached.staticLyrics,
          syncedLyrics: synced,
          source: cached.source,
        );
        
        _lyricsCache[song.id]![res.source] = res;
        onResult(res);
        return; // Cache hit, skip network fetch
      } catch (e) {
        debugPrint('[LyricsService] Error parsing cached Isar lyrics: $e');
      }
    }

    // Check if the song has local downloaded lyrics in its folder
    if (song.encryptedMediaUrl != null &&
        song.encryptedMediaUrl!.isNotEmpty &&
        !song.encryptedMediaUrl!.startsWith('http://') &&
        !song.encryptedMediaUrl!.startsWith('https://')) {
      try {
        final audioFile = File(song.encryptedMediaUrl!);
        if (audioFile.existsSync()) {
          final songDir = audioFile.parent;
          final lrcFile = File('${songDir.path}/lyrics.lrc');
          final txtFile = File('${songDir.path}/lyrics.txt');

          List<LyricLine> synced = [];
          String? staticLyrics;

          if (lrcFile.existsSync()) {
            final rawLrc = await lrcFile.readAsString();
            synced = LrcParser.parse(rawLrc).map((l) {
              final translit = HinglishTransliterator.transliterate(l.text);
              return LyricLine(
                time: l.time,
                text: l.text,
                transliteration: translit != l.text ? translit : null,
              );
            }).toList();
          }

          if (txtFile.existsSync()) {
            staticLyrics = await txtFile.readAsString();
          }

          if (synced.isNotEmpty || (staticLyrics != null && staticLyrics.isNotEmpty)) {
            final res = LyricsResult(
              staticLyrics: staticLyrics,
              syncedLyrics: synced,
              source: 'Downloaded',
            );
            _lyricsCache[song.id]![res.source] = res;
            if (sessionId == _currentSessionId) {
              onResult(res);
            }
            return;
          }
        }
      } catch (e) {
        debugPrint('[LyricsService] Error reading local lyrics file: $e');
      }
    }

    if (sessionId != _currentSessionId) return;

    bool hasSyncedResult = false;
    LyricsResult? pendingStaticResult;
    Timer? staticDebounceTimer;

    void tryComplete(LyricsResult? res) {
      if (sessionId != _currentSessionId) return; 
      
      if (res != null && (res.hasSynced || res.hasStatic)) {
        _lyricsCache[song.id]![res.source] = res;
        
        // Save to Isar
        final cacheObj = CachedLyrics()
          ..songId = song.id
          ..staticLyrics = res.staticLyrics
          ..syncedLyricsJson = jsonEncode(res.syncedLyrics.map((l) => l.toJson()).toList())
          ..source = res.source
          ..cachedAt = DateTime.now()
          ..expiryTime = DateTime.now().add(const Duration(days: 30));
        locator<DatabaseService>().saveCachedLyrics(cacheObj);
        
        if (res.hasSynced) {
          hasSyncedResult = true;
          staticDebounceTimer?.cancel();
        }
        
        if (!res.hasSynced && !hasSyncedResult) {
          pendingStaticResult = res;
          staticDebounceTimer?.cancel();
          staticDebounceTimer = Timer(const Duration(milliseconds: 500), () {
            if (sessionId == _currentSessionId && pendingStaticResult != null) {
              onResult(pendingStaticResult!);
            }
          });
        } else {
          onResult(res);
        }
      }
    }

    if (BackendApiService.useProxyBackend) {
      unawaited(_fetchProxy(song).then(tryComplete).catchError((_) {}));
    }
    
    unawaited(_fetchLrcLib(song).then(tryComplete).catchError((_) {}));
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
              .map((l) {
                final translit = HinglishTransliterator.transliterate(l.text);
                return LyricLine(
                  time: l.time,
                  text: l.text,
                  transliteration: translit != l.text ? translit : null,
                );
              })
              .toList();
        }

        final staticText = (plainStr != null && plainStr.isNotEmpty)
            ? HinglishTransliterator.transliterate(plainStr)
            : null;

        if (parsedSynced.isNotEmpty || staticText != null) {
          return LyricsResult(
            staticLyrics: staticText,
            syncedLyrics: parsedSynced,
            source: 'Saavn',
          );
        }
      }
    } catch (e) {
      debugPrint('[LyricsService] Backend proxy lyrics error: $e');
    }
    return null;
  }

  Future<LyricsResult?> _fetchSaavn(Song song) async {
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
            syncedLrc = syncedLrc.map((line) {
                  final translit = HinglishTransliterator.transliterate(line.text);
                  return LyricLine(
                    time: line.time,
                    text: line.text,
                    transliteration: translit != line.text ? translit : null,
                  );
                }).toList();
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
                .map((line) {
                  final translit = HinglishTransliterator.transliterate(line.text);
                  return LyricLine(
                    time: line.time,
                    text: line.text,
                    transliteration: translit != line.text ? translit : null,
                  );
                })
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