import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/utils/string_utils.dart';

/// Represents the evaluated validation and scoring status of a track candidate.
class TrackValidationResult {
  final Song song;
  final double confidenceScore; // 0.0 to 100.0
  final bool isValid;
  final String? rejectionReason;
  final bool isInstrumental;
  final bool isRemixOrModification;

  const TrackValidationResult({
    required this.song,
    required this.confidenceScore,
    required this.isValid,
    this.rejectionReason,
    this.isInstrumental = false,
    this.isRemixOrModification = false,
  });

  @override
  String toString() =>
      'TrackValidationResult(title: "${song.title}", score: ${confidenceScore.toStringAsFixed(1)}, valid: $isValid, reason: $rejectionReason)';
}

/// Centralized, intelligent track validation, ranking, and filtering engine.
/// Replaces scattered ad-hoc substring filters with a multi-vector heuristic scoring model.
class TrackValidationEngine {
  TrackValidationEngine._();

  static const List<String> instrumentalKeywords = [
    'instrumental',
    'karaoke',
    'flute cover',
    'flute version',
    'flute',
    'piano cover',
    'piano version',
    'guitar cover',
    'guitar version',
    'violin cover',
    'violin version',
    'saxophone',
    'shehnai',
    'sitar',
    'tabla solo',
    'santoor',
    'orchestral version',
    'orchestra cover',
    'bgm',
    'background score',
    'theme music',
  ];

  static const List<String> modifierKeywords = [
    'slowed',
    'reverb',
    'slowed+reverb',
    'slowed & reverb',
    'lofi',
    'lo-fi',
    'lofi flip',
    '8d audio',
    'tribute to',
    'tribute',
    'ringtone',
    'caller tune',
    'status video',
    'whatsapp status',
    'dj remix',
    'jhankar',
    'jhankar beats',
    'bass boosted',
  ];

  static const List<String> emulationKeywords = [
    'emulation',
    '8-bit',
    '8 bit',
    '8bit',
    '16-bit',
    '16 bit',
    '16bit',
    'chiptune',
    'arcade player',
    '8-bit arcade',
    'arcade version',
    'arcade cover',
    'music box version',
    'music box cover',
    'music box',
    'lullaby version',
    'baby lullaby',
    'midi cover',
    'midi version',
    'synth cover',
    'synthesizer cover',
    'synthesizer version',
    'in the style of',
    'as made famous by',
    'originally performed by',
  ];

  static const List<String> spamArtists = [
    'arcade player',
    '8-bit arcade',
    '8 bit arcade',
    'sing2piano',
    'sing2guitar',
    'karaoke channel',
    'midifine',
    'relaxing piano crew',
    'lullaby world',
    'baby sleep',
    'tribute band',
    'cover band',
    'acoustic tribute',
  ];

  static const List<String> topCelebrityArtists = [
    'the weeknd',
    'taylor swift',
    'drake',
    'ariana grande',
    'ed sheeran',
    'justin bieber',
    'dua lipa',
    'billie eilish',
    'bruno mars',
    'post malone',
    'harry styles',
    'arijit singh',
    'diljit dosanjh',
    'badshah',
    'shreya ghoshal',
    'pritam',
  ];

  /// Checks whether a string denotes an explicit user desire for instrumental/karaoke music.
  static bool isContextuallyInstrumental(String? queryContext) {
    if (queryContext == null || queryContext.trim().isEmpty) return false;
    final q = queryContext.toLowerCase();
    return q.contains('instrumental') ||
        q.contains('karaoke') ||
        q.contains('flute') ||
        q.contains('piano') ||
        q.contains('guitar') ||
        q.contains('bgm') ||
        q.contains('theme');
  }

  /// Checks whether a string denotes an explicit user desire for modified/remixed music.
  static bool isContextuallyRemix(String? queryContext) {
    if (queryContext == null || queryContext.trim().isEmpty) return false;
    final q = queryContext.toLowerCase();
    return q.contains('remix') ||
        q.contains('slowed') ||
        q.contains('reverb') ||
        q.contains('lofi') ||
        q.contains('lo-fi') ||
        q.contains('jhankar');
  }

