import 'package:it_feels_music/core/intelligence/events/listening_event.dart';
import 'package:it_feels_music/core/intelligence/events/listening_event_buffer.dart';

class MusicDnaOverview {
  final int totalListeningMinutes;
  final int totalPlays;
  final int uniqueArtistsCount;
  final int uniqueAlbumsCount;
  final List<MapEntry<String, int>> topArtists;
  final List<MapEntry<String, int>> topSongs;
  final Map<String, int> genreBreakdown;
  final Map<String, int> timeOfDayDistribution;
  final Map<String, int> weekdayWeekendDistribution;
  final int newlyDiscoveredArtistsCount;
  final List<ListeningEvent> recentActivityTimeline;

  MusicDnaOverview({
    required this.totalListeningMinutes,
    required this.totalPlays,
    required this.uniqueArtistsCount,
    required this.uniqueAlbumsCount,
    required this.topArtists,
    required this.topSongs,
    required this.genreBreakdown,
    required this.timeOfDayDistribution,
    required this.weekdayWeekendDistribution,
    required this.newlyDiscoveredArtistsCount,
    required this.recentActivityTimeline,
  });
}

class ArtistPersonalRelationship {
  final String artistName;
  final int totalPlays;
  final List<MapEntry<String, int>> mostPlayedTracks;
  final DateTime? firstRecordedPlay;
  final DateTime? lastRecordedPlay;
  final double averageCompletionRate;

  ArtistPersonalRelationship({
    required this.artistName,
    required this.totalPlays,
    required this.mostPlayedTracks,
    this.firstRecordedPlay,
    this.lastRecordedPlay,
    this.averageCompletionRate = 1.0,
  });
}

class TrackPersonalInsights {
  final String trackTitle;
  final int playCount;
  final int skipCount;
  final double completionPercentage;
  final DateTime? lastPlayedAt;

  TrackPersonalInsights({
    required this.trackTitle,
    required this.playCount,
    required this.skipCount,
    required this.completionPercentage,
    this.lastPlayedAt,
  });
}

/// Offline privacy-preserving music intelligence engine that derives personal
/// listening DNA, heatmaps, and relationships exclusively from local records.
class MusicDnaService {
  static final MusicDnaService _instance = MusicDnaService._internal();
  factory MusicDnaService() => _instance;
  MusicDnaService._internal();

  final ListeningEventBuffer _buffer = ListeningEventBuffer.instance;

  /// Computes the complete Music DNA overview from genuine on-device event records.
  Future<MusicDnaOverview> computeDnaOverview() async {
    await _buffer.init();
    final events = _buffer.getRecentEvents(limit: 500);

    int totalDurationMs = 0;
    int playEventsCount = 0;
    final Set<String> artists = {};
    final Set<String> albums = {};
    final Map<String, int> artistCounts = {};
    final Map<String, int> trackCounts = {};
    final Map<String, int> genreCounts = {};

    final Map<String, int> timeOfDay = {
      'Morning': 0, // 05:00 - 11:59
      'Afternoon': 0, // 12:00 - 16:59
      'Evening': 0, // 17:00 - 21:59
      'Night': 0, // 22:00 - 04:59
    };

    final Map<String, int> weekdayWeekend = {
      'Weekdays': 0,
      'Weekends': 0,
    };

    final Set<String> seenArtistsChronological = {};
    int newDiscoveriesCount = 0;

    // Process from oldest to newest for chronological discovery detection
    final chronologicalEvents = events.reversed.toList();

    for (final event in chronologicalEvents) {
      totalDurationMs += event.durationPlayedMs;

      if (event.eventType == ListeningEventType.playbackCompleted ||
          event.eventType == ListeningEventType.meaningfulPlayback ||
          event.eventType == ListeningEventType.playbackStarted) {
        playEventsCount++;

        // Track & Artist tallies
        final art = event.artistName.trim();
        if (art.isNotEmpty) {
          artists.add(art);
          artistCounts[art] = (artistCounts[art] ?? 0) + 1;

          if (!seenArtistsChronological.contains(art.toLowerCase())) {
            seenArtistsChronological.add(art.toLowerCase());
            newDiscoveriesCount++;
          }
        }

        final trk = event.trackTitle.trim();
        if (trk.isNotEmpty) {
          trackCounts[trk] = (trackCounts[trk] ?? 0) + 1;
        }

        final gen = event.genre.trim();
        if (gen.isNotEmpty && gen.toLowerCase() != 'unknown') {
          genreCounts[gen] = (genreCounts[gen] ?? 0) + 1;
        }

        final alb = event.metadata['album']?.toString();
        if (alb != null && alb.isNotEmpty) {
          albums.add(alb);
        }

        // Time of day classification
        final hour = event.timestamp.hour;
        if (hour >= 5 && hour < 12) {
          timeOfDay['Morning'] = timeOfDay['Morning']! + 1;
        } else if (hour >= 12 && hour < 17) {
          timeOfDay['Afternoon'] = timeOfDay['Afternoon']! + 1;
        } else if (hour >= 17 && hour < 22) {
          timeOfDay['Evening'] = timeOfDay['Evening']! + 1;
        } else {
          timeOfDay['Night'] = timeOfDay['Night']! + 1;
        }

        // Weekday vs Weekend
        final weekday = event.timestamp.weekday;
        if (weekday >= 1 && weekday <= 5) {
          weekdayWeekend['Weekdays'] = weekdayWeekend['Weekdays']! + 1;
        } else {
          weekdayWeekend['Weekends'] = weekdayWeekend['Weekends']! + 1;
        }
      }
    }

    // Sort Top Artists
    final sortedArtists = artistCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Sort Top Songs
    final sortedSongs = trackCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return MusicDnaOverview(
      totalListeningMinutes: (totalDurationMs / 60000).round(),
      totalPlays: playEventsCount,
      uniqueArtistsCount: artists.length,
      uniqueAlbumsCount: albums.length,
      topArtists: sortedArtists.take(10).toList(),
      topSongs: sortedSongs.take(10).toList(),
      genreBreakdown: genreCounts,
      timeOfDayDistribution: timeOfDay,
      weekdayWeekendDistribution: weekdayWeekend,
      newlyDiscoveredArtistsCount: newDiscoveriesCount,
      recentActivityTimeline: events.take(15).toList(),
    );
  }

