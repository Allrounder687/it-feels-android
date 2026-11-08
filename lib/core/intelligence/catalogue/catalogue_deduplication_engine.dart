import 'package:string_similarity/string_similarity.dart';
import 'package:it_feels_music/data/models/song_model.dart';

/// Result report from a deduplication pass.
class DeduplicationReport<T> {
  final List<T> uniqueItems;
  final int totalInputCount;
  final int duplicatesRemoved;
  final int legitimateVariantsPreserved;
  final List<String> consolidatedIdentifiers;

  const DeduplicationReport({
    required this.uniqueItems,
    required this.totalInputCount,
    required this.duplicatesRemoved,
    required this.legitimateVariantsPreserved,
    this.consolidatedIdentifiers = const [],
  });

  double get deduplicationRatio =>
      totalInputCount > 0 ? (duplicatesRemoved / totalInputCount) : 0.0;
}

/// Global deduplication engine for tracks, albums, playlists, and artwork across the application.
/// Strictly distinguishes between true identical duplicates and legitimate artistic variants
/// (live, remixes, acoustic versions, remasters, instrumentals, and language editions).
class CatalogueDeduplicationEngine {
  static final CatalogueDeduplicationEngine _instance =
      CatalogueDeduplicationEngine._internal();
  factory CatalogueDeduplicationEngine() => _instance;
  CatalogueDeduplicationEngine._internal();

  /// Variant tokens that denote legitimate musical versions that MUST NOT be merged.
  static const Set<String> _variantTokens = {
    'remix',
    'live',
    'acoustic',
    'unplugged',
    'instrumental',
    'karaoke',
    'reprise',
    'remaster',
    'remastered',
    'deluxe',
    'lofi',
    'lo-fi',
    'slowed',
    'reverb',
    'sped up',
    'radio edit',
    'extended',
    'club mix',
    'orchestral',
    'piano version',
    'original soundtrack',
    'ost',
    'cover',
  };

  /// Normalizes a song title while preserving or tagging recognized version variants.
  static String extractVariantSignature(String rawTitle) {
    final lower = rawTitle.toLowerCase();
    final matchedTokens = <String>[];
    for (final token in _variantTokens) {
      if (lower.contains(token)) {
        matchedTokens.add(token);
      }
    }
    matchedTokens.sort();
    return matchedTokens.join('|');
  }

