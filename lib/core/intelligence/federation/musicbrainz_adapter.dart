import 'dart:async';
import '../orchestration/enterprise_api_orchestrator.dart';
import '../orchestration/tiered_cache_manager.dart';
import 'data_provenance.dart';
import 'canonical_contributor.dart';

class MusicBrainzRecordingInfo {
  final String mbid;
  final String title;
  final String? isrc;
  final int? durationMs;
  final String? releaseTitle;
  final String? releaseDate;
  final List<CanonicalContributor> contributors;
  final DataProvenance provenance;

  MusicBrainzRecordingInfo({
    required this.mbid,
    required this.title,
    this.isrc,
    this.durationMs,
    this.releaseTitle,
    this.releaseDate,
    this.contributors = const [],
    required this.provenance,
  });
}

class MusicBrainzArtistInfo {
  final String mbid;
  final String name;
  final String? sortName;
  final String? country;
  final String? activeFrom;
  final String? activeTo;
  final List<String> releaseGroupTitles;
  final List<String> collaborators;
  final DataProvenance provenance;

  MusicBrainzArtistInfo({
    required this.mbid,
    required this.name,
    this.sortName,
    this.country,
    this.activeFrom,
    this.activeTo,
    this.releaseGroupTitles = const [],
    this.collaborators = const [],
    required this.provenance,
  });
}

/// Authoritative MusicBrainz metadata adapter compliant with MetaBrainz Foundation
/// rate limits (1 req/sec) and CC0 / Open Access data terms.
class MusicBrainzAdapter {
  final EnterpriseApiOrchestrator _orchestrator;

  MusicBrainzAdapter({EnterpriseApiOrchestrator? orchestrator})
      : _orchestrator = orchestrator ?? EnterpriseApiOrchestrator();

  /// Searches for an artist MBID and basic information.
  Future<MusicBrainzArtistInfo?> fetchArtistInfo(String artistName) async {
    final query = Uri.encodeComponent('artist:"$artistName"');
    final searchUrl = 'https://musicbrainz.org/ws/2/artist/?query=$query&fmt=json&limit=1';

    final searchJson = await _orchestrator.getJson(
      provider: 'musicbrainz',
      url: searchUrl,
      cacheType: CacheContentType.artist,
    );

    if (searchJson == null || searchJson['artists'] == null) return null;
    final artists = searchJson['artists'] as List;
    if (artists.isEmpty) return null;

    final first = artists.first as Map<String, dynamic>;
    final mbid = first['id']?.toString() ?? '';
    if (mbid.isEmpty) return null;

    // Fetch expanded details including release groups and artist relations
    final detailUrl = 'https://musicbrainz.org/ws/2/artist/$mbid?inc=release-groups+artist-rels&fmt=json';
    final detailJson = await _orchestrator.getJson(
      provider: 'musicbrainz',
      url: detailUrl,
      cacheType: CacheContentType.artist,
      customTtl: const Duration(days: 14),
    );

    final effectiveJson = detailJson ?? first;
    final lifeSpan = effectiveJson['life-span'] as Map<String, dynamic>?;
    final releaseGroups = (effectiveJson['release-groups'] as List?)
            ?.map((rg) => rg['title']?.toString() ?? '')
            .where((t) => t.isNotEmpty)
            .toList() ??
        [];

    final collaborators = <String>[];
    if (effectiveJson['relations'] is List) {
      for (final rel in effectiveJson['relations'] as List) {
        if (rel['type'] == 'collaboration' || rel['type'] == 'member of band' || rel['type'] == 'supporting musician') {
          final target = rel['artist']?['name']?.toString();
          if (target != null && target.isNotEmpty && !collaborators.contains(target)) {
            collaborators.add(target);
          }
        }
      }
    }

    return MusicBrainzArtistInfo(
      mbid: mbid,
      name: effectiveJson['name']?.toString() ?? artistName,
      sortName: effectiveJson['sort-name']?.toString(),
      country: effectiveJson['country']?.toString(),
      activeFrom: lifeSpan?['begin']?.toString(),
      activeTo: lifeSpan?['end']?.toString(),
      releaseGroupTitles: releaseGroups,
      collaborators: collaborators,
      provenance: DataProvenance.musicBrainz(mbid),
    );
  }

  /// Searches and retrieves verified recording credits, composer, lyricist, and ISRC.
  Future<MusicBrainzRecordingInfo?> fetchRecordingCredits(String title, String artist) async {
    final cleanT = Uri.encodeComponent(title);
    final cleanA = Uri.encodeComponent(artist);
    final searchUrl = 'https://musicbrainz.org/ws/2/recording/?query=recording:"$cleanT"+AND+artist:"$cleanA"&fmt=json&limit=1';

    final searchJson = await _orchestrator.getJson(
      provider: 'musicbrainz',
      url: searchUrl,
      cacheType: CacheContentType.trackCredits,
    );

    if (searchJson == null || searchJson['recordings'] == null) return null;
    final recs = searchJson['recordings'] as List;
    if (recs.isEmpty) return null;

    final first = recs.first as Map<String, dynamic>;
    final mbid = first['id']?.toString() ?? '';
    if (mbid.isEmpty) return null;

    // Fetch expanded relationships (composer, lyricist, arranger, producer)
    final detailUrl = 'https://musicbrainz.org/ws/2/recording/$mbid?inc=artist-rels+work-rels+releases+isrcs&fmt=json';
    final detailJson = await _orchestrator.getJson(
      provider: 'musicbrainz',
      url: detailUrl,
      cacheType: CacheContentType.trackCredits,
      customTtl: const Duration(days: 14),
    );

    final effectiveJson = detailJson ?? first;
    final isrcList = effectiveJson['isrcs'] as List?;
    final firstIsrc = isrcList != null && isrcList.isNotEmpty ? isrcList.first?.toString() : null;

    final contributors = <CanonicalContributor>[];
    if (effectiveJson['relations'] is List) {
      for (final rel in effectiveJson['relations'] as List) {
        final type = rel['type']?.toString() ?? 'Contributor';
        final artistMap = rel['artist'] as Map<String, dynamic>?;
        if (artistMap != null) {
          final cName = artistMap['name']?.toString() ?? '';
          final cId = artistMap['id']?.toString() ?? '';
          if (cName.isNotEmpty) {
            String role = 'Contributor';
            if (type.contains('composer')) {
              role = 'Composer';
            } else if (type.contains('lyricist')) {
              role = 'Lyricist';
            } else if (type.contains('producer')) {
              role = 'Producer';
            } else if (type.contains('arranger')) {
              role = 'Arranger';
            } else if (type.contains('instrument')) {
              role = 'Musician';
            }

            contributors.add(CanonicalContributor(
              id: cId,
              name: cName,
              role: role,
              provenance: DataProvenance.musicBrainz(mbid),
            ));
          }
        }
      }
    }

    String? releaseTitle;
    String? releaseDate;
    if (effectiveJson['releases'] is List && (effectiveJson['releases'] as List).isNotEmpty) {
      final relMap = (effectiveJson['releases'] as List).first as Map<String, dynamic>;
      releaseTitle = relMap['title']?.toString();
      releaseDate = relMap['date']?.toString();
    }

    return MusicBrainzRecordingInfo(
      mbid: mbid,
      title: effectiveJson['title']?.toString() ?? title,
      isrc: firstIsrc,
      durationMs: effectiveJson['length'] is int ? effectiveJson['length'] as int : null,
      releaseTitle: releaseTitle,
      releaseDate: releaseDate,
      contributors: contributors,
      provenance: DataProvenance.musicBrainz(mbid),
    );
  }
}
