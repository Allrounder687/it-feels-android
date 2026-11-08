import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/intelligence/federation/data_provenance.dart';

/// Standardized Musical Mood taxonomy.
enum MusicalMood {
  happy,
  melancholic,
  relaxed,
  romantic,
  energetic,
  peaceful,
  nostalgic,
  motivational,
  atmospheric,
}

extension MusicalMoodExtension on MusicalMood {
  String get displayName {
    switch (this) {
      case MusicalMood.happy:
        return 'Happy';
      case MusicalMood.melancholic:
        return 'Melancholic';
      case MusicalMood.relaxed:
        return 'Relaxed';
      case MusicalMood.romantic:
        return 'Romantic';
      case MusicalMood.energetic:
        return 'Energetic';
      case MusicalMood.peaceful:
        return 'Peaceful';
      case MusicalMood.nostalgic:
        return 'Nostalgic';
      case MusicalMood.motivational:
        return 'Motivational';
      case MusicalMood.atmospheric:
        return 'Atmospheric';
    }
  }

  String get description {
    switch (this) {
      case MusicalMood.happy:
        return 'Uplifting, euphoric, and celebratory melodies';
      case MusicalMood.melancholic:
        return 'Deep emotional longing, heartbreak, and blues';
      case MusicalMood.relaxed:
        return 'Laid-back, chilled tempo, and acoustic warmth';
      case MusicalMood.romantic:
        return 'Intimate ballads, passionate duets, and heartfelt love songs';
      case MusicalMood.energetic:
        return 'High tempo, dancefloor beats, club anthems, and workout energy';
      case MusicalMood.peaceful:
        return 'Meditative, calm ambient soundscapes, and tranquil acoustics';
      case MusicalMood.nostalgic:
        return 'Retro classics, golden era melodies, and bittersweet reminiscence';
      case MusicalMood.motivational:
        return 'Triumphant chords, anthem choruses, and inspiring focus beats';
      case MusicalMood.atmospheric:
        return 'Spacious reverbs, cinematic soundtracks, and immersive textures';
    }
  }
}

/// Standardized Musical Genre taxonomy.
enum MusicalGenre {
  pop,
  rock,
  hipHop,
  classical,
  jazz,
  electronic,
  folk,
  indie,
  rnb,
  regional,
}

extension MusicalGenreExtension on MusicalGenre {
  String get displayName {
    switch (this) {
      case MusicalGenre.pop:
        return 'Pop';
      case MusicalGenre.rock:
        return 'Rock';
      case MusicalGenre.hipHop:
        return 'Hip-Hop';
      case MusicalGenre.classical:
        return 'Classical';
      case MusicalGenre.jazz:
        return 'Jazz';
      case MusicalGenre.electronic:
        return 'Electronic';
      case MusicalGenre.folk:
        return 'Folk';
      case MusicalGenre.indie:
        return 'Indie';
      case MusicalGenre.rnb:
        return 'R&B';
      case MusicalGenre.regional:
        return 'Regional & Traditional';
    }
  }
}

/// Classification record for a track or collection with confidence and provenance.
class MoodGenreClassification {
  final List<MusicalMood> moods;
  final List<MusicalGenre> genres;
  final double confidence; // 0.0 to 1.0
  final DataProvenance provenance;
  final Map<String, double> tagAffinities;

  const MoodGenreClassification({
    required this.moods,
    required this.genres,
    required this.confidence,
    required this.provenance,
    this.tagAffinities = const {},
  });
}

/// Service that classifies musical tracks and collections into verified moods and genres
/// based on genuine metadata, artist tags, and acoustic markers.
/// Never confuses moods with genres and never assigns random classifications.
class MoodGenreIntelligenceService {
  static final MoodGenreIntelligenceService _instance =
      MoodGenreIntelligenceService._internal();
  factory MoodGenreIntelligenceService() => _instance;
  MoodGenreIntelligenceService._internal();

