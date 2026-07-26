import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/utils/hinglish_transliterator.dart';
import '../../core/utils/lrc_parser.dart';
import '../../core/utils/string_utils.dart'; // Import StringUtils
import '../models/song_model.dart';

/// A container class to hold both static and synchronized lyrics for a song.
///
/// - [staticLyrics]: A plain text string of lyrics.
/// - [syncedLyrics]: A list of [LyricLine] objects, each with a timestamp and text.
class LyricsResult {
  final String? staticLyrics;
  final List<LyricLine> syncedLyrics;

  /// Constructs a [LyricsResult] instance.
  LyricsResult({this.staticLyrics, this.syncedLyrics = const []});

  /// Returns `true` if synchronized lyrics are available.
  bool get hasSynced => syncedLyrics.isNotEmpty;

  /// Returns `true` if static lyrics are available.
  bool get hasStatic => staticLyrics != null && staticLyrics!.isNotEmpty;
}

/// `LyricsService` is responsible for fetching song lyrics from various sources
/// and processing them into displayable formats.
///
/// It implements a fallback strategy, attempting to retrieve static lyrics from
/// JioSaavn and synchronized LRC lyrics from LRCLIB. It also leverages
/// [HinglishTransliterator] for language conversion and [LrcParser] for LRC text processing.
class LyricsService {
  static const String _saavnBaseUrl = 'https://www.jiosaavn.com/api.php';
  static final Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json',
  };

        if (data['lyrics'] != null) {
          final rawStatic = StringUtils.cleanText(data['lyrics'].toString());
          staticLrc = HinglishTransliterator.transliterate(rawStatic); // Transliterate for consistency
        }
      } else {
        final errorMessage = 'Failed to fetch static lyrics from JioSaavn. Status code: ${response.statusCode}';
        onError?.call('Could not load static lyrics.');
        debugPrint('[LyricsService] $errorMessage');
      }
    } catch (e) {
      final errorMessage = 'JioSaavn lyrics error: $e';
      onError?.call('Could not load static lyrics.');
      debugPrint('[LyricsService] $errorMessage');
      // Continue even if static lyrics fail, as synced lyrics might still be available.
    }

    // 2. Try LRCLIB for synced LRC lyrics (Prefer Romanized/Latin script, fallback to Devanagari transliteration)
    try {
      final query = '${song.artist} ${song.title}'.trim();
      final lrclibUrl = Uri.parse(
          'https://lrclib.net/api/search?q=${Uri.encodeComponent(query)}');
      final response = await http.get(lrclibUrl);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          String? bestLrc;
          // Priority 1: Find a match with synced lyrics in Latin/Romanized script
          for (var item in data) {
            final rawSynced = item['syncedLyrics']?.toString();
            if (rawSynced != null && rawSynced.isNotEmpty) {
              // Check if it primarily contains Devanagari characters
              if (!HinglishTransliterator.hasDevanagari(rawSynced)) {
                bestLrc = rawSynced; // Found a Romanized synced lyric, prefer this
                break;
              } else if (bestLrc == null) {
                bestLrc = rawSynced; // Keep the first Devanagari if no Romanized is found yet
              }
            }
          }

          if (bestLrc != null) {
            syncedLrc = LrcParser.parse(bestLrc); // Parse the raw LRC text
            // Convert any remaining Devanagari lines in synced lyrics to Hinglish
            syncedLrc = syncedLrc
                .map((line) => LyricLine(
                      time: line.time,
                      text: HinglishTransliterator.transliterate(line.text),
                    ))
                .toList();
          }
        }
      } else {
        final errorMessage = 'Failed to fetch synced lyrics from LRCLIB. Status code: ${response.statusCode}';
        onError?.call('Could not load synced lyrics.');
        debugPrint('[LyricsService] $errorMessage');
      }
    } catch (e) {
      final errorMessage = 'LRCLIB synced lyrics error: $e';
      onError?.call('Could not load synced lyrics.');
      debugPrint('[LyricsService] $errorMessage');
      // Continue even if synced lyrics fail.
    }

    return LyricsResult(
      staticLyrics: staticLrc,
      syncedLyrics: syncedLrc,
    );
  }

  /// Helper method to clean up common HTML entities and `<br/>` tags from lyric text.
  /// Used for JioSaavn static lyrics to prepare them for display.
  static String _cleanText(String input) {
    return input
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'<br\s*\/?>'), '\n') // Replace all variations of <br> tags with newline
        .replaceAll('&nbsp;', ' ');
  }
}
