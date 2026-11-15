import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/core/utils/track_validation_engine.dart';

enum ListeningCollectionKind { artist, year, decade, mood, genre, album, radio }

class ListeningCollection {
  final String id;
  final String title;
  final String query;
  final ListeningCollectionKind kind;
  final Song? seed;
  final int? year;
  final String? artist;
  final String? album;

  const ListeningCollection({
    required this.id,
    required this.title,
    required this.query,
    required this.kind,
    this.seed,
    this.year,
    this.artist,
    this.album,
  });

  String get subtitle => switch (kind) {
    ListeningCollectionKind.artist => 'Artist mix · refresh for a new order',
    ListeningCollectionKind.year => 'Songs released in $year',
    ListeningCollectionKind.decade => 'A trip through the $query',
    ListeningCollectionKind.mood => 'Set the mood',
    ListeningCollectionKind.genre => 'Explore $query',
    ListeningCollectionKind.album => 'An album listening session',
    ListeningCollectionKind.radio =>
      'Songs inspired by ${seed?.title ?? query}',
  };

  static ListeningCollection songRadio(Song song) => ListeningCollection(
    id: 'radio:${song.id}',
    title: '${song.title} Radio',
    query: song.artist,
    kind: ListeningCollectionKind.radio,
    seed: song,
  );

  static List<ListeningCollection> catalogue(
    List<Song> history, {
    DateTime? now,
    List<String> favoriteArtists = const [],
  }) {
    final artists = <String>{
      ...favoriteArtists,
      ...history.map((s) => s.artist.split(',').first.trim()),
      'Arijit Singh',
      'Shreya Ghoshal',
      'Pritam',
      'Diljit Dosanjh',
      'Karan Aujla',
      'AP Dhillon',
      'The Weeknd',
      'Taylor Swift',
      'Dua Lipa',
      'Anuv Jain',
      'Prateek Kuhad',
      'A. R. Rahman',
    }.where((a) => a.isNotEmpty && a.toLowerCase() != 'unknown artist');
    final currentYear = (now ?? DateTime.now()).year;
    final albums = <String, Song>{};
    for (final song in history) {
      if (song.album.trim().isNotEmpty &&
          song.album.toLowerCase() != 'unknown') {
        albums.putIfAbsent(
          '${song.artist.toLowerCase()}|${song.album.toLowerCase()}',
          () => song,
        );
      }
    }
    return [
      for (final artist in artists.take(18))
        ListeningCollection(
          id: 'artist:${artist.toLowerCase()}',
          title: '$artist Mix',
          query: artist,
          kind: ListeningCollectionKind.artist,
          artist: artist,
        ),
      for (var year = currentYear; year >= currentYear - 25; year--)
        ListeningCollection(
          id: 'year:$year',
          title: 'The sound of $year',
          query: 'hits $year',
          year: year,
          kind: ListeningCollectionKind.year,
        ),
      for (final decade in [1960, 1970, 1980, 1990, 2000, 2010, 2020])
        ListeningCollection(
          id: 'decade:$decade',
          title: '${decade}s Essentials',
          query: '${decade}s',
          year: decade,
          kind: ListeningCollectionKind.decade,
        ),
      for (final mood in [
        'Romantic',
        'Happy',
        'Melancholic',
        'Relaxed',
        'Energetic',
        'Peaceful',
        'Nostalgic',
        'Motivational',
        'Atmospheric',
      ])
        ListeningCollection(
          id: 'mood:$mood',
          title: '$mood Mix',
          query: '$mood music',
          kind: ListeningCollectionKind.mood,
        ),
      for (final genre in [
        'Bollywood',
        'Punjabi',
        'Pop',
        'Rock',
        'Hip-Hop',
        'Indie',
        'Acoustic',
        'Electronic',
        'Jazz',
        'Classical',
        'R&B',
        'Folk',
      ])
        ListeningCollection(
          id: 'genre:$genre',
          title: '$genre Essentials',
          query: genre,
          kind: ListeningCollectionKind.genre,
        ),
      for (final song in albums.values.take(12))
        ListeningCollection(
          id: 'album:${song.artist.toLowerCase()}:${song.album.toLowerCase()}',
          title: song.album,
          query: '${song.album} ${song.artist}',
          kind: ListeningCollectionKind.album,
          album: song.album,
          artist: song.artist,
          seed: song,
        ),
      for (final song in {for (final s in history) s.id: s}.values.take(12))
        ListeningCollection.songRadio(song),
    ];
  }
}