  /// Evaluates and scores an individual song candidate against contextual expectations.
  static TrackValidationResult evaluate(
    Song song, {
    String? queryContext,
    String? expectedArtist,
    String? expectedAlbum,
    int? expectedDurationSec,
    double minPassingScore = 35.0,
  }) {
    if (song.title.trim().isEmpty) {
      return TrackValidationResult(
        song: song,
        confidenceScore: 0.0,
        isValid: false,
        rejectionReason: 'Empty title',
      );
    }

    final tLower = song.title.toLowerCase();
    final aLower = song.artist.toLowerCase();
    final albLower = song.album.toLowerCase();

    bool isInstrumental = false;
    for (final kw in instrumentalKeywords) {
      if (tLower.contains(kw) || albLower.contains(kw)) {
        isInstrumental = true;
        break;
      }
    }

    bool isModification = false;
    for (final kw in modifierKeywords) {
      if (tLower.contains(kw) || albLower.contains(kw)) {
        isModification = true;
        break;
      }
    }

    bool isEmulation = false;
    for (final kw in emulationKeywords) {
      if (tLower.contains(kw) || albLower.contains(kw) || aLower.contains(kw)) {
        isEmulation = true;
        break;
      }
    }

    bool isSpamArtist = false;
    for (final sa in spamArtists) {
      if (aLower.contains(sa)) {
        isSpamArtist = true;
        break;
      }
    }

    bool isSeoTitleStuffed = false;
    for (final celeb in topCelebrityArtists) {
      if (tLower.contains(celeb) && !aLower.contains(celeb)) {
        isSeoTitleStuffed = true;
        break;
      }
    }

    final userWantsInstrumental = isContextuallyInstrumental(queryContext);
    final userWantsRemix = isContextuallyRemix(queryContext);

    double score = 50.0; // Baseline neutrality

    // 1. Metadata completeness & authenticity
    if (song.artist.isNotEmpty && song.artist != 'Unknown Artist') {
      score += 15.0;
    } else {
      score -= 20.0;
    }

    if (song.album.isNotEmpty && song.album != song.title) {
      score += 10.0;
    }

    if (song.duration > 0) {
      // Penalize extreme ringtone/teaser outliers (< 45s) unless specifically tagged
      if (song.duration < 45) {
        score -= 30.0;
      } else if (song.duration >= 120 && song.duration <= 480) {
        // Standard studio track duration
        score += 10.0;
      }
    }

    // 2. Expected Artist Affinity
    if (expectedArtist != null && expectedArtist.trim().isNotEmpty) {
      final cleanExpArtist = expectedArtist.toLowerCase().split(',').first.trim();
      if (aLower.contains(cleanExpArtist)) {
        score += 25.0;
      } else {
        score -= 15.0;
      }
    }

    // 3. Expected Album Affinity
    if (expectedAlbum != null && expectedAlbum.trim().isNotEmpty) {
      final cleanExpAlbum = expectedAlbum.toLowerCase().trim();
      if (albLower.contains(cleanExpAlbum)) {
        score += 15.0;
      }
    }

    // 4. Expected Duration Match (if known)
    if (expectedDurationSec != null && expectedDurationSec > 0 && song.duration > 0) {
      final diff = (song.duration - expectedDurationSec).abs();
      if (diff <= 5) {
        score += 15.0; // Exact match
      } else if (diff <= 20) {
        score += 5.0;
      } else if (diff > 90) {
        score -= 15.0; // Suspect version/extended cut
      }
    }

    // 5. Unwanted Modifier Penalties (Contextual)
    String? rejectionReason;

    if (isInstrumental) {
      if (userWantsInstrumental) {
        score += 30.0; // Boost requested instrumental
      } else {
        score -= 55.0; // Heavy penalty for unwanted instrumental cover/karaoke
        rejectionReason = 'Unwanted instrumental/karaoke track';
      }
    }

    if (isModification) {
      if (userWantsRemix) {
        score += 25.0; // Boost requested modification
      } else {
        score -= 45.0; // Heavy penalty for slowed/reverb/ringtone/tribute
        rejectionReason = rejectionReason ?? 'Unwanted remix/ringtone modification';
      }
    }

    if (isEmulation) {
      score -= 60.0; // Heavy penalty for unwanted 8-bit/16-bit chiptune or emulation
      rejectionReason = rejectionReason ?? 'Unwanted 8-bit/16-bit emulation or chiptune track';
    }

    if (isSpamArtist) {
      score -= 60.0; // Heavy penalty for known sound-alike / chiptune spam creators
      rejectionReason = rejectionReason ?? 'Known sound-alike or chiptune spam artist ($aLower)';
    }

    if (isSeoTitleStuffed) {
      score -= 55.0; // Heavy penalty for SEO title-stuffed sound-alike cover impersonators
      rejectionReason = rejectionReason ?? 'SEO title-stuffed sound-alike cover';
    }

    // Clamp score to [0.0, 100.0]
    final finalScore = score.clamp(0.0, 100.0);
    final isValid = finalScore >= minPassingScore;

    return TrackValidationResult(
      song: song,
      confidenceScore: finalScore,
      isValid: isValid,
      rejectionReason: isValid ? null : (rejectionReason ?? 'Confidence score below threshold ($finalScore < $minPassingScore)'),
      isInstrumental: isInstrumental,
      isRemixOrModification: isModification,
    );
  }

