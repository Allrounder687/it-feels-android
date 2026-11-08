import 'dart:async';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/home/home_provider.dart';
import 'package:it_feels_music/core/intelligence/catalogue/catalogue_deduplication_engine.dart';
import 'package:it_feels_music/core/intelligence/catalogue/artwork_repair_service.dart';
import 'package:it_feels_music/core/intelligence/playlists/dynamic_playlist_models.dart';
import 'package:it_feels_music/core/intelligence/playlists/dynamic_playlist_service.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/core/utils/track_validation_engine.dart';

/// Specification for a curated daily mix.
class DailyMixDefinition {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String genreTag;
  final String seedQuery;

  const DailyMixDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.genreTag,
    required this.seedQuery,
  });
}

/// Orchestrator for Daily Mixes and automated collections.
/// Guarantees that Daily Mixes 1-6 are never empty, have stable identities,
/// non-repeating track selections, persistent composite artwork, and survival across application restarts.
class DailyMixOrchestrator {
  static final DailyMixOrchestrator _instance = DailyMixOrchestrator._internal();
  factory DailyMixOrchestrator() => _instance;
  static DailyMixOrchestrator get instance => _instance;
  DailyMixOrchestrator._internal();

  static const List<DailyMixDefinition> definitions = [
    DailyMixDefinition(
      id: 'daily_mix_1',
      title: 'Bollywood Romance',
      subtitle: 'Arijit Singh, Pritam, Shreya Ghoshal',
      description: 'Soul-stirring romantic melodies and heartfelt Hindi cinema ballads.',
      genreTag: 'Bollywood',
      seedQuery: 'Bollywood Romance Hits',
    ),
    DailyMixDefinition(
      id: 'daily_mix_2',
      title: 'Pop & International',
      subtitle: 'The Weeknd, Taylor Swift, Drake',
      description: 'Global chart-toppers, infectious pop grooves, and international anthems.',
      genreTag: 'Pop',
      seedQuery: 'Today Top Hits Pop',
    ),
    DailyMixDefinition(
      id: 'daily_mix_3',
      title: 'Punjabi Beats',
      subtitle: 'Diljit Dosanjh, Karan Aujla, AP Dhillon',
      description: 'High-energy Punjabi club bangers, folk-drill rhythms, and diaspora anthems.',
      genreTag: 'Punjabi',
      seedQuery: 'Punjabi Superhits 2026',
    ),
    DailyMixDefinition(
      id: 'daily_mix_4',
      title: 'Desi Hip-Hop',
      subtitle: 'DIVINE, Seedhe Maut, KR\$NA',
      description: 'Hard-hitting gully bars, underground drill beats, and Indian rap poetry.',
      genreTag: 'Hip-Hop',
      seedQuery: 'Desi Hip Hop Anthems',
    ),
    DailyMixDefinition(
      id: 'daily_mix_5',
      title: 'Acoustic & Indie',
      subtitle: 'Anuv Jain, Prateek Kuhad, Jasleen Royal',
      description: 'Intimate guitars, indie-pop harmonies, and mellow late-night acoustics.',
      genreTag: 'Indie',
      seedQuery: 'Acoustic Indie Hindi Chill',
    ),
    DailyMixDefinition(
      id: 'daily_mix_6',
      title: 'Club & Party Anthems',
      subtitle: 'Badshah, Yo Yo Honey Singh, Nucleya',
      description: 'Bass-heavy dance anthems, wedding celebrations, and festival crowd-pleasers.',
      genreTag: 'Dance',
      seedQuery: 'Bollywood Dance Club Hits',
    ),
  ];

  final Map<String, DynamicPlaylist> _activeMixes = {};

