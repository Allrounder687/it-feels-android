import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:it_feels_music/core/music_identity/canonical_artist.dart';
import 'package:it_feels_music/core/music_identity/canonical_album.dart';
import 'package:it_feels_music/core/music_identity/canonical_track.dart';
import 'musicbrainz_adapter.dart';
import 'wikidata_adapter.dart';
import 'lastfm_adapter.dart';
import 'cover_art_archive_adapter.dart';
import 'canonical_contributor.dart';

/// Top-level coordinator that federates primary catalogue data with MusicBrainz,
/// Wikidata, Last.fm, and Cover Art Archive to produce deeply enriched canonical entities.
class FederatedMusicIntelligenceService {
  static final FederatedMusicIntelligenceService _instance =
      FederatedMusicIntelligenceService._internal();
  factory FederatedMusicIntelligenceService() => _instance;

  final MusicBrainzAdapter _musicBrainz;
  final WikidataAdapter _wikidata;
  final LastfmAdapter _lastfm;
  final CoverArtArchiveAdapter _coverArtArchive;

  FederatedMusicIntelligenceService._internal({
    MusicBrainzAdapter? musicBrainz,
    WikidataAdapter? wikidata,
    LastfmAdapter? lastfm,
    CoverArtArchiveAdapter? coverArtArchive,
  })  : _musicBrainz = musicBrainz ?? MusicBrainzAdapter(),
        _wikidata = wikidata ?? WikidataAdapter(),
        _lastfm = lastfm ?? LastfmAdapter(),
        _coverArtArchive = coverArtArchive ?? CoverArtArchiveAdapter();

  /// Enriches an artist with multi-source intelligence (biography, native names, country,
  /// timeline milestones, verified collaborators, and similar artists).
  Future<CanonicalArtist> enrichArtist(CanonicalArtist base) async {
    try {
      // Execute multi-source queries concurrently with graceful degradation
      final results = await Future.wait([
        _wikidata.fetchArtistProfile(base.name).catchError((_) => null),
        _musicBrainz.fetchArtistInfo(base.name).catchError((_) => null),
        _lastfm.fetchArtistInsights(base.name).catchError((_) => null),
      ]);

      final wikiProfile = results[0] as WikidataArtistProfile?;
      final mbInfo = results[1] as MusicBrainzArtistInfo?;
      final lastfmInsights = results[2] as LastfmArtistInsights?;

      // 1. Native Names
      final nativeNames = List<String>.from(base.nativeNames);
      if (wikiProfile != null) {
        for (final n in wikiProfile.nativeLabels) {
          if (!nativeNames.contains(n)) nativeNames.add(n);
        }
      }

      // 2. Genres & Tags
      final genres = List<String>.from(base.genres);
      if (lastfmInsights != null) {
        for (final t in lastfmInsights.tags) {
          if (!genres.contains(t) && genres.length < 8) genres.add(t);
        }
      }

      // 3. Collaborators
      final collaborators = List<String>.from(base.collaborators);
      if (mbInfo != null) {
        for (final c in mbInfo.collaborators) {
          if (!collaborators.contains(c) && collaborators.length < 12) collaborators.add(c);
        }
      }

      // 4. Similar Artists
      final similarArtists = List<String>.from(base.relatedArtists);
      if (lastfmInsights != null) {
        for (final s in lastfmInsights.similarArtists) {
          if (!similarArtists.contains(s) && similarArtists.length < 12) similarArtists.add(s);
        }
      }

      // 5. Biography Synthesis (Wikidata description + Last.fm summary)
      String? bio = base.biography;
      if (bio == null || bio.isEmpty) {
        if (lastfmInsights?.bioSummary != null && lastfmInsights!.bioSummary!.isNotEmpty) {
          bio = lastfmInsights.bioSummary;
        } else if (wikiProfile?.description != null) {
          bio = '${wikiProfile!.label} is an ${wikiProfile.description}.';
        }
      }

      // 6. Chronological Career Timeline
      final timeline = List<Map<String, dynamic>>.from(base.timeline);
      if (timeline.isEmpty) {
        if (wikiProfile?.birthDate != null) {
          timeline.add({
            'year': wikiProfile!.birthDate!.split('-').first,
            'title': 'Born / Career Origins',
            'detail': 'Born in ${wikiProfile.country ?? "India"}.',
          });
        }
        if (mbInfo?.activeFrom != null) {
          timeline.add({
            'year': mbInfo!.activeFrom!.split('-').first,
            'title': 'Active Debut',
            'detail': 'Official catalogue releases and discography begins.',
          });
        }
        if (mbInfo != null && mbInfo.releaseGroupTitles.isNotEmpty) {
          final sampleAlbums = mbInfo.releaseGroupTitles.take(3).join(', ');
          timeline.add({
            'year': 'Discography',
            'title': 'Major Releases',
            'detail': 'Key releases include $sampleAlbums.',
          });
        }
      }

      // 7. Provider IDs
      final providerIds = Map<String, String>.from(base.providerIds);
      if (wikiProfile != null) providerIds['wikidata'] = wikiProfile.qid;
      if (mbInfo != null) providerIds['mbid'] = mbInfo.mbid;

      return base.copyWith(
        biography: bio,
        nativeNames: nativeNames,
        country: wikiProfile?.country ?? mbInfo?.country ?? base.country,
        activeYears: (mbInfo?.activeFrom != null)
            ? '${mbInfo!.activeFrom!.split('-').first}–${mbInfo.activeTo != null ? mbInfo.activeTo!.split('-').first : "present"}'
            : base.activeYears,
        genres: genres,
        collaborators: collaborators,
        relatedArtists: similarArtists,
        timeline: timeline,
        providerIds: providerIds,
        provenance: mbInfo?.provenance ?? wikiProfile?.provenance ?? base.provenance,
      );
    } catch (e) {
      debugPrint('[FederatedMusicIntelligence] Failed to enrich artist ${base.name}: $e');
      return base;
    }
  }