/// Discovery uses the installed repository only; no provider endpoints or streams.
class ListeningCollectionService {
  final IMusicRepository repository;
  final Random random;
  final Map<String, Future<List<Song>>> _pending = {};
  static const _prefix = 'listening_collection_v1:';

  ListeningCollectionService(this.repository, {Random? random})
    : random = random ?? Random();

  Future<List<Song>> load(
    ListeningCollection collection, {
    bool refresh = false,
  }) {
    return _pending.putIfAbsent(
      collection.id,
      () => _load(collection, refresh: refresh).whenComplete(() {
        _pending.remove(collection.id);
      }),
    );
  }

  Future<List<Song>> _load(
    ListeningCollection collection, {
    required bool refresh,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix${collection.id}';
    List<Song> cached = [];
    DateTime? saved;
    try {
      final raw = prefs.getString(key);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        cached = select(
          collection,
          (data['tracks'] as List).map((s) {
            final json = Map<String, dynamic>.from(s as Map);
            // This is our own snapshot, so preserve addon identity verbatim.
            final song = Song.fromJson(json);
            song.id = json['id'] as String;
            song.saavnId = json['saavnId'] as String;
            return song;
          }),
        );
        saved = DateTime.tryParse(data['saved'] as String);
      }
    } catch (_) {
      /* A damaged collection does not invalidate other caches. */
    }
    if (!refresh &&
        cached.isNotEmpty &&
        saved != null &&
        DateTime.now().difference(saved) < const Duration(hours: 12)) {
      return cached;
    }

    List<Song> candidates = [];
    try {
      if (collection.kind == ListeningCollectionKind.radio &&
          collection.seed != null) {
        candidates = await repository
            .getRecommendedSongs(collection.seed!)
            .timeout(const Duration(seconds: 15));
      }
      if (candidates.isEmpty) {
        candidates = await repository
            .searchSongs(collection.query, count: 60)
            .timeout(const Duration(seconds: 15));
      }
    } catch (_) {
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
    var tracks = select(collection, candidates);
    if (tracks.isEmpty) return cached;
    if (collection.kind != ListeningCollectionKind.album) {
      tracks.shuffle(random);
      if (tracks.length > 1 &&
          cached.isNotEmpty &&
          tracks.first.id == cached.first.id) {
        tracks = [...tracks.skip(1), tracks.first];
      }
    }
    if (collection.kind == ListeningCollectionKind.radio &&
        collection.seed != null) {
      tracks = [
        collection.seed!,
        ...tracks.where((s) => s.id != collection.seed!.id),
      ];
    }
    tracks = tracks.take(40).toList();
    await prefs.setString(
      key,
      jsonEncode({
        'saved': DateTime.now().toIso8601String(),
        'tracks': tracks.map((s) => s.toJson()).toList(),
      }),
    );
    // Bound disk growth; retain the most recently used collection snapshots.
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    if (keys.length > 80) {
      keys.remove(key);
      keys.sort((a, b) => _savedAt(prefs, a).compareTo(_savedAt(prefs, b)));
      for (final old in keys.take(keys.length - 79)) {
        await prefs.remove(old);
      }
    }
    return tracks;
  }

  static String _savedAt(SharedPreferences prefs, String key) {
    try {
      return (jsonDecode(prefs.getString(key)!) as Map)['saved'] as String;
    } catch (_) {
      return '';
    }
  }

  static List<Song> select(
    ListeningCollection collection,
    Iterable<Song> candidates,
  ) {
    final unique = <String, Song>{};
    for (final song in TrackValidationEngine.filterAndRank(
      candidates.toList(),
      preserveOriginalOrderIfValid: true,
    )) {
      if (song.id.isEmpty || song.id.startsWith('radio:')) continue;
      if (collection.kind == ListeningCollectionKind.year &&
          song.year != collection.year) {
        continue;
      }
      if (collection.kind == ListeningCollectionKind.decade &&
          (song.year < collection.year! ||
              song.year >= collection.year! + 10)) {
        continue;
      }
      if (collection.kind == ListeningCollectionKind.artist &&
          !song.artist
              .toLowerCase()
              .split(RegExp(r'[,;&]'))
              .map((a) => a.trim())
              .contains(collection.artist!.toLowerCase())) {
        continue;
      }
      if (collection.kind == ListeningCollectionKind.album &&
          (song.album.toLowerCase() != collection.album!.toLowerCase() ||
              song.artist.toLowerCase() != collection.artist!.toLowerCase())) {
        continue;
      }
      unique.putIfAbsent(song.id, () => song);
    }
    return unique.values.toList();
  }
}
