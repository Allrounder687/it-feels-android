import 'package:it_feels_music/core/music_identity/canonical_track.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/utils/track_validation_engine.dart';
import 'package:it_feels_music/core/utils/string_utils.dart';

/// Central reconciliation engine that resolves external catalog tracks,
/// local files, and streaming candidates into deduplicated, canonical tracks.
class MusicIdentityResolver {
  static final MusicIdentityResolver _instance = MusicIdentityResolver._internal();
  factory MusicIdentityResolver() => _instance;
  static MusicIdentityResolver get instance => _instance;

  MusicIdentityResolver._internal();

  final Map<String, CanonicalTrack> _idIndex = {};
  final Map<String, CanonicalTrack> _isrcIndex = {};
  final Map<String, CanonicalTrack> _providerIndex = {};
  final Map<String, CanonicalTrack> _normalizedKeyIndex = {};

  /// Total count of indexed canonical tracks.
  int get indexedCount => _idIndex.length;

  /// Resolves an incoming Song model into a CanonicalTrack, linking provider references
  /// and deduplicating against existing catalog entries.
  CanonicalTrack resolveSong(Song song, {String provider = 'saavn'}) {
    final cleanTitle = StringUtils.cleanText(song.title);
    final cleanArtist = StringUtils.cleanText(song.artist);
    final normalizedKey = TrackValidationEngine.normalizeTrackKey(cleanTitle, cleanArtist);
    final providerKey = '$provider:${song.id}';

    // 1. Check direct provider index
    if (_providerIndex.containsKey(providerKey)) {
      final existing = _providerIndex[providerKey]!;
      return _updateStreamIfFresh(existing, song, provider);
    }

    // 2. Check normalized acoustic key index
    if (normalizedKey.isNotEmpty && _normalizedKeyIndex.containsKey(normalizedKey)) {
      final existing = _normalizedKeyIndex[normalizedKey]!;
      // Verify duration compatibility to avoid confusing short ringtones or extended mixes
      final durationDiff = (existing.duration - song.duration).abs();
      if (existing.duration <= 0 || song.duration <= 0 || durationDiff <= 15) {
        final merged = _mergeSongIntoTrack(existing, song, provider);
        _registerTrack(merged);
        return merged;
      }
    }

    // 3. Create fresh CanonicalTrack
    final fresh = CanonicalTrack.fromSong(song, provider: provider);
    _registerTrack(fresh);
    return fresh;
  }

  /// Resolves a batch of Song models into CanonicalTracks.
  List<CanonicalTrack> resolveSongs(List<Song> songs, {String provider = 'saavn'}) {
    return songs.map((s) => resolveSong(s, provider: provider)).toList();
  }

  /// Finds a canonical track by its primary ID.
  CanonicalTrack? findById(String id) => _idIndex[id];

  /// Finds a canonical track by provider and provider track ID.
  CanonicalTrack? findByProvider(String provider, String providerTrackId) {
    return _providerIndex['$provider:$providerTrackId'];
  }

  /// Finds a canonical track by ISRC.
  CanonicalTrack? findByIsrc(String isrc) => _isrcIndex[isrc.trim().toUpperCase()];

  /// Registers a canonical track across all indexes.
  void _registerTrack(CanonicalTrack track) {
    _idIndex[track.id] = track;

    if (track.isrc != null && track.isrc!.isNotEmpty) {
      _isrcIndex[track.isrc!.toUpperCase()] = track;
    }

    if (track.normalizedKey.isNotEmpty) {
      _normalizedKeyIndex[track.normalizedKey] = track;
    }

    for (final ref in track.providerRefs) {
      _providerIndex['${ref.provider}:${ref.providerTrackId}'] = track;
    }
  }

  CanonicalTrack _updateStreamIfFresh(CanonicalTrack existing, Song song, String provider) {
    if (song.streamUrl == null || song.streamUrl!.isEmpty) return existing;

    final updatedRefs = existing.providerRefs.map((ref) {
      if (ref.provider == provider && ref.providerTrackId == song.id) {
        return ref.copyWith(
          streamUrl: song.streamUrl,
          encryptedMediaUrl: song.encryptedMediaUrl,
          lastVerifiedAt: DateTime.now(),
        );
      }
      return ref;
    }).toList();

    final updated = existing.copyWith(providerRefs: updatedRefs);
    _registerTrack(updated);
    return updated;
  }

  CanonicalTrack _mergeSongIntoTrack(CanonicalTrack existing, Song song, String provider) {
    final existingRefIndex = existing.providerRefs.indexWhere(
      (r) => r.provider == provider && r.providerTrackId == song.id,
    );

    final newRef = ProviderTrackRef(
      provider: provider,
      providerTrackId: song.id,
      streamUrl: song.streamUrl ?? (existingRefIndex != -1 ? existing.providerRefs[existingRefIndex].streamUrl : null),
      encryptedMediaUrl: song.encryptedMediaUrl,
      lastVerifiedAt: DateTime.now(),
      rawMetadata: {
        'saavnId': song.saavnId,
        'genre': song.genre,
        'year': song.year,
        'language': song.language,
      },
    );

    final updatedRefs = List<ProviderTrackRef>.from(existing.providerRefs);
    if (existingRefIndex != -1) {
      updatedRefs[existingRefIndex] = newRef;
    } else {
      updatedRefs.add(newRef);
    }

    return existing.copyWith(
      providerRefs: updatedRefs,
      genre: (existing.genre == 'Unknown' && song.genre.isNotEmpty) ? song.genre : existing.genre,
      year: (existing.year <= 1900 && song.year > 1900) ? song.year : existing.year,
      language: (existing.language == 'unknown' && song.language.isNotEmpty) ? song.language : existing.language,
      hasLyrics: existing.hasLyrics || song.hasLyrics,
    );
  }

  /// Clears in-memory resolution caches (useful for testing).
  void clear() {
    _idIndex.clear();
    _isrcIndex.clear();
    _providerIndex.clear();
    _normalizedKeyIndex.clear();
  }
}