  /// Enriches a track with authentic recording credits, composers, lyricists, ISRC, and story.
  Future<CanonicalTrack> enrichTrack(CanonicalTrack base) async {
    try {
      final creditsInfo = await _musicBrainz.fetchRecordingCredits(base.title, base.artist);
      if (creditsInfo == null) return base;

      final existingCredits = List<CanonicalContributor>.from(base.credits);
      for (final c in creditsInfo.contributors) {
        if (!existingCredits.any((e) => e.name.toLowerCase() == c.name.toLowerCase() && e.role == c.role)) {
          existingCredits.add(c);
        }
      }

      String? composer = base.composer;
      String? lyricist = base.lyricist;

      for (final c in existingCredits) {
        if (composer == null && c.role.toLowerCase() == 'composer') composer = c.name;
        if (lyricist == null && c.role.toLowerCase() == 'lyricist') lyricist = c.name;
      }

      // Generate verified track story
      String? story = base.trackStory;
      if (story == null || story.isEmpty) {
        final buffer = StringBuffer();
        buffer.write('"${base.title}" is a recording performed by ${base.artist}');
        if (base.album.isNotEmpty) buffer.write(' featured on the album "${base.album}"');
        if (creditsInfo.releaseDate != null) buffer.write(' released in ${creditsInfo.releaseDate!.split('-').first}');
        if (composer != null) buffer.write('. Composed by $composer');
        if (lyricist != null) buffer.write(', with lyrics written by $lyricist');
        buffer.write('.');
        story = buffer.toString();
      }

      return base.copyWith(
        isrc: base.isrc ?? creditsInfo.isrc,
        composer: composer,
        lyricist: lyricist,
        credits: existingCredits,
        trackStory: story,
        provenance: creditsInfo.provenance,
      );
    } catch (e) {
      debugPrint('[FederatedMusicIntelligence] Failed to enrich track ${base.title}: $e');
      return base;
    }
  }

  /// Enriches an album with high-resolution archival cover art, story, and release credits.
  Future<CanonicalAlbum> enrichAlbum(CanonicalAlbum base) async {
    try {
      String? cover = base.coverArt;
      if (base.providerIds.containsKey('mbid')) {
        final mbid = base.providerIds['mbid']!;
        final artUrls = await _coverArtArchive.fetchCoverArt(mbid);
        if (artUrls != null) {
          cover = artUrls.displayUrl;
        }
      }

      String? story = base.albumStory;
      if (story == null || story.isEmpty) {
        final buffer = StringBuffer();
        buffer.write('"${base.title}" is a ${base.releaseType.toLowerCase()} by ${base.artist}');
        if (base.year != null) buffer.write(' released in ${base.year}');
        if (base.recordLabel != null && base.recordLabel!.isNotEmpty) buffer.write(' under ${base.recordLabel}');
        if (base.trackCount != null && base.trackCount! > 0) buffer.write(', containing ${base.trackCount} tracks');
        buffer.write('.');
        story = buffer.toString();
      }

      return base.copyWith(
        coverArt: cover,
        albumStory: story,
      );
    } catch (e) {
      debugPrint('[FederatedMusicIntelligence] Failed to enrich album ${base.title}: $e');
      return base;
    }
  }
}