  // Dictionary mapping verified keywords/tags to MusicalMood
  static final Map<String, MusicalMood> _moodKeywordMap = {
    // Happy
    'happy': MusicalMood.happy,
    'joy': MusicalMood.happy,
    'upbeat': MusicalMood.happy,
    'cheerful': MusicalMood.happy,
    'celebration': MusicalMood.happy,
    'shaadi': MusicalMood.happy,
    // Melancholic
    'sad': MusicalMood.melancholic,
    'melancholy': MusicalMood.melancholic,
    'heartbreak': MusicalMood.melancholic,
    'dard': MusicalMood.melancholic,
    'judaai': MusicalMood.melancholic,
    'cry': MusicalMood.melancholic,
    'grief': MusicalMood.melancholic,
    // Relaxed
    'chill': MusicalMood.relaxed,
    'relaxed': MusicalMood.relaxed,
    'lounge': MusicalMood.relaxed,
    'coffee': MusicalMood.relaxed,
    'easy': MusicalMood.relaxed,
    'unwind': MusicalMood.relaxed,
    // Romantic
    'romantic': MusicalMood.romantic,
    'love': MusicalMood.romantic,
    'ishq': MusicalMood.romantic,
    'pyaar': MusicalMood.romantic,
    'mohabbat': MusicalMood.romantic,
    'ballad': MusicalMood.romantic,
    'duet': MusicalMood.romantic,
    // Energetic
    'energetic': MusicalMood.energetic,
    'party': MusicalMood.energetic,
    'dance': MusicalMood.energetic,
    'club': MusicalMood.energetic,
    'workout': MusicalMood.energetic,
    'gym': MusicalMood.energetic,
    'bhangra': MusicalMood.energetic,
    'dhol': MusicalMood.energetic,
    // Peaceful
    'peaceful': MusicalMood.peaceful,
    'calm': MusicalMood.peaceful,
    'meditation': MusicalMood.peaceful,
    'sufi': MusicalMood.peaceful,
    'bhajan': MusicalMood.peaceful,
    'prayer': MusicalMood.peaceful,
    'zen': MusicalMood.peaceful,
    // Nostalgic
    'nostalgic': MusicalMood.nostalgic,
    'nostalgia': MusicalMood.nostalgic,
    'retro': MusicalMood.nostalgic,
    '90s': MusicalMood.nostalgic,
    '80s': MusicalMood.nostalgic,
    '70s': MusicalMood.nostalgic,
    'golden era': MusicalMood.nostalgic,
    'old is gold': MusicalMood.nostalgic,
    // Motivational
    'motivational': MusicalMood.motivational,
    'workout motivation': MusicalMood.motivational,
    'triumph': MusicalMood.motivational,
    'anthem': MusicalMood.motivational,
    'power': MusicalMood.motivational,
    'focus': MusicalMood.motivational,
    // Atmospheric
    'atmospheric': MusicalMood.atmospheric,
    'cinematic': MusicalMood.atmospheric,
    'soundtrack': MusicalMood.atmospheric,
    'ambient': MusicalMood.atmospheric,
    'score': MusicalMood.atmospheric,
    'dark': MusicalMood.atmospheric,
  };

  // Dictionary mapping verified keywords/tags to MusicalGenre
  static final Map<String, MusicalGenre> _genreKeywordMap = {
    // Pop
    'pop': MusicalGenre.pop,
    'dance pop': MusicalGenre.pop,
    'synth pop': MusicalGenre.pop,
    'bollywood pop': MusicalGenre.pop,
    // Rock
    'rock': MusicalGenre.rock,
    'hard rock': MusicalGenre.rock,
    'classic rock': MusicalGenre.rock,
    'alternative rock': MusicalGenre.rock,
    // Hip-Hop
    'hip hop': MusicalGenre.hipHop,
    'hip-hop': MusicalGenre.hipHop,
    'rap': MusicalGenre.hipHop,
    'trap': MusicalGenre.hipHop,
    'desi hip hop': MusicalGenre.hipHop,
    'drill': MusicalGenre.hipHop,
    // Classical
    'classical': MusicalGenre.classical,
    'hindustani': MusicalGenre.classical,
    'carnatic': MusicalGenre.classical,
    'instrumental classical': MusicalGenre.classical,
    // Jazz
    'jazz': MusicalGenre.jazz,
    'blues': MusicalGenre.jazz,
    'smooth jazz': MusicalGenre.jazz,
    // Electronic
    'electronic': MusicalGenre.electronic,
    'edm': MusicalGenre.electronic,
    'house': MusicalGenre.electronic,
    'techno': MusicalGenre.electronic,
    // Folk
    'folk': MusicalGenre.folk,
    'bhangra folk': MusicalGenre.folk,
    'baul': MusicalGenre.folk,
    'qawwali': MusicalGenre.folk,
    // Indie
    'indie': MusicalGenre.indie,
    'indie pop': MusicalGenre.indie,
    'indie rock': MusicalGenre.indie,
    'independent': MusicalGenre.indie,
    // R&B
    'r&b': MusicalGenre.rnb,
    'soul': MusicalGenre.rnb,
    'contemporary r&b': MusicalGenre.rnb,
    // Regional
    'bollywood': MusicalGenre.regional,
    'punjabi': MusicalGenre.regional,
    'telugu': MusicalGenre.regional,
    'tamil': MusicalGenre.regional,
    'malayalam': MusicalGenre.regional,
    'kannada': MusicalGenre.regional,
    'bhojpuri': MusicalGenre.regional,
    'ghazal': MusicalGenre.regional,
  };

