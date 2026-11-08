import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../orchestration/enterprise_api_orchestrator.dart';
import '../orchestration/tiered_cache_manager.dart';
import 'data_provenance.dart';

class LastfmArtistInsights {
  final String name;
  final String? bioSummary;
  final List<String> tags;
  final List<String> similarArtists;
  final DataProvenance provenance;

  LastfmArtistInsights({
    required this.name,
    this.bioSummary,
    this.tags = const [],
    this.similarArtists = const [],
    required this.provenance,
  });
}

/// Community tag, similar artist, and bio enrichment adapter powered by Last.fm.
class LastfmAdapter {
  final EnterpriseApiOrchestrator _orchestrator;
  static const String _defaultApiKey = 'c90ebc94fcce2775fbbcd46f7c787570'; // Public discovery fallback

  LastfmAdapter({EnterpriseApiOrchestrator? orchestrator})
      : _orchestrator = orchestrator ?? EnterpriseApiOrchestrator();

  String get _apiKey {
    if (dotenv.isInitialized && dotenv.env['LASTFM_API_KEY'] != null) {
      return dotenv.env['LASTFM_API_KEY']!;
    }
    return _defaultApiKey;
  }

  /// Fetches artist bio summary, genre tags, and similar artists.
  Future<LastfmArtistInsights?> fetchArtistInsights(String artistName) async {
    final cleanName = Uri.encodeComponent(artistName);
    final url = 'https://ws.audioscrobbler.com/2.0/?method=artist.getinfo&artist=$cleanName&api_key=$_apiKey&format=json&autocorrect=1';

    final json = await _orchestrator.getJson(
      provider: 'lastfm',
      url: url,
      cacheType: CacheContentType.artist,
      customTtl: const Duration(days: 7),
    );

    if (json == null || json['artist'] == null) return null;
    final artistMap = json['artist'] as Map<String, dynamic>;

    // 1. Tags
    final tags = <String>[];
    final rawTags = artistMap['tags']?['tag'];
    if (rawTags is List) {
      for (final t in rawTags) {
        final tName = t['name']?.toString();
        if (tName != null && tName.isNotEmpty && !tags.contains(tName)) {
          tags.add(tName);
        }
      }
    }

    // 2. Similar artists
    final similar = <String>[];
    final rawSimilar = artistMap['similar']?['artist'];
    if (rawSimilar is List) {
      for (final s in rawSimilar) {
        final sName = s['name']?.toString();
        if (sName != null && sName.isNotEmpty && !similar.contains(sName)) {
          similar.add(sName);
        }
      }
    }

    // 3. Bio summary
    String? bio;
    final bioSummary = artistMap['bio']?['summary']?.toString();
    if (bioSummary != null && bioSummary.isNotEmpty) {
      // Strip Last.fm HTML links e.g. <a href="...">Read more on Last.fm</a>
      bio = bioSummary.replaceAll(RegExp(r'<a\s+[^>]*>.*?<\/a>', caseSensitive: false), '').trim();
    }

    return LastfmArtistInsights(
      name: artistMap['name']?.toString() ?? artistName,
      bioSummary: bio,
      tags: tags,
      similarArtists: similar,
      provenance: DataProvenance.lastFm(artistName),
    );
  }
}
