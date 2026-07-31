import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'ai_provider.dart';
import 'failure_mode.dart';
import 'package:it_feels_music/data/models/song_model.dart';

class MockAIProvider extends ChangeNotifier implements AIProvider {
  @override
  String get id => 'mock';

  @override
  String get displayName => 'Mock (Simulated)';

  bool _enableFailureMode = false;
  FailureMode _failureMode = FailureMode.success;
  Duration _latencyDelay = const Duration(milliseconds: 800);

  final Map<String, List<Song>> _cannedResponses = {
    'focus': [
      Song(
        id: 'mock:1',
        saavnId: 'mock:song1',
        title: 'Focus Flow',
        artist: 'Lo-Fi Beats',
        album: 'Study Sessions',
        duration: 180,
        coverArt: '',
        genre: 'Electronic',
        year: 2024,
        language: 'english',
        addedAt: DateTime.now(),
      ),
      Song(
        id: 'mock:2',
        saavnId: 'mock:song2',
        title: 'Deep Concentration',
        artist: 'Chill Vibes',
        album: 'Productivity',
        duration: 210,
        coverArt: '',
        genre: 'Ambient',
        year: 2024,
        language: 'english',
        addedAt: DateTime.now(),
      ),
    ],
    'rainy': [
      Song(
        id: 'mock:3',
        saavnId: 'mock:song3',
        title: 'Rainy Day Blues',
        artist: 'Soft Dreams',
        album: 'Weather Moods',
        duration: 240,
        coverArt: '',
        genre: 'Indie',
        year: 2024,
        language: 'english',
        addedAt: DateTime.now(),
      ),
      Song(
        id: 'mock:4',
        saavnId: 'mock:song4',
        title: 'Piano Rain',
        artist: 'Melancholy Keys',
        album: 'Weather Moods',
        duration: 195,
        coverArt: '',
        genre: 'Classical',
        year: 2024,
        language: 'english',
        addedAt: DateTime.now(),
      ),
    ],
    'party': [
      Song(
        id: 'mock:5',
        saavnId: 'mock:song5',
        title: 'Party Pulse',
        artist: 'DJ Energy',
        album: 'Night Life',
        duration: 200,
        coverArt: '',
        genre: 'EDM',
        year: 2024,
        language: 'english',
        addedAt: DateTime.now(),
      ),
      Song(
        id: 'mock:6',
        saavnId: 'mock:song6',
        title: 'Dance Night',
        artist: 'Bass Boosters',
        album: 'Club Mix',
        duration: 225,
        coverArt: '',
        genre: 'House',
        year: 2024,
        language: 'english',
        addedAt: DateTime.now(),
      ),
    ],
    'calm': [
      Song(
        id: 'mock:7',
        saavnId: 'mock:song7',
        title: 'Calm Waters',
        artist: 'Tranquil Sounds',
        album: 'Peaceful Moments',
        duration: 300,
        coverArt: '',
        genre: 'New Age',
        year: 2024,
        language: 'english',
        addedAt: DateTime.now(),
      ),
      Song(
        id: 'mock:8',
        saavnId: 'mock:song8',
        title: 'Morning Breeze',
        artist: 'Serene Tones',
        album: 'Peaceful Moments',
        duration: 180,
        coverArt: '',
        genre: 'Acoustic',
        year: 2024,
        language: 'english',
        addedAt: DateTime.now(),
      ),
    ],
  };

  bool get enableFailureMode => _enableFailureMode;
  set enableFailureMode(bool value) {
    if (_enableFailureMode != value) {
      _enableFailureMode = value;
      notifyListeners();
    }
  }

  FailureMode get failureMode => _failureMode;
  set failureMode(FailureMode mode) {
    if (_failureMode != mode) {
      _failureMode = mode;
      notifyListeners();
    }
  }

  Duration get latencyDelay => _latencyDelay;
  set latencyDelay(Duration delay) {
    _latencyDelay = delay;
    notifyListeners();
  }