  /// Filters a list of song candidates, removing invalid/polluting entries and sorting by confidence score.
  static List<Song> filterAndRank(
    List<Song> candidates, {
    String? queryContext,
    String? expectedArtist,
    String? expectedAlbum,
    int? expectedDurationSec,
    double minPassingScore = 35.0,
    bool preserveOriginalOrderIfValid = false,
  }) {
    if (candidates.isEmpty) return [];

    final evaluated = candidates.map((s) {
      return evaluate(
        s,
        queryContext: queryContext,
        expectedArtist: expectedArtist,
        expectedAlbum: expectedAlbum,
        expectedDurationSec: expectedDurationSec,
        minPassingScore: minPassingScore,
      );
    }).where((res) => res.isValid).toList();

    if (!preserveOriginalOrderIfValid) {
      evaluated.sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));
    }

    // Enforce deduplication by canonical identity
    final seen = <String>{};
    final List<Song> results = [];
    for (final item in evaluated) {
      final key = _generateCanonicalKey(item.song);
      if (seen.add(key)) {
        results.add(item.song);
      }
    }

    return results;
  }

  /// Quick Boolean filter suitable for stream iterators or `.where()` predicates.
  static bool isValidTrack(Song song, {String? queryContext, double minPassingScore = 35.0}) {
    return evaluate(song, queryContext: queryContext, minPassingScore: minPassingScore).isValid;
  }

  /// Generates a normalized canonical key to deduplicate identical recordings.
  static String normalizeTrackKey(String title, String artist) {
    final cleanT = StringUtils.cleanText(title)
        .toLowerCase()
        .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
        .replaceAll(RegExp(r'\s*\[[^\]]*\]'), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    final cleanA = StringUtils.cleanText(artist)
        .toLowerCase()
        .split(',')
        .first
        .split('&')
        .first
        .split('/')
        .first
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (cleanT.isEmpty) {
      return '';
    }
    return '${cleanT}_$cleanA';
  }

  /// Generates a normalized canonical key to deduplicate identical recordings.
  static String _generateCanonicalKey(Song s) {
    final key = normalizeTrackKey(s.title, s.artist);
    return key.isNotEmpty ? key : s.id;
  }
}