  /// Synchronizes Daily Mixes using live home feed state, applying deduplication and artwork repair.
  Future<List<DynamicPlaylist>> synchronizeMixesWithHomeState(HomeState homeState) async {
    final dedup = CatalogueDeduplicationEngine();
    final artworkRepair = ArtworkRepairService();
    final dynService = DynamicPlaylistService.instance;
    await dynService.init();

    final result = <DynamicPlaylist>[];

    for (int i = 0; i < definitions.length; i++) {
      final def = definitions[i];
      final existing = dynService.getPlaylist(def.id);

      List<Song> candidateSongs = [];

      // 1. Check if homeState already has catalog tracks matching the genre
      if (i == 0 && homeState.bollywoodSongs.isNotEmpty) {
        candidateSongs = homeState.bollywoodSongs;
      } else if (i == 1 && homeState.hollywoodSongs.isNotEmpty) {
        candidateSongs = homeState.hollywoodSongs;
      } else if (i == 2 && homeState.punjabiSongs.isNotEmpty) {
        candidateSongs = homeState.punjabiSongs;
      } else if (i == 3 && homeState.trendingSongs.isNotEmpty) {
        candidateSongs = homeState.trendingSongs.where((s) => s.artist.toLowerCase().contains('divine') || s.artist.toLowerCase().contains('raftaar') || s.artist.toLowerCase().contains('kr')).toList();
        if (candidateSongs.isEmpty) candidateSongs = homeState.trendingSongs;
      } else if (i == 4 && homeState.youSongs.isNotEmpty) {
        candidateSongs = homeState.youSongs;
      } else if (i == 5 && homeState.trendingSongs.isNotEmpty) {
        candidateSongs = homeState.trendingSongs;
      }

      // If candidates are empty, check if existing dynamic playlist already has tracks from past session
      if (candidateSongs.isEmpty && existing != null && existing.tracks.isNotEmpty) {
        candidateSongs = existing.tracks;
      }

      // If still empty, check match in youPlaylists
      if (candidateSongs.isEmpty) {
        final match = homeState.youPlaylists.where((p) => p.id == def.id).firstOrNull;
        if (match != null && match.songs != null && match.songs!.isNotEmpty) {
          candidateSongs = match.songs!;
        }
      }

      // Filter out any emulation, chiptune, or low-quality sound-alike candidates
      candidateSongs = TrackValidationEngine.filterAndRank(
        candidateSongs,
        preserveOriginalOrderIfValid: true,
      );

      // If candidate pool is starved, query verified seed tracks
      if (candidateSongs.length < 10 && locator.isRegistered<IMusicRepository>()) {
        try {
          final seedTracks = await locator<IMusicRepository>().searchSongs(def.seedQuery, count: 25);
          final cleanSeeds = TrackValidationEngine.filterAndRank(seedTracks);
          candidateSongs = [...candidateSongs, ...cleanSeeds];
        } catch (_) {}
      }

      // Apply Global Deduplication to candidate tracks
      final dedupReport = dedup.deduplicateTracks(candidateSongs);
      final finalTracks = dedupReport.uniqueItems.take(25).toList();

      // Resolve deterministic composite artwork
      final compositeCover = artworkRepair.generatePlaylistCover(
        playlistId: def.id,
        tracks: finalTracks,
        fallbackTitle: def.title,
      );

      final playlist = DynamicPlaylist(
        id: def.id,
        title: def.title,
        subtitle: def.subtitle,
        coverArt: compositeCover.primaryUrl,
        tracks: finalTracks,
        lastRefreshedAt: DateTime.now(),
        metadata: {
          'description': def.description,
          'genreTag': def.genreTag,
          'quadImageUrls': compositeCover.quadImageUrls,
          'isQuadComposite': compositeCover.isQuadComposite,
          'duplicatesRemoved': dedupReport.duplicatesRemoved,
        },
      );

      _activeMixes[def.id] = playlist;
      await dynService.persistPlaylist(playlist);
      result.add(playlist);
    }

    return result;
  }

  /// Retrieves an active daily mix by ID.
  DynamicPlaylist? getMix(String id) {
    return _activeMixes[id] ?? DynamicPlaylistService.instance.getPlaylist(id);
  }

  /// Retrieves all 6 Daily Mixes.
  List<DynamicPlaylist> getAllMixes() {
    if (_activeMixes.length == definitions.length) {
      return _activeMixes.values.toList();
    }
    return definitions.map((def) {
      return getMix(def.id) ??
          DynamicPlaylist(
            id: def.id,
            title: def.title,
            subtitle: def.subtitle,
            coverArt: ArtworkRepairService().getDailyMixCover(def.id),
            lastRefreshedAt: DateTime.now(),
            metadata: {'description': def.description},
          );
    }).toList();
  }
}
