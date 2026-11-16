import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/core/utils/track_validation_engine.dart';
import 'package:it_feels_music/features/connected_music/connected_music_models.dart';
import 'package:it_feels_music/features/connected_music/connected_music_service.dart';

class DiscoveryPick {
  final String category;
  final Playlist? catalogue;
  final RemotePlaylist? remote;
  const DiscoveryPick(this.category, {this.catalogue, this.remote});
  String get key => remote?.key ?? 'catalogue:${catalogue!.id}';
  String get title => remote?.title ?? catalogue!.title;
  String get artwork => remote?.artwork ?? catalogue!.coverArt;
  String get source => remote != null ? 'YouTube Music' : 'Music catalogue';
}

/// Cold start needs no profile, saved playlist, account, or user-supplied prompt.
/// All collections and recordings come from installed providers; none are invented.
class DiscoveryFeedService extends ChangeNotifier {
  final IMusicRepository repository;
  final PublicPlaylistGateway? publicGateway;
  final Future<List<Song>> Function(String)? generate;
  final DateTime Function() clock;
  static const categories = [
    'Global pop',
    'Bollywood',
    'Punjabi',
    'Indie & acoustic',
    'Chill & focus',
    'Golden classics',
  ];
  static const queries = [
    'Today top pop hits',
    'Bollywood hits',
    'Punjabi hits',
    'Indie acoustic essentials',
    'Chill focus music',
    'Greatest classic hits',
  ];
  final List<DiscoveryPick> _picks = [];
  final List<Song> _sampler = [];
  List<Song> generated = [];
  bool loading = false, generating = false, _disposed = false;
  String? message;
  DateTime? updated;
  Future<void>? _pending, _initialization;
  int _generation = 0, _surprises = 0;
  DiscoveryFeedService(
    this.repository, {
    this.publicGateway,
    this.generate,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  List<DiscoveryPick> get picks => List.unmodifiable(_picks);
  List<Song> get sampler => List.unmodifiable(_sampler);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        'discovery_feed.v1',
      );
      if (raw == null || _disposed) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      updated = DateTime.tryParse(j['updated']?.toString() ?? '');
      for (final p in j['picks'] as List? ?? []) {
        try {
          if (p['remote'] != null) {
            _picks.add(
              DiscoveryPick(
                p['category'] as String,
                remote: RemotePlaylist.fromJson(
                  'youtube_music',
                  Map<String, dynamic>.from(p['remote'] as Map),
                ),
              ),
            );
          } else {
            _picks.add(
              DiscoveryPick(
                p['category'] as String,
                catalogue: Playlist.fromJson(
                  Map<String, dynamic>.from(p['catalogue'] as Map),
                ),
              ),
            );
          }
        } catch (_) {
          /* One damaged cached card does not hide the other shelves. */
        }
      }
      for (final s in j['sampler'] as List? ?? []) {
        final song = Song.fromJson(Map<String, dynamic>.from(s as Map));
        song.id = s['id'] as String;
        song.saavnId = s['saavnId'] as String? ?? '';
        _sampler.add(song);
      }
    } catch (_) {
      /* Rebuild a corrupt snapshot from live providers. */
    }
    _notify();
  }

  Future<void> refresh({bool force = false}) =>
      _pending ??= _refresh(force).whenComplete(() => _pending = null);
  Future<void> _refresh(bool force) async {
    await initialize();
    if (_disposed ||
        (!force &&
            _picks.isNotEmpty &&
            updated != null &&
            clock().difference(updated!) < const Duration(hours: 6))) {
      return;
    }
    loading = true;
    message = null;
    _notify();
    final current = ++_generation;
    bool active() => !_disposed && current == _generation;
    final fresh = <String, DiscoveryPick>{};
    final bucketSongs = <int, List<Song>>{};
    void publish() {
      if (!active()) return;
      if (fresh.isNotEmpty) {
        _picks
          ..clear()
          ..addAll(fresh.values);
      }
      final sample = diverseSampler([
        for (var i = 0; i < categories.length; i++) bucketSongs[i] ?? [],
      ]);
      if (sample.isNotEmpty) {
        _sampler
          ..clear()
          ..addAll(sample);
      }
      _notify();
    }

    Future<void> publicPicks() async {
      if (publicGateway == null) return;
      try {
        await for (final page in publicGateway!.discover(accountAddons.first)) {
          if (!active()) return;
          for (final p in [
            ...page.playlists.where((p) => p.videoId == null).take(12),
            ...page.playlists.where((p) => p.videoId != null).take(6),
          ]) {
            if (!p.requiresAccount && _suitable(p.title)) {
              fresh[p.key] = DiscoveryPick(
                p.videoId != null ? 'Long mixes' : 'YouTube discoveries',
                remote: p,
              );
            }
          }
          publish();
        }
      } catch (_) {
        /* Catalogue shelves remain usable when public YouTube is unavailable. */
      }
    }

    var nextBucket = 0;
    Future<void> worker() async {
      while (nextBucket < categories.length && active()) {
        final index = nextBucket++;
        try {
          final results = await repository
              .searchPlaylists(queries[index], count: 8)
              .timeout(const Duration(seconds: 15));
          for (final p
              in results
                  .where(
                    (p) =>
                        p.id.isNotEmpty &&
                        p.type.toLowerCase() == 'playlist' &&
                        _suitable(p.title),
                  )
                  .take(3)) {
            fresh.putIfAbsent(
              'catalogue:${p.id}',
              () => DiscoveryPick(categories[index], catalogue: p),
            );
          }
          publish();
        } catch (_) {
          /* Each bucket and provider fails independently. */
        }
        try {
          bucketSongs[index] = await repository
              .searchSongs(queries[index], count: 12)
              .timeout(const Duration(seconds: 15));
          publish();
        } catch (_) {
          /* Do not invent a sampler when catalogue queries fail. */
        }
      }
    }

    await Future.wait([worker(), publicPicks()]);
    if (!active()) return;
    loading = false;
    if (fresh.isNotEmpty || bucketSongs.values.any((s) => s.isNotEmpty)) {
      updated = clock();
      try {
        final data = {
          'updated': updated!.toIso8601String(),
          'picks': _picks
              .map(
                (p) => {
                  'category': p.category,
                  if (p.remote != null) 'remote': p.remote!.toJson(),
                  if (p.catalogue != null)
                    'catalogue': {
                      'id': p.catalogue!.id,
                      'title': p.title,
                      'coverArt': p.artwork,
                      'songCount': p.catalogue!.songCount,
                      'type': 'playlist',
                    },
                },
              )
              .toList(),
          'sampler': _sampler.map((s) => s.toJson()).toList(),
        };
        await (await SharedPreferences.getInstance()).setString(
          'discovery_feed.v1',
          jsonEncode(data),
        );
      } catch (_) {
        /* Discovery still works when caching is unavailable. */
      }
    } else {
      message = _picks.isEmpty && _sampler.isEmpty
          ? 'Discovery is temporarily unavailable. Check your connection and music addons, then retry.'
          : 'Showing your last discoveries. We could not refresh them just now.';
    }
    _notify();
  }

  Future<void> surprise() async {
    if (generating || _disposed) return;
    generating = true;
    _notify();
    try {
      final query = queries[(clock().day + _surprises++) % queries.length];
      final candidates = generate != null
          ? await generate!(query).timeout(const Duration(seconds: 30))
          : await repository.searchSongs(query, count: 40);
      if (!_disposed) generated = diverseSampler([candidates]);
    } catch (_) {
      if (!_disposed) generated = List.of(_sampler);
    }
    if (!_disposed) {
      generating = false;
      _notify();
    }
  }

  static bool _suitable(String title) =>
      title.trim().isNotEmpty &&
      !RegExp(
        r'karaoke|8[ -]?bit|16[ -]?bit|emulation|tribute to',
        caseSensitive: false,
      ).hasMatch(title);
  static List<Song> diverseSampler(List<List<Song>> buckets) {
    final validated = buckets
        .map(
          (s) => TrackValidationEngine.filterAndRank(
            s,
            preserveOriginalOrderIfValid: true,
          ),
        )
        .toList();
    final result = <Song>[], seen = <String>{}, artists = <String, int>{};
    final longest = validated.fold<int>(
      0,
      (n, s) => n > s.length ? n : s.length,
    );
    for (var row = 0; row < longest && result.length < 30; row++) {
      for (final bucket in validated) {
        if (row >= bucket.length || result.length >= 30) continue;
        final song = bucket[row],
            artist = bucket[row].artist.toLowerCase().trim();
        if (song.id.isEmpty ||
            song.id.startsWith('radio:') ||
            seen.contains(song.id) ||
            (artists[artist] ?? 0) >= 3) {
          continue;
        }
        seen.add(song.id);
        artists[artist] = (artists[artist] ?? 0) + 1;
        result.add(song);
      }
    }
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