  /// Normalizes clean acoustic title by stripping punctuation and parenthetical descriptors.
  static String normalizeBaseTitle(String rawTitle) {
    String clean = rawTitle.toLowerCase();
    // Remove parentheticals and brackets
    clean = clean.replaceAll(RegExp(r'[\(\[\{].*?[\)\]\}]'), ' ');
    // Remove featured artists text (feat., ft., with)
    clean = clean.replaceAll(RegExp(r'\b(feat|ft|featuring|with)\b.*'), ' ');
    // Strip non-alphanumeric except whitespace
    clean = clean.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return clean.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Normalizes artist string for fuzzy comparison.
  static String normalizeArtist(String rawArtist) {
    String clean = rawArtist.toLowerCase();
    // Split on separators and take primary artist
    final separators = RegExp(r'[,&/\\]|\b(feat|ft|featuring|and)\b');
    final parts = clean.split(separators);
    final primary = parts.isNotEmpty ? parts.first : clean;
    return primary.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Performs global deduplication on a track list.
  /// Removes duplicate recordings while preserving legitimate variants (remixes, live, remasters).
  DeduplicationReport<Song> deduplicateTracks(List<Song> songs) {
    if (songs.isEmpty) {
      return const DeduplicationReport(
        uniqueItems: [],
        totalInputCount: 0,
        duplicatesRemoved: 0,
        legitimateVariantsPreserved: 0,
      );
    }

    final uniqueList = <Song>[];
    final seenExactIds = <String>{};
    final seenClusterKeys = <String, Song>{};
    int duplicatesRemoved = 0;
    int variantsPreserved = 0;
    final consolidated = <String>[];

    for (final song in songs) {
      // 1. Exact ID deduplication
      if (seenExactIds.contains(song.id)) {
        duplicatesRemoved++;
        consolidated.add('${song.id} (Exact ID)');
        continue;
      }

      // 2. Exact Saavn/Provider ID deduplication
      if (song.saavnId.isNotEmpty && seenExactIds.contains(song.saavnId)) {
        duplicatesRemoved++;
        consolidated.add('${song.saavnId} (Exact Provider ID)');
        continue;
      }

      final baseTitle = normalizeBaseTitle(song.title);
      final primaryArtist = normalizeArtist(song.artist);
      final variantSig = extractVariantSignature(song.title);

      // If variant signature is present, it is a protected variant
      final clusterKey = '$primaryArtist::$baseTitle::$variantSig';

      if (seenClusterKeys.containsKey(clusterKey)) {
        final existing = seenClusterKeys[clusterKey]!;
        // Check duration similarity
        final durationDiff = (song.duration - existing.duration).abs();
        if (durationDiff <= 5) {
          // Genuine duplicate of the same recording!
          duplicatesRemoved++;
          consolidated.add('${song.title} by ${song.artist} -> ${existing.id}');
          continue;
        } else {
          // Duration difference > 5s implies different recording/cut
          variantsPreserved++;
        }
      } else {
        // Check if there is a base title match without the variant
        final baseKey = '$primaryArtist::$baseTitle';
        final hasBaseWithoutVariant = seenClusterKeys.keys.any((k) => k.startsWith('$baseKey::'));
        if (hasBaseWithoutVariant && variantSig.isNotEmpty) {
          variantsPreserved++;
        }
      }

      seenExactIds.add(song.id);
      if (song.saavnId.isNotEmpty) seenExactIds.add(song.saavnId);
      seenClusterKeys[clusterKey] = song;
      uniqueList.add(song);
    }

    return DeduplicationReport(
      uniqueItems: uniqueList,
      totalInputCount: songs.length,
      duplicatesRemoved: duplicatesRemoved,
      legitimateVariantsPreserved: variantsPreserved,
      consolidatedIdentifiers: consolidated,
    );
  }

  /// Deduplicates albums across multiple catalogue queries.
  /// Preserves deluxe editions, remasters, and anniversary releases as distinct.
  DeduplicationReport<Playlist> deduplicateAlbums(List<Playlist> albums) {
    if (albums.isEmpty) {
      return const DeduplicationReport(
        uniqueItems: [],
        totalInputCount: 0,
        duplicatesRemoved: 0,
        legitimateVariantsPreserved: 0,
      );
    }

    final uniqueList = <Playlist>[];
    final seenIds = <String>{};
    final seenSignatures = <String, Playlist>{};
    int duplicatesRemoved = 0;
    int variantsPreserved = 0;

    for (final album in albums) {
      if (seenIds.contains(album.id)) {
        duplicatesRemoved++;
        continue;
      }

      final baseTitle = normalizeBaseTitle(album.title);
      final artist = normalizeArtist(album.subtitle);
      final variantSig = extractVariantSignature(album.title);
      final sig = '$artist::$baseTitle::$variantSig';

      if (seenSignatures.containsKey(sig)) {
        duplicatesRemoved++;
        continue;
      }

      final baseSig = '$artist::$baseTitle';
      final hasBase = seenSignatures.keys.any((k) => k.startsWith('$baseSig::'));
      if (hasBase && variantSig.isNotEmpty) {
        variantsPreserved++;
      }

      seenIds.add(album.id);
      seenSignatures[sig] = album;
      uniqueList.add(album);
    }

    return DeduplicationReport(
      uniqueItems: uniqueList,
      totalInputCount: albums.length,
      duplicatesRemoved: duplicatesRemoved,
      legitimateVariantsPreserved: variantsPreserved,
    );
  }

  /// Deduplicates playlists based on name similarity and tracklist overlap (Jaccard Index).
  DeduplicationReport<Playlist> deduplicatePlaylists(List<Playlist> playlists) {
    if (playlists.isEmpty) {
      return const DeduplicationReport(
        uniqueItems: [],
        totalInputCount: 0,
        duplicatesRemoved: 0,
        legitimateVariantsPreserved: 0,
      );
    }

    final uniqueList = <Playlist>[];
    final seenIds = <String>{};
    int duplicatesRemoved = 0;

    for (final playlist in playlists) {
      if (seenIds.contains(playlist.id)) {
        duplicatesRemoved++;
        continue;
      }

      bool isDuplicate = false;
      for (final existing in uniqueList) {
        // 1. Check title similarity
        final titleSim = playlist.title.similarityTo(existing.title);
        if (titleSim > 0.92) {
          isDuplicate = true;
          break;
        }

        // 2. Check track ID Jaccard index if songs are populated
        if (playlist.songs != null &&
            existing.songs != null &&
            playlist.songs!.isNotEmpty &&
            existing.songs!.isNotEmpty) {
          final setA = playlist.songs!.map((s) => s.id).toSet();
          final setB = existing.songs!.map((s) => s.id).toSet();
          final intersection = setA.intersection(setB).length;
          final union = setA.union(setB).length;
          if (union > 0) {
            final jaccard = intersection / union;
            if (jaccard >= 0.85) {
              isDuplicate = true;
              break;
            }
          }
        }
      }

      if (isDuplicate) {
        duplicatesRemoved++;
      } else {
        seenIds.add(playlist.id);
        uniqueList.add(playlist);
      }
    }

    return DeduplicationReport(
      uniqueItems: uniqueList,
      totalInputCount: playlists.length,
      duplicatesRemoved: duplicatesRemoved,
      legitimateVariantsPreserved: 0,
    );
  }

  /// Deduplicates image artwork URLs by checking normalized URI stems and dimensions.
  List<String> deduplicateArtworkUrls(List<String> urls) {
    final cleanUrls = <String>[];
    final seenStems = <String>{};

    for (final rawUrl in urls) {
      if (rawUrl.trim().isEmpty) continue;
      // Strip dynamic CDN resize dimensions (e.g., -500x500.jpg, _500x500.jpg)
      final stem = rawUrl
          .replaceAll(RegExp(r'[-_]\d+x\d+\.(jpg|png|jpeg|webp)', caseSensitive: false), '')
          .toLowerCase();

      if (!seenStems.contains(stem)) {
        seenStems.add(stem);
        cleanUrls.add(rawUrl);
      }
    }
    return cleanUrls;
  }
}