  /// Calculates the user's personal relationship with a specific artist.
  Future<ArtistPersonalRelationship> getArtistRelationship(String artistName) async {
    await _buffer.init();
    final events = _buffer.getRecentEvents(limit: 500);

    final cleanName = artistName.trim().toLowerCase();
    int totalPlays = 0;
    final Map<String, int> trackPlays = {};
    DateTime? firstPlay;
    DateTime? lastPlay;
    double sumRatio = 0.0;
    int ratioCount = 0;

    for (final e in events) {
      if (e.artistName.toLowerCase().contains(cleanName) ||
          e.artists.any((a) => a.toLowerCase().contains(cleanName))) {
        totalPlays++;
        trackPlays[e.trackTitle] = (trackPlays[e.trackTitle] ?? 0) + 1;

        if (firstPlay == null || e.timestamp.isBefore(firstPlay)) {
          firstPlay = e.timestamp;
        }
        if (lastPlay == null || e.timestamp.isAfter(lastPlay)) {
          lastPlay = e.timestamp;
        }

        sumRatio += e.completionRatio;
        ratioCount++;
      }
    }

    final sortedTracks = trackPlays.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ArtistPersonalRelationship(
      artistName: artistName,
      totalPlays: totalPlays,
      mostPlayedTracks: sortedTracks.take(5).toList(),
      firstRecordedPlay: firstPlay,
      lastRecordedPlay: lastPlay,
      averageCompletionRate: ratioCount == 0 ? 0.0 : sumRatio / ratioCount,
    );
  }

  /// Calculates the user's personal listening insights for a single track.
  Future<TrackPersonalInsights> getTrackInsights(String trackTitle) async {
    await _buffer.init();
    final events = _buffer.getRecentEvents(limit: 500);

    final cleanTitle = trackTitle.trim().toLowerCase();
    int plays = 0;
    int skips = 0;
    double sumRatio = 0.0;
    int count = 0;
    DateTime? lastPlay;

    for (final e in events) {
      if (e.trackTitle.toLowerCase() == cleanTitle) {
        if (e.eventType == ListeningEventType.playbackSkipped) {
          skips++;
        } else {
          plays++;
        }
        sumRatio += e.completionRatio;
        count++;
        if (lastPlay == null || e.timestamp.isAfter(lastPlay)) {
          lastPlay = e.timestamp;
        }
      }
    }

    return TrackPersonalInsights(
      trackTitle: trackTitle,
      playCount: plays,
      skipCount: skips,
      completionPercentage: count == 0 ? 0.0 : (sumRatio / count) * 100,
      lastPlayedAt: lastPlay,
    );
  }
}
