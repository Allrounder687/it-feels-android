import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/core/intelligence/playlists/dynamic_playlist_models.dart';
import 'package:it_feels_music/core/intelligence/playlists/playlist_version_engine.dart';

/// Central service managing lifecycle, scheduled refreshes, and persistence for dynamic playlists.
class DynamicPlaylistService {
  static const String _storagePrefix = 'dynamic_playlist_v1_';
  static final DynamicPlaylistService _instance = DynamicPlaylistService._internal();
  factory DynamicPlaylistService() => _instance;
  static DynamicPlaylistService get instance => _instance;

  DynamicPlaylistService._internal();

  final Map<String, DynamicPlaylist> _playlists = {};
  bool _isInitialized = false;

  IMusicRepository? _injectedRepo;
  IMusicRepository get _musicRepo => _injectedRepo ?? locator<IMusicRepository>();

  @visibleForTesting
  void setMusicRepository(IMusicRepository repo) {
    _injectedRepo = repo;
  }

  /// Initializes the service and hydrates existing playlists from storage.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_storagePrefix));
      for (final key in keys) {
        final raw = prefs.getString(key);
        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          final playlist = DynamicPlaylist.fromJson(decoded);
          _playlists[playlist.id] = playlist;
        }
      }
    } catch (e) {
      debugPrint('[DynamicPlaylistService] Hydration failed: $e');
    } finally {
      _isInitialized = true;
    }
  }

  /// Retrieves a dynamic playlist by ID.
  DynamicPlaylist? getPlaylist(String id) => _playlists[id];

  /// Returns all active dynamic playlists.
  List<DynamicPlaylist> getAllPlaylists() => _playlists.values.toList();

  /// Refreshes a dynamic playlist, applying user modifications so user edits survive.
  Future<DynamicPlaylist> refreshPlaylist(String playlistId) async {
    final current = _playlists[playlistId] ?? _createDefaultSkeleton(playlistId);

    List<Song> freshlyGenerated = [];
    try {
      final query = _getSeedQueryForPlaylist(playlistId);
      freshlyGenerated = await _musicRepo.searchSongs(query, count: 25);
    } catch (e) {
      debugPrint('[DynamicPlaylistService] Refresh query failed for $playlistId: $e');
    }

    final reconciled = PlaylistVersionEngine.reconcileRefresh(
      currentPlaylist: current,
      freshlyGeneratedTracks: freshlyGenerated.isNotEmpty ? freshlyGenerated : current.tracks,
    );

    _playlists[playlistId] = reconciled;
    await persistPlaylist(reconciled);
    return reconciled;
  }

  /// Manually adds a track to a dynamic playlist.
  Future<void> addTrack(String playlistId, Song song) async {
    final current = _playlists[playlistId] ?? _createDefaultSkeleton(playlistId);
    final updated = PlaylistVersionEngine.addTrack(playlist: current, song: song);
    _playlists[playlistId] = updated;
    await persistPlaylist(updated);
  }

  /// Manually removes a track from a dynamic playlist.
  Future<void> removeTrack(String playlistId, String songId) async {
    final current = _playlists[playlistId];
    if (current == null) return;
    final updated = PlaylistVersionEngine.removeTrack(playlist: current, songId: songId);
    _playlists[playlistId] = updated;
    await persistPlaylist(updated);
  }

  /// Persists a playlist to local storage.
  Future<void> persistPlaylist(DynamicPlaylist playlist) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_storagePrefix${playlist.id}';
      final jsonStr = jsonEncode(playlist.toJson());
      await prefs.setString(key, jsonStr);
    } catch (_) {}
  }

  String _getSeedQueryForPlaylist(String id) {
    switch (id) {
      case 'daily_mix_1':
        return 'Bollywood Romance';
      case 'daily_mix_2':
        return 'Pop International Hits';
      case 'daily_mix_3':
        return 'Punjabi Hits';
      case 'daily_mix_4':
        return 'Desi Hip Hop';
      case 'daily_mix_5':
        return 'Acoustic Indie Hindi';
      case 'daily_mix_6':
        return 'Party Dance Hits';
      case 'discover_weekly':
        return 'Trending India';
      case 'release_radar':
        return 'New Hindi Releases';
      default:
        return 'Top Hits';
    }
  }

  DynamicPlaylist _createDefaultSkeleton(String id) {
    final titles = {
      'daily_mix_1': 'Bollywood Romance',
      'daily_mix_2': 'Pop & International',
      'daily_mix_3': 'Punjabi Beats',
      'daily_mix_4': 'Desi Hip-Hop',
      'daily_mix_5': 'Acoustic & Indie',
      'daily_mix_6': 'Club & Party Anthems',
      'discover_weekly': 'Discover Weekly',
      'release_radar': 'Release Radar',
    };

    final subtitles = {
      'daily_mix_1': 'Arijit Singh, Pritam, Shreya Ghoshal',
      'daily_mix_2': 'The Weeknd, Taylor Swift, Drake',
      'daily_mix_3': 'Diljit Dosanjh, Karan Aujla, AP Dhillon',
      'daily_mix_4': 'DIVINE, Seedhe Maut, KR\$NA',
      'daily_mix_5': 'Anuv Jain, Prateek Kuhad, Jasleen Royal',
      'daily_mix_6': 'Badshah, Yo Yo Honey Singh, Nucleya',
      'discover_weekly': 'Your weekly personalized discovery mixtape',
      'release_radar': 'Catch all the newest music from artists you love',
    };

    return DynamicPlaylist(
      id: id,
      title: titles[id] ?? 'Dynamic Mix',
      subtitle: subtitles[id] ?? 'Updated automatically',
      lastRefreshedAt: DateTime.now(),
    );
  }
}
