import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/core/intelligence/events/listening_event.dart';

/// Buffers listening events in memory, persists to offline storage,
/// and streams events to taste intelligence consumers.
class ListeningEventBuffer {
  static const String _storageKey = 'listening_events_offline_buffer_v1';
  static const int _maxInMemoryEvents = 500;
  static const int _autoFlushThreshold = 25;

  static final ListeningEventBuffer _instance = ListeningEventBuffer._internal();
  factory ListeningEventBuffer() => _instance;
  static ListeningEventBuffer get instance => _instance;

  ListeningEventBuffer._internal();

  final List<ListeningEvent> _events = [];
  final StreamController<ListeningEvent> _eventStreamController = StreamController<ListeningEvent>.broadcast();
  bool _isInitialized = false;

  /// Real-time stream of incoming listening events.
  Stream<ListeningEvent> get eventStream => _eventStreamController.stream;

  /// Current count of events in buffer.
  int get count => _events.length;

  /// Initializes buffer and hydrates un-flushed events from persistent storage.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_storageKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
        _events.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _events.add(ListeningEvent.fromJson(item));
          }
        }
      }
    } catch (_) {
      // Graceful local hydration fallback
    } finally {
      _isInitialized = true;
    }
  }

  /// Appends an event to the buffer, broadcasts it, and triggers auto-persistence if threshold is reached.
  Future<void> recordEvent(ListeningEvent event) async {
    _events.add(event);
    _eventStreamController.add(event);

    // Prune oldest if exceeds capacity
    if (_events.length > _maxInMemoryEvents) {
      _events.removeRange(0, _events.length - _maxInMemoryEvents);
    }

    if (_events.length % _autoFlushThreshold == 0) {
      await persist();
    }
  }

  /// Returns recent listening events matching optional criteria.
  List<ListeningEvent> getRecentEvents({int limit = 100, Duration? within}) {
    final now = DateTime.now();
    var filtered = _events.reversed;
    if (within != null) {
      final threshold = now.subtract(within);
      filtered = filtered.where((e) => e.timestamp.isAfter(threshold));
    }
    return filtered.take(limit).toList();
  }

  /// Persists current in-memory buffer to disk.
  Future<void> persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = jsonEncode(_events.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, serialized);
    } catch (_) {
      // Ignored for non-blocking execution
    }
  }

  /// Clears in-memory and persistent buffer (e.g. on profile reset or tests).
  Future<void> clear() async {
    _events.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }
}
