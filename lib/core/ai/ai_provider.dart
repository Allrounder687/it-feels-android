import 'package:it_feels_music/data/models/song_model.dart';

// ─────────────────────────────────────────────
// AIProvider — abstract interface every real/mock provider must implement.
// The UI and AIService depend only on this contract, never on concrete classes.
// ─────────────────────────────────────────────
abstract class AIProvider {
  String get id;
  String get displayName;

  Future<List<Song>> generatePlaylistFromRequest({
    required String userRequest,
    required List<Song> localLibrary,
    Duration? maxResponseTime,
  });

  /// Generates a list of 10 global song titles + artists based on a user request
  /// when the local library is empty or lacks matches.
  Future<List<String>> generateGlobalPlaylistNames({
    required String userRequest,
    Duration? maxResponseTime,
  });

  Future<List<Song>> reorderQueueByMood({
    required List<Song> queue,
    required String moodDescription,
  });

  Future<String> suggestPlaylistName({
    required String initialName,
    required List<Song> songs,
  });

  Future<String> describePlaylistVibe({required List<Song> songs});

  Future<List<Song>> recommendSongs({
    required List<Song> library,
    required String context,
  });

  Future<bool> checkAvailability();
}

// ─────────────────────────────────────────────
// AIResponse — unified result type returned by AIService.
// UI only touches this — never touches provider internals.
// ─────────────────────────────────────────────
class AIResponse {
  final String providerId;
  final DateTime timestamp;
  final bool success;
  final String? error;
  final List<Song>? resultSongs;
  final String? resultText;
  final List<String>? resultNames;

  const AIResponse._({
    required this.providerId,
    required this.timestamp,
    required this.success,
    this.error,
    this.resultSongs,
    this.resultText,
    this.resultNames,
  });

  factory AIResponse.songs({
    required String providerId,
    required List<Song> songs,
  }) =>
      AIResponse._(
        providerId: providerId,
        timestamp: DateTime.now(),
        success: true,
        resultSongs: songs,
      );

  factory AIResponse.text({
    required String providerId,
    required String text,
  }) =>
      AIResponse._(
        providerId: providerId,
        timestamp: DateTime.now(),
        success: true,
        resultText: text,
      );

  factory AIResponse.names({
    required String providerId,
    required List<String> names,
  }) =>
      AIResponse._(
        providerId: providerId,
        timestamp: DateTime.now(),
        success: true,
        resultNames: names,
      );

  factory AIResponse.failure({
    required String providerId,
    required String error,
  }) =>
      AIResponse._(
        providerId: providerId,
        timestamp: DateTime.now(),
        success: false,
        error: error,
      );

  // Compat factories so existing callers keep working
  factory AIResponse.success({required String providerId, required List<Song> songs}) =>
      AIResponse.songs(providerId: providerId, songs: songs);

  factory AIResponse.textSuccess({required String providerId, required String text}) =>
      AIResponse.text(providerId: providerId, text: text);
}