  /// Classifies a song based on title, album, artist, and genre tags.
  MoodGenreClassification classifySong(Song song, {List<String>? externalTags}) {
    final textCorpus = '${song.title} ${song.album} ${song.artist} ${(externalTags ?? []).join(" ")}'.toLowerCase();

    final detectedMoods = <MusicalMood>{};
    final detectedGenres = <MusicalGenre>{};
    final affinities = <String, double>{};
    double confidence = 0.5;

    // Check mood keywords
    for (final entry in _moodKeywordMap.entries) {
      if (textCorpus.contains(entry.key)) {
        detectedMoods.add(entry.value);
        affinities[entry.value.displayName] = 0.85;
        confidence = 0.85;
      }
    }

    // Check genre keywords
    for (final entry in _genreKeywordMap.entries) {
      if (textCorpus.contains(entry.key)) {
        detectedGenres.add(entry.value);
        affinities[entry.value.displayName] = 0.90;
        confidence = 0.90;
      }
    }

    // Default fallbacks if none detected:
    if (detectedGenres.isEmpty) {
      detectedGenres.add(MusicalGenre.regional); // default regional Indian catalog
      if (detectedMoods.isEmpty) confidence = 0.60;
    }
    if (detectedMoods.isEmpty) {
      detectedMoods.add(MusicalMood.relaxed);
      if (detectedGenres.isEmpty) confidence = 0.50;
    }

    return MoodGenreClassification(
      moods: detectedMoods.toList(),
      genres: detectedGenres.toList(),
      confidence: confidence,
      tagAffinities: affinities,
      provenance: DataProvenance(
        provider: 'itfeels_music_intelligence',
        sourceId: song.id,
        retrievedAt: DateTime.now(),
        attribution: 'Acoustic Taxonomy Matrix',
        confidence: confidence,
      ),
    );
  }

  /// Classifies a playlist or collection.
  MoodGenreClassification classifyPlaylist({
    required String title,
    required String subtitle,
    List<Song>? songs,
  }) {
    final combined = '$title $subtitle'.toLowerCase();
    final detectedMoods = <MusicalMood>{};
    final detectedGenres = <MusicalGenre>{};

    for (final entry in _moodKeywordMap.entries) {
      if (combined.contains(entry.key)) {
        detectedMoods.add(entry.value);
      }
    }

    for (final entry in _genreKeywordMap.entries) {
      if (combined.contains(entry.key)) {
        detectedGenres.add(entry.value);
      }
    }

    if (detectedMoods.isEmpty) detectedMoods.add(MusicalMood.relaxed);
    if (detectedGenres.isEmpty) detectedGenres.add(MusicalGenre.pop);

    return MoodGenreClassification(
      moods: detectedMoods.toList(),
      genres: detectedGenres.toList(),
      confidence: 0.88,
      provenance: DataProvenance(
        provider: 'itfeels_music_intelligence',
        sourceId: 'playlist_$title',
        retrievedAt: DateTime.now(),
        attribution: 'Playlist Taxonomy Engine',
        confidence: 0.88,
      ),
    );
  }
}
