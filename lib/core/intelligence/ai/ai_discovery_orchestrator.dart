import 'package:flutter/foundation.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/core/utils/track_validation_engine.dart';
import 'package:it_feels_music/core/intelligence/taste/user_taste_profile.dart';
import 'package:it_feels_music/core/intelligence/recommendations/recommendation_scorer.dart';

/// Structured music query constraints extracted from natural-language prompts.
class MusicQueryConstraints {
  final String originalPrompt;
  final List<String> genres;
  final List<String> moods;
  final String tempo; // 'slow', 'medium', 'fast', 'any'
  final String era;   // '90s', '2000s', 'modern', 'classic', 'any'
  final List<String> targetArtists;
  final List<String> searchKeywords;
  final String suggestedTitle;
  final String rationale;

  const MusicQueryConstraints({
    required this.originalPrompt,
    this.genres = const [],
    this.moods = const [],
    this.tempo = 'any',
    this.era = 'any',
    this.targetArtists = const [],
    this.searchKeywords = const [],
    required this.suggestedTitle,
    required this.rationale,
  });

  Map<String, dynamic> toJson() => {
    'originalPrompt': originalPrompt,
    'genres': genres,
    'moods': moods,
    'tempo': tempo,
    'era': era,
    'targetArtists': targetArtists,
    'searchKeywords': searchKeywords,
    'suggestedTitle': suggestedTitle,
    'rationale': rationale,
  };

