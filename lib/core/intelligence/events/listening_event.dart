/// Enumeration of the standardized listening and engagement events (Section 6).
enum ListeningEventType {
  playbackStarted,
  meaningfulPlayback,
  playbackCompleted,
  playbackSkipped,
  trackReplayed,
  trackLiked,
  trackUnliked,
  trackSaved,
  trackHidden,
  artistHidden,
  artistFollowed,
  trackAddedToPlaylist,
  playlistAdded,
  playlistRemoved,
  playlistSaved,
  playlistOpened,
  recommendationImpression,
  recommendationClicked,
  recommendationDismissed,
  searchAndPlay,
  trackUnhidden,
  queueAppended,
  sharedTrack,
  seekPerformed,
  lyricsViewed,
  albumExplored,
  artistExplored,
}

/// Structured listening event tracking user interaction, duration, and mathematical engagement weight.
class ListeningEvent {
  final String eventId;
  final ListeningEventType eventType;
  final String canonicalTrackId;
  final String trackTitle;
  final String artistName;
  final List<String> artists;
  final String genre;
  final double completionRatio; // 0.0 to 1.0
  final int durationPlayedMs;
  final int totalDurationMs;
  final DateTime timestamp;
  final String? sessionId;
  final String? sourceContext; // e.g. 'home_feed', 'daily_mix_1', 'search', 'radio'
  final Map<String, dynamic> metadata;

  const ListeningEvent({
    required this.eventId,
    required this.eventType,
    required this.canonicalTrackId,
    required this.trackTitle,
    required this.artistName,
    this.artists = const [],
    this.genre = 'Unknown',
    this.completionRatio = 0.0,
    this.durationPlayedMs = 0,
    this.totalDurationMs = 0,
    required this.timestamp,
    this.sessionId,
    this.sourceContext,
    this.metadata = const {},
  });

  /// Evaluates mathematical engagement weight based on Section 5.1 & Section 6 specifications:
  /// - Immediate Skip (< 15s or < 10%): -0.35
  /// - Mid-Track Skip (15s <= t <= 50%): -0.05
  /// - Late Skip (50% < t < 85%): +0.40
  /// - Completion (>= 85%): +1.00
  /// - Replay: +1.75
  /// - Explicit Actions: Like (+2.50), Save (+2.25), Add to Playlist (+2.00), Hide Track (-10.00), Hide Artist (-15.00)
  double get engagementScore {
    switch (eventType) {
      case ListeningEventType.playbackStarted:
        return 0.05;

      case ListeningEventType.playbackSkipped:
        final playedSec = durationPlayedMs / 1000.0;
        if (playedSec < 15.0 || completionRatio < 0.10) {
          return -0.35; // Immediate skip penalty
        } else if (completionRatio < 0.50) {
          return -0.05; // Mid-track neutral/situational skip
        } else if (completionRatio < 0.85) {
          return 0.40; // Late skip (mostly listened)
        } else {
          return 1.00; // Treated as complete if >= 85%
        }

      case ListeningEventType.meaningfulPlayback:
        return 0.50;

      case ListeningEventType.playbackCompleted:
        return 1.00;

      case ListeningEventType.trackReplayed:
        return 1.75;

      case ListeningEventType.trackLiked:
        return 2.50;

      case ListeningEventType.trackUnliked:
        return -1.50;

      case ListeningEventType.trackSaved:
        return 2.25;

      case ListeningEventType.trackHidden:
        return -10.00; // Hard negative preference

      case ListeningEventType.artistHidden:
        return -15.00; // Hard negative artist preference

      case ListeningEventType.artistFollowed:
        return 3.00;

      case ListeningEventType.trackAddedToPlaylist:
      case ListeningEventType.playlistAdded:
        return 2.00;

      case ListeningEventType.playlistRemoved:
        return -0.50;

      case ListeningEventType.playlistSaved:
        return 2.50;

      case ListeningEventType.playlistOpened:
        return 0.30;

      case ListeningEventType.recommendationImpression:
        return 0.00; // Impression only, does not count as play

      case ListeningEventType.recommendationClicked:
        return 0.75;

      case ListeningEventType.recommendationDismissed:
        return -0.50;

      case ListeningEventType.searchAndPlay:
        return 1.25;

      case ListeningEventType.trackUnhidden:
        return 5.00; // Reversal of hard penalty

      case ListeningEventType.queueAppended:
        return 1.00;

      case ListeningEventType.sharedTrack:
        return 2.00;

      case ListeningEventType.lyricsViewed:
        return 0.50;

      case ListeningEventType.seekPerformed:
        return 0.10;

      case ListeningEventType.albumExplored:
        return 0.75;

      case ListeningEventType.artistExplored:
        return 0.75;
    }
  }

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'eventType': eventType.name,
    'canonicalTrackId': canonicalTrackId,
    'trackTitle': trackTitle,
    'artistName': artistName,
    'artists': artists,
    'genre': genre,
    'completionRatio': completionRatio,
    'durationPlayedMs': durationPlayedMs,
    'totalDurationMs': totalDurationMs,
    'timestamp': timestamp.toIso8601String(),
    'sessionId': sessionId,
    'sourceContext': sourceContext,
    'metadata': metadata,
  };

  factory ListeningEvent.fromJson(Map<String, dynamic> json) {
    return ListeningEvent(
      eventId: json['eventId']?.toString() ?? '',
      eventType: ListeningEventType.values.firstWhere(
        (e) => e.name == json['eventType'],
        orElse: () => ListeningEventType.playbackStarted,
      ),
      canonicalTrackId: json['canonicalTrackId']?.toString() ?? '',
      trackTitle: json['trackTitle']?.toString() ?? '',
      artistName: json['artistName']?.toString() ?? '',
      artists: (json['artists'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      genre: json['genre']?.toString() ?? 'Unknown',
      completionRatio: (json['completionRatio'] is num) ? (json['completionRatio'] as num).toDouble() : 0.0,
      durationPlayedMs: json['durationPlayedMs'] is int ? json['durationPlayedMs'] as int : 0,
      totalDurationMs: json['totalDurationMs'] is int ? json['totalDurationMs'] as int : 0,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      sessionId: json['sessionId']?.toString(),
      sourceContext: json['sourceContext']?.toString(),
      metadata: json['metadata'] is Map<String, dynamic> ? json['metadata'] as Map<String, dynamic> : {},
    );
  }
}