  @override
  Future<List<Song>> generatePlaylistFromRequest({
    required String userRequest,
    required List<Song> localLibrary,
    Duration? maxResponseTime,
  }) async {
    await _applyLatency();
    if (_shouldFail()) throw _generateFailureException();

    final lower = userRequest.toLowerCase();
    if (lower.contains('focus') || lower.contains('study') || lower.contains('work')) {
      return _cannedResponses['focus'] ?? [];
    }
    if (lower.contains('rainy') || lower.contains('sad') || lower.contains('blue')) {
      return _cannedResponses['rainy'] ?? [];
    }
    if (lower.contains('party') || lower.contains('dance') || lower.contains('happy')) {
      return _cannedResponses['party'] ?? [];
    }
    if (lower.contains('calm') || lower.contains('relax') || lower.contains('sleep')) {
      return _cannedResponses['calm'] ?? [];
    }

    if (localLibrary.isNotEmpty) {
      return _shuffleList(localLibrary).take(3).toList();
    }
    return [];
  }

  @override
  Future<List<String>> generateGlobalPlaylistNames({
    required String userRequest,
    Duration? maxResponseTime,
  }) async {
    await _applyLatency();
    if (_shouldFail()) throw _generateFailureException();
    return [
      "Blinding Lights - The Weeknd",
      "Shape of You - Ed Sheeran",
      "Dance Monkey - Tones and I",
      "Rockstar - Post Malone",
      "One Dance - Drake",
      "Closer - The Chainsmokers",
      "Sunflower - Post Malone",
      "Señorita - Shawn Mendes",
      "Bad Guy - Billie Eilish",
      "Perfect - Ed Sheeran"
    ];
  }

  @override
  Future<List<Song>> reorderQueueByMood({
    required List<Song> queue,
    required String moodDescription,
  }) async {
    await _applyLatency();
    if (_shouldFail()) throw _generateFailureException();
    return _shuffleList(queue);
  }

  @override
  Future<String> suggestPlaylistName({
    required String initialName,
    required List<Song> songs,
  }) async {
    await _applyLatency();
    if (_shouldFail()) throw _generateFailureException();

    final adjectives = ['Awesome', 'Ultimate', 'Pure', 'Classic', 'Epic', 'Greatest', 'Essential'];
    final randomAdj = adjectives[Random().nextInt(adjectives.length)];
    return '$randomAdj $initialName Mix';
  }

  @override
  Future<String> describePlaylistVibe({required List<Song> songs}) async {
    await _applyLatency();
    if (_shouldFail()) throw _generateFailureException();

    if (songs.isEmpty) return 'Empty playlist vibes.';
    final genres = songs.map((s) => s.genre).toSet().toList();
    return 'This playlist mixes ${genres.join(', ')} vibes perfect for any mood.';
  }

  @override
  Future<List<Song>> recommendSongs({
    required List<Song> library,
    required String context,
  }) async {
    await _applyLatency();
    if (_shouldFail()) throw _generateFailureException();

    final lower = context.toLowerCase();
    return library
        .where((s) => s.title.toLowerCase().contains(lower) || s.artist.toLowerCase().contains(lower))
        .toList()
        .take(5)
        .toList();
  }

  @override
  Future<bool> checkAvailability() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return !_enableFailureMode ||
        (_failureMode != FailureMode.networkError && _failureMode != FailureMode.timeout);
  }

  bool _shouldFail() {
    return _enableFailureMode && _failureMode != FailureMode.success;
  }

  Exception _generateFailureException() {
    switch (_failureMode) {
      case FailureMode.networkError:
        return const SocketException('Network connection lost');
      case FailureMode.timeout:
        return TimeoutException('Request timed out after 30 seconds');
      case FailureMode.invalidRequest:
        return const FormatException('Invalid request format');
      default:
        return Exception('Mock provider error simulated');
    }
  }

  Future<void> _applyLatency() async {
    if (_latencyDelay > Duration.zero) {
      await Future.delayed(_latencyDelay);
    }
  }

  List<Song> _shuffleList(List<Song> input) {
    final shuffled = List<Song>.from(input);
    final random = Random();
    for (var i = shuffled.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = temp;
    }
    return shuffled;
  }

  void simulateNetworkError() {
    _enableFailureMode = true;
    _failureMode = FailureMode.networkError;
    notifyListeners();
  }

  void simulateTimeout() {
    _enableFailureMode = true;
    _failureMode = FailureMode.timeout;
    notifyListeners();
  }

  void simulateSuccessful() {
    _enableFailureMode = false;
    _failureMode = FailureMode.success;
    notifyListeners();
  }
}