  factory MusicQueryConstraints.fromJson(Map<String, dynamic> json) {
    return MusicQueryConstraints(
      originalPrompt: json['originalPrompt']?.toString() ?? '',
      genres: (json['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      moods: (json['moods'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      tempo: json['tempo']?.toString() ?? 'any',
      era: json['era']?.toString() ?? 'any',
      targetArtists: (json['targetArtists'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      searchKeywords: (json['searchKeywords'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      suggestedTitle: json['suggestedTitle']?.toString() ?? 'Curated Mix',
      rationale: json['rationale']?.toString() ?? '',
    );
  }
}

/// Result of an AI Discovery operation with structured metadata and validated playable songs.
class AIDiscoveryResult {
  final String title;
  final String description;
  final MusicQueryConstraints constraints;
  final List<Song> songs;

  const AIDiscoveryResult({
    required this.title,
    required this.description,
    required this.constraints,
    required this.songs,
  });
}

/// Orchestrates natural-language prompt interpretation into structured constraints,
/// validates against live catalogue repositories, and applies recommendation intelligence.
///
/// RULE: AI is NOT the source of truth for metadata or playable media URLs.
/// All songs returned are strictly validated and fetched through authentic catalogue endpoints.
class AIDiscoveryOrchestrator {
  final IMusicRepository? _injectedRepo;
  IMusicRepository get _musicRepo => _injectedRepo ?? locator<IMusicRepository>();

  AIDiscoveryOrchestrator({IMusicRepository? musicRepo}) : _injectedRepo = musicRepo;

  /// Extracts structured musical constraints from raw prompt.
  MusicQueryConstraints extractConstraints(String prompt) {
    final clean = prompt.toLowerCase();
    final genres = <String>[];
    final moods = <String>[];
    final targetArtists = <String>[];
    String tempo = 'any';
    String era = 'any';

    // 1. Detect Genres
    final genrePatterns = {
      'bollywood': 'Bollywood',
      'punjabi': 'Punjabi',
      'pop': 'Pop',
      'hip hop': 'Hip-Hop',
      'rap': 'Hip-Hop',
      'acoustic': 'Acoustic',
      'indie': 'Indie',
      'edm': 'EDM',
      'dance': 'Dance',
      'sufi': 'Sufi',
      'ghazal': 'Ghazal',
      'rock': 'Rock',
      'lo-fi': 'Lo-Fi',
      'lofi': 'Lo-Fi',
      'devotional': 'Devotional',
      'classical': 'Classical',
    };

    genrePatterns.forEach((k, v) {
      if (clean.contains(k) && !genres.contains(v)) {
        genres.add(v);
      }
    });

    // 2. Detect Moods
    final moodPatterns = {
      'late night': 'Late Night',
      'night': 'Late Night',
      'romantic': 'Romantic',
      'love': 'Romantic',
      'sad': 'Melancholic',
      'heartbreak': 'Heartbreak',
      'melancholy': 'Melancholic',
      'chill': 'Chill',
      'relax': 'Chill',
      'workout': 'High Energy',
      'gym': 'High Energy',
      'party': 'Party',
      'focus': 'Focus',
      'study': 'Focus',
      'nostalgic': 'Nostalgic',
      'happy': 'Uplifting',
    };

    moodPatterns.forEach((k, v) {
      if (clean.contains(k) && !moods.contains(v)) {
        moods.add(v);
      }
    });

    // 3. Detect Tempo
    if (clean.contains('slow') || clean.contains('calm') || clean.contains('soft') || clean.contains('mellow')) {
      tempo = 'slow';
    } else if (clean.contains('fast') || clean.contains('energetic') || clean.contains('hype') || clean.contains('upbeat')) {
      tempo = 'fast';
    } else if (clean.contains('medium') || clean.contains('moderate')) {
      tempo = 'medium';
    }

    // 4. Detect Era
    if (clean.contains('90s') || clean.contains('90\'s') || clean.contains('nineties')) {
      era = '90s';
    } else if (clean.contains('2000s') || clean.contains('2000\'s') || clean.contains('y2k')) {
      era = '2000s';
    } else if (clean.contains('retro') || clean.contains('old') || clean.contains('classic')) {
      era = 'classic';
    } else if (clean.contains('new') || clean.contains('latest') || clean.contains('modern') || clean.contains('recent')) {
      era = 'modern';
    }

    // 5. Detect Artists
    final knownArtists = [
      'Arijit Singh', 'Pritam', 'Shreya Ghoshal', 'Diljit Dosanjh', 'Karan Aujla',
      'AP Dhillon', 'Badshah', 'Yo Yo Honey Singh', 'DIVINE', 'Seedhe Maut',
      'Anuv Jain', 'Prateek Kuhad', 'Jasleen Royal', 'Atif Aslam', 'KK',
      'The Weeknd', 'Taylor Swift', 'Drake', 'Dua Lipa', 'Ed Sheeran',
    ];

    for (final artist in knownArtists) {
      if (clean.contains(artist.toLowerCase())) {
        targetArtists.add(artist);
      }
    }

    // Compose search keywords
    final searchKeywords = <String>[];
    if (targetArtists.isNotEmpty) {
      searchKeywords.addAll(targetArtists.map((a) => '$a ${genres.isNotEmpty ? genres.first : "hits"}'));
    }
    if (genres.isNotEmpty && moods.isNotEmpty) {
      searchKeywords.add('${moods.first} ${genres.first}');
    } else if (moods.isNotEmpty) {
      searchKeywords.add('${moods.first} songs');
    } else if (genres.isNotEmpty) {
      searchKeywords.add('${genres.first} hits');
    }

    if (searchKeywords.isEmpty) {
      searchKeywords.add(prompt);
    }

    // Generate title
    String title;
    if (moods.isNotEmpty && genres.isNotEmpty) {
      title = '${moods.first} ${genres.first} Mix';
    } else if (moods.isNotEmpty) {
      title = '${moods.first} Flow';
    } else if (targetArtists.isNotEmpty) {
      title = '${targetArtists.first} & Friends';
    } else if (genres.isNotEmpty) {
      title = '${genres.first} Selections';
    } else {
      title = prompt.split(' ').take(4).map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
    }

    final rationale = 'Curated based on ${moods.join(", ")} vibes${genres.isNotEmpty ? " with ${genres.join(", ")}" : ""}.';

    return MusicQueryConstraints(
      originalPrompt: prompt,
      genres: genres,
      moods: moods,
      tempo: tempo,
      era: era,
      targetArtists: targetArtists,
      searchKeywords: searchKeywords,
      suggestedTitle: title,
      rationale: rationale,
    );
  }

  /// Discovers, validates, and ranks playable songs matching natural-language constraints.
  Future<AIDiscoveryResult> discoverAndValidate({
    required String prompt,
    UserTasteProfile? profile,
    int count = 20,
  }) async {
    final constraints = extractConstraints(prompt);
    final candidateSongs = <Song>[];
    final seenIds = <String>{};

    for (final query in constraints.searchKeywords.take(3)) {
      try {
        final results = await _musicRepo.searchSongs(query, count: 15);
        for (final song in results) {
          if (seenIds.add(song.id)) {
            candidateSongs.add(song);
          }
        }
      } catch (e) {
        debugPrint('[AIDiscoveryOrchestrator] Query error for "$query": $e');
      }
    }

    // Filter through TrackValidationEngine
    final validated = TrackValidationEngine.filterAndRank(
      candidateSongs,
      queryContext: prompt,
      minPassingScore: 40.0,
      preserveOriginalOrderIfValid: false,
    );

    // Apply scoring if taste profile provided
    List<Song> finalTracks = validated;
    if (profile != null) {
      const scorer = RecommendationScorer();
      final scored = validated.map((s) {
        return scorer.scoreCandidate(song: s, profile: profile) ??
            ScoredTrack(song: s, totalScore: 0.0, explanation: 'Relevant match');
      }).toList();

      scored.sort((a, b) => b.totalScore.compareTo(a.totalScore));
      finalTracks = scored.map((s) => s.song).toList();
    }

    return AIDiscoveryResult(
      title: constraints.suggestedTitle,
      description: constraints.rationale,
      constraints: constraints,
      songs: finalTracks.take(count).toList(),
    );
  }
}
