import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/core/intelligence/events/listening_event_buffer.dart';
import 'package:it_feels_music/core/intelligence/taste/user_taste_profile.dart';
import 'package:it_feels_music/core/intelligence/taste/taste_decay_engine.dart';

/// Central service that manages, persists, and continuously updates the user taste profile.
class TasteProfileService {
  static const String _storageKey = 'user_taste_profile_v1';
  static final TasteProfileService _instance = TasteProfileService._internal();
  factory TasteProfileService() => _instance;
  static TasteProfileService get instance => _instance;

  TasteProfileService._internal();

  UserTasteProfile _profile = UserTasteProfile.initial();
  final StreamController<UserTasteProfile> _profileController = StreamController<UserTasteProfile>.broadcast();
  StreamSubscription? _eventSubscription;
  bool _isInitialized = false;

  UserTasteProfile get profile => _profile;
  Stream<UserTasteProfile> get profileStream => _profileController.stream;

  /// Initializes profile service, hydrates from local storage, and binds to event stream.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _profile = UserTasteProfile.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('[TasteProfileService] Hydration failed: $e');
    } finally {
      _isInitialized = true;
    }

    // Subscribe to real-time listening events
    _eventSubscription?.cancel();
    _eventSubscription = ListeningEventBuffer.instance.eventStream.listen((_) {
      // Trigger profile recalculation in non-blocking microtask
      scheduleMicrotask(() => recalculate());
    });
  }

  /// Recalculates profile using all recent events in the buffer.
  Future<void> recalculate() async {
    final recentEvents = ListeningEventBuffer.instance.getRecentEvents(limit: 500);
    _profile = TasteDecayEngine.calculateProfile(
      events: recentEvents,
      existingProfile: _profile,
    );
    _profileController.add(_profile);
    await persist();
  }

  /// Adds an artist to the permanent exclusion list.
  Future<void> excludeArtist(String artist) async {
    final clean = artist.trim().toLowerCase();
    if (clean.isEmpty) return;
    final updated = Set<String>.from(_profile.excludedArtists)..add(clean);
    _profile = _profile.copyWith(excludedArtists: updated);
    _profileController.add(_profile);
    await persist();
  }

  /// Removes an artist from the exclusion list.
  Future<void> unexcludeArtist(String artist) async {
    final clean = artist.trim().toLowerCase();
    final updated = Set<String>.from(_profile.excludedArtists)..remove(clean);
    _profile = _profile.copyWith(excludedArtists: updated);
    _profileController.add(_profile);
    await persist();
  }

  /// Adds a genre to the permanent exclusion list.
  Future<void> excludeGenre(String genre) async {
    final clean = genre.trim().toLowerCase();
    if (clean.isEmpty) return;
    final updated = Set<String>.from(_profile.excludedGenres)..add(clean);
    _profile = _profile.copyWith(excludedGenres: updated);
    _profileController.add(_profile);
    await persist();
  }

  /// Removes a genre from the exclusion list.
  Future<void> unexcludeGenre(String genre) async {
    final clean = genre.trim().toLowerCase();
    final updated = Set<String>.from(_profile.excludedGenres)..remove(clean);
    _profile = _profile.copyWith(excludedGenres: updated);
    _profileController.add(_profile);
    await persist();
  }

  /// Adds a track to the excluded list.
  Future<void> excludeTrack(String trackId) async {
    final updated = Set<String>.from(_profile.excludedTrackIds)..add(trackId.trim());
    _profile = _profile.copyWith(excludedTrackIds: updated);
    _profileController.add(_profile);
    await persist();
  }

  /// Sets novelty tolerance between 0.0 (strict familiarity) and 1.0 (deep discovery).
  Future<void> setNoveltyTolerance(double value) async {
    _profile = _profile.copyWith(noveltyTolerance: value.clamp(0.0, 1.0));
    _profileController.add(_profile);
    await persist();
  }

  /// Persists current profile to SharedPreferences.
  Future<void> persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_profile.toJson());
      await prefs.setString(_storageKey, jsonStr);
    } catch (_) {}
  }

  /// Resets personalization profile to factory defaults.
  Future<void> reset() async {
    _profile = UserTasteProfile.initial();
    _profileController.add(_profile);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }

  void dispose() {
    _eventSubscription?.cancel();
    _profileController.close();
  }
}
