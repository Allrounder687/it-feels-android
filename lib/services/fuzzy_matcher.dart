import 'dart:math';
import 'package:it_feels_music/data/models/song_model.dart';

/// FuzzyMatcher — matches AI-returned song names against the user's local library.
/// Provider-independent: works even when AI is unavailable.
class FuzzyMatcher {
  static final FuzzyMatcher instance = FuzzyMatcher._();
  FuzzyMatcher._();

  /// Levenshtein edit-distance between two strings.
  int levenshteinDistance(String s, String t) {
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    final n = s.length;
    final m = t.length;

    // Two-row optimisation (only need previous row + current row).
    var prev = List<int>.generate(m + 1, (j) => j);
    var curr = List<int>.filled(m + 1, 0);

    for (var i = 1; i <= n; i++) {
      curr[0] = i;
      for (var j = 1; j <= m; j++) {
        final cost = (s[i - 1] == t[j - 1]) ? 0 : 1;
        curr[j] = [
          prev[j] + 1, // deletion
          curr[j - 1] + 1, // insertion
          prev[j - 1] + cost, // substitution
        ].reduce(min);
      }
      // swap rows
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[m];
  }

  /// Score 0-100 for how well [query] matches [target]. Higher is better.
  double calculateScore(String query, String target) {
    if (query.isEmpty || target.isEmpty) return 0.0;

    final q = query.toLowerCase();
    final t = target.toLowerCase();

    if (q == t) return 100.0;
    if (t.startsWith(q)) return 90.0;
    if (t.contains(q)) return 75.0;

    final dist = levenshteinDistance(q, t);
    final maxLen = max(q.length, t.length);
    var similarity = maxLen > 0 ? 1.0 - (dist / maxLen) : 1.0;

    // Boost by common word overlap
    final qWords = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final tWords = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
    final common = qWords.where(tWords.contains).length;
    if (common > 0) {
      similarity += (common / qWords.length) * 0.1;
    }

    return min(similarity * 100, 99.9);
  }

  /// Return the best‐matching songs from [library] for [query].
  List<Song> findBestMatches(
    List<Song> library,
    String query, {
    int maxResults = 10,
    double threshold = 20.0,
  }) {
    if (library.isEmpty || query.isEmpty) return [];

    final scored = <MapEntry<Song, double>>[];
    final q = query.toLowerCase();

    for (final song in library) {
      final titleScore = calculateScore(q, song.title);
      final artistScore = calculateScore(q, song.artist);
      final albumScore = calculateScore(q, song.album);
      final genreScore = calculateScore(q, song.genre);

      // Weighted combination
      final total = (titleScore * 0.4) + (artistScore * 0.3) + (albumScore * 0.2) + (genreScore * 0.1);
      if (total >= threshold) {
        scored.add(MapEntry(song, total));
      }
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(maxResults).map((e) => e.key).toList();
  }

  /// Given AI-returned song names, resolve them to real library entries.
  List<Song> resolveAISuggestions(List<String> aiSongNames, List<Song> library) {
    final results = <Song>[];
    for (final name in aiSongNames) {
      final matches = findBestMatches(library, name, maxResults: 1, threshold: 40.0);
      if (matches.isNotEmpty) {
        results.add(matches.first);
      }
    }
    return results;
  }
}
