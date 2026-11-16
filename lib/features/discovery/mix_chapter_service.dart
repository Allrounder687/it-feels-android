import 'package:it_feels_music/data/models/mix_chapter.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/core/utils/track_validation_engine.dart';
import 'package:it_feels_music/core/utils/audio_source_policy.dart';
import 'package:it_feels_music/features/connected_music/connected_music_models.dart';

class ChapterMatch {
  final MixChapter chapter;
  final Song? song;
  const ChapterMatch(this.chapter, this.song);
}

class MixDownloadResult {
  final List<Song> tracks;
  final int? chapterCount;
  const MixDownloadResult(this.tracks, {this.chapterCount});
}

class MixChapterService {
  final IMusicRepository repository;
  MixChapterService(this.repository);
  Future<MixDownloadResult> downloadable(AccountSnapshot snapshot) async {
    if (!snapshot.complete) {
      throw const FormatException('Mix metadata is incomplete');
    }
    final full = snapshot.tracks.firstOrNull?.song;
    if (full != null) {
      try {
        final url = await repository
            .getStreamUrl(full)
            .timeout(const Duration(seconds: 20));
        if (url != null && await AudioSourcePolicy.probe(url)) {
          return MixDownloadResult([full]);
        }
      } catch (_) {
        /* Only audio-only sources qualify for a complete-mix download. */
      }
    }
    final matches = await resolve(snapshot.chapters);
    final songs = matches.map((m) => m.song).whereType<Song>().toList();
    if (songs.isEmpty) {
      throw const FormatException(
        'No audio source or reliable chapter matches',
      );
    }
    return MixDownloadResult(songs, chapterCount: snapshot.chapters.length);
  }

  Future<List<ChapterMatch>> resolve(List<MixChapter> chapters) async {
    final result = List<ChapterMatch?>.filled(chapters.length, null);
    final pending = <String, Future<List<Song>>>{};
    var next = 0;
    Future<void> worker() async {
      while (next < chapters.length) {
        final index = next++, chapter = chapters[index];
        Song? selected;
        if (!RegExp(
          r'^(intro|outro|interlude|subscribe|track\s*\d+|song\s*\d+)$',
          caseSensitive: false,
        ).hasMatch(chapter.title.trim())) {
          try {
            final query = chapter.title.replaceFirst(
              RegExp(r'^\s*\d+[.)]\s*'),
              '',
            );
            final candidates = await pending.putIfAbsent(
              query,
              () => repository
                  .searchSongs(query, count: 8)
                  .timeout(const Duration(seconds: 12)),
            );
            selected = bestMatch(chapter, candidates);
          } catch (_) {
            /* An unavailable chapter remains explicitly unmatched. */
          }
        }
        result[index] = ChapterMatch(chapter, selected);
      }
    }

    await Future.wait([worker(), worker()]);
    return result.whereType<ChapterMatch>().toList();
  }

  static String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'\([^)]*(official|lyrics?|audio)[^)]*\)'), '')
      .replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  static Song? bestMatch(MixChapter chapter, List<Song> candidates) {
    final label = _normalize(
      chapter.title.replaceFirst(RegExp(r'^\s*\d+[.)]\s*'), ''),
    );
    final labelTokens = label.split(' ').toSet();
    const variants = [
      'remix',
      'live',
      'acoustic',
      'slowed',
      'nightcore',
      'instrumental',
      'cover',
    ];
    Song? best;
    var highest = 0.0;
    for (final song in TrackValidationEngine.filterAndRank(
      candidates,
      preserveOriginalOrderIfValid: true,
    )) {
      final title = _normalize(song.title),
          tokens = _normalize(
            song.title,
          ).split(' ').where((s) => s.isNotEmpty).toSet();
      if (tokens.isEmpty || tokens.any((t) => !labelTokens.contains(t))) {
        continue;
      }
      if (variants.any((v) => labelTokens.contains(v) != tokens.contains(v))) {
        continue;
      }
      final artistTokens = _normalize(
        song.artist,
      ).split(' ').where((t) => t.length > 2 && t != 'the').toSet();
      final hasArtist = artistTokens.any(labelTokens.contains);
      final exactTitle = label == title;
      if (!exactTitle && !hasArtist) continue;
      final duration = chapter.endSeconds == null
          ? null
          : chapter.endSeconds! - chapter.startSeconds;
      if (duration != null &&
          duration >= 40 &&
          duration <= 600 &&
          song.duration > 0 &&
          (duration - song.duration).abs() > 25) {
        continue;
      }
      final score = (exactTitle ? 90.0 : 80.0) + (hasArtist ? 20.0 : 0.0);
      if (score > highest) {
        highest = score;
        best = song;
      }
    }
    return best;
  }
}
