import 'package:it_feels_music/core/utils/track_validation_engine.dart';
import 'package:it_feels_music/data/models/song_model.dart';

/// Resolves metadata-only recordings through installed catalogue providers.
/// No provider endpoints, scraping, or guessed media URLs live here.
class ConnectedTrackAudioResolver {
  static String normalize(String text) => text
      .toLowerCase()
      .replaceAll(
        RegExp(
          r'\b(official music video|official video|official audio|lyric video|lyrics|visualizer|vevo|topic)\b',
        ),
        ' ',
      )
      .replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static List<Song> matches(Song original, List<Song> candidates) {
    if (original.duration > 1200) {
      return []; // Long mixes need creator chapters.
    }
    final label = normalize(original.title).split(' ').toSet();
    final artist = normalize(
      original.artist,
    ).split(' ').where((s) => s.length > 1).toSet();
    const variants = [
      'live',
      'remix',
      'acoustic',
      'cover',
      'slowed',
      'sped',
      'nightcore',
      'instrumental',
      'remaster',
    ];
    final matching = candidates.where((song) {
      if (song.id == original.id || !song.id.startsWith('saavn:')) {
        return false;
      }
      final title = normalize(
        song.title,
      ).split(' ').where((s) => s.isNotEmpty).toSet();
      final people = song.artist
          .split(RegExp(r',|&| feat\.? | featuring '))
          .map(
            (person) =>
                normalize(person).split(' ').where((s) => s.length > 1).toSet(),
          )
          .where((person) => person.isNotEmpty)
          .toList();
      if (title.isEmpty || people.isEmpty || !label.containsAll(title)) {
        return false;
      }
      if (variants.any((v) => label.contains(v) != title.contains(v))) {
        return false;
      }
      if (!people.any(
        (person) =>
            person.every((p) => artist.contains(p) || label.contains(p)),
      )) {
        return false;
      }
      if (original.duration > 0 &&
          song.duration > 0 &&
          (original.duration - song.duration).abs() > 20) {
        return false;
      }
      return true;
    }).toList();
    return TrackValidationEngine.filterAndRank(
      matching,
      preserveOriginalOrderIfValid: true,
    ).take(2).toList();
  }

  static Future<String?> resolve(
    Song original, {
    required Future<List<Song>> Function(String query) search,
    required Future<String?> Function(Song candidate) resolveCandidate,
  }) async {
    if (original.duration > 1200) return null;
    try {
      final candidates = await search(
        '${original.title} ${original.artist}'.trim(),
      ).timeout(const Duration(seconds: 10));
      for (final song in matches(original, candidates)) {
        try {
          final url = await resolveCandidate(
            song,
          ).timeout(const Duration(seconds: 10));
          if (url != null && url.isNotEmpty) return url;
        } catch (_) {
          /* Try the next verified recording. */
        }
      }
    } catch (_) {
      /* Unavailable is preferable to playing a different recording. */
    }
    return null;
  }
}
