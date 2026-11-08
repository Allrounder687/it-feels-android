import 'dart:async';
import '../orchestration/enterprise_api_orchestrator.dart';
import '../orchestration/tiered_cache_manager.dart';
import 'data_provenance.dart';

class WikidataArtistProfile {
  final String qid;
  final String label;
  final String? description;
  final String? country;
  final String? birthDate;
  final List<String> nativeLabels;
  final String? officialWebsite;
  final DataProvenance provenance;

  WikidataArtistProfile({
    required this.qid,
    required this.label,
    this.description,
    this.country,
    this.birthDate,
    this.nativeLabels = const [],
    this.officialWebsite,
    required this.provenance,
  });
}

/// Encyclopedic artist intelligence adapter powered by the Wikidata open knowledge base.
class WikidataAdapter {
  final EnterpriseApiOrchestrator _orchestrator;

  WikidataAdapter({EnterpriseApiOrchestrator? orchestrator})
      : _orchestrator = orchestrator ?? EnterpriseApiOrchestrator();

  /// Searches Wikidata for an artist QID and extracts encyclopedic profile data.
  Future<WikidataArtistProfile?> fetchArtistProfile(String artistName) async {
    final clean = Uri.encodeComponent(artistName);
    final searchUrl = 'https://www.wikidata.org/w/api.php?action=wbsearchentities&search=$clean&language=en&format=json&limit=1';

    final searchJson = await _orchestrator.getJson(
      provider: 'wikidata',
      url: searchUrl,
      cacheType: CacheContentType.artist,
    );

    if (searchJson == null || searchJson['search'] == null) return null;
    final results = searchJson['search'] as List;
    if (results.isEmpty) return null;

    final first = results.first as Map<String, dynamic>;
    final qid = first['id']?.toString() ?? '';
    if (qid.isEmpty) return null;

    final description = first['description']?.toString();

    // Fetch entity claims and multi-lingual labels (Hindi, English)
    final detailUrl = 'https://www.wikidata.org/w/api.php?action=wbgetentities&ids=$qid&props=labels|descriptions|claims&languages=en|hi|bn|pa|ta|te&format=json';
    final detailJson = await _orchestrator.getJson(
      provider: 'wikidata',
      url: detailUrl,
      cacheType: CacheContentType.artist,
      customTtl: const Duration(days: 30),
    );

    final nativeLabels = <String>[];
    String? birthDate;
    String? country;
    String? officialSite;

    if (detailJson != null && detailJson['entities'] != null) {
      final entity = (detailJson['entities'] as Map<String, dynamic>)[qid] as Map<String, dynamic>?;
      if (entity != null) {
        // Collect native names from Hindi, Bengali, Punjabi, Tamil, Telugu
        final labels = entity['labels'] as Map<String, dynamic>?;
        if (labels != null) {
          for (final lang in ['hi', 'bn', 'pa', 'ta', 'te']) {
            final val = labels[lang]?['value']?.toString();
            if (val != null && val.isNotEmpty && !nativeLabels.contains(val)) {
              nativeLabels.add(val);
            }
          }
        }

        final claims = entity['claims'] as Map<String, dynamic>?;
        if (claims != null) {
          // P569: Date of birth
          if (claims['P569'] is List && (claims['P569'] as List).isNotEmpty) {
            final timeVal = claims['P569'][0]?['mainsnak']?['datavalue']?['value']?['time']?.toString();
            if (timeVal != null) {
              birthDate = timeVal.replaceAll('+', '').split('T').first;
            }
          }

          // P27: Country of citizenship (Q668 = India)
          if (claims['P27'] is List && (claims['P27'] as List).isNotEmpty) {
            final countryQid = claims['P27'][0]?['mainsnak']?['datavalue']?['value']?['id']?.toString();
            if (countryQid == 'Q668') {
              country = 'India';
            } else if (countryQid == 'Q30') {
              country = 'United States';
            } else if (countryQid == 'Q145') {
              country = 'United Kingdom';
            } else if (countryQid == 'Q843') {
              country = 'Pakistan';
            }
          }

          // P856: Official website
          if (claims['P856'] is List && (claims['P856'] as List).isNotEmpty) {
            officialSite = claims['P856'][0]?['mainsnak']?['datavalue']?['value']?.toString();
          }
        }
      }
    }

    return WikidataArtistProfile(
      qid: qid,
      label: first['label']?.toString() ?? artistName,
      description: description,
      country: country,
      birthDate: birthDate,
      nativeLabels: nativeLabels,
      officialWebsite: officialSite,
      provenance: DataProvenance.wikidata(qid),
    );
  }
}
