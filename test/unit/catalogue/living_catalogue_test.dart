import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/intelligence/catalogue/catalogue_deduplication_engine.dart';
import 'package:it_feels_music/core/intelligence/catalogue/mood_genre_intelligence_service.dart';
import 'package:it_feels_music/core/intelligence/catalogue/artwork_repair_service.dart';
import 'package:it_feels_music/core/intelligence/catalogue/content_health_service.dart';
import 'package:it_feels_music/core/intelligence/playlists/daily_mix_orchestrator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Global Track Deduplication & Variant Preservation Tests', () {
    late CatalogueDeduplicationEngine dedup;

    setUp(() {
      dedup = CatalogueDeduplicationEngine();
    });

    test('Consolidates exact duplicate recordings across providers', () {
      final songs = [
        Song(
          id: 'saavn_track_1',
          saavnId: 'saavn_track_1',
          title: 'Kesariya',
          artist: 'Arijit Singh, Pritam',
          album: 'Brahmastra',
          duration: 268,
          coverArt: 'https://c.saavncdn.com/kesariya-500x500.jpg',
          addedAt: DateTime.now(),
        ),
        Song(
          id: 'provider2_track_1',
          saavnId: 'saavn_track_1', // Same provider ID
          title: 'Kesariya (From Brahmastra)',
          artist: 'Arijit Singh, Pritam',
          album: 'Brahmastra',
          duration: 268,
          coverArt: 'https://c.saavncdn.com/kesariya-150x150.jpg',
          addedAt: DateTime.now(),
        ),
        Song(
          id: 'different_track',
          saavnId: 'saavn_track_2',
          title: 'Apna Bana Le',
          artist: 'Arijit Singh, Sachin-Jigar',
          album: 'Bhediya',
          duration: 261,
          coverArt: 'https://c.saavncdn.com/bhediya-500x500.jpg',
          addedAt: DateTime.now(),
        ),
      ];

      final report = dedup.deduplicateTracks(songs);
      expect(report.totalInputCount, 3);
      expect(report.duplicatesRemoved, 1);
      expect(report.uniqueItems.length, 2);
      expect(report.uniqueItems.map((s) => s.id), containsAll(['saavn_track_1', 'different_track']));
    });

    test('Preserves legitimate variants (Remix, Live, Acoustic, Remaster) as distinct entities', () {
      final songs = [
        Song(
          id: 'orig',
          saavnId: 'orig',
          title: 'Tum Hi Ho',
          artist: 'Arijit Singh',
          album: 'Aashiqui 2',
          duration: 262,
          coverArt: 'https://c.saavncdn.com/a2.jpg',
          addedAt: DateTime.now(),
        ),
        Song(
          id: 'remix',
          saavnId: 'remix',
          title: 'Tum Hi Ho (Remix)',
          artist: 'Arijit Singh, DJ Chetas',
          album: 'Aashiqui 2 Remixes',
          duration: 240,
          coverArt: 'https://c.saavncdn.com/a2_remix.jpg',
          addedAt: DateTime.now(),
        ),
        Song(
          id: 'live',
          saavnId: 'live',
          title: 'Tum Hi Ho (Live in Concert)',
          artist: 'Arijit Singh',
          album: 'Live at MTV',
          duration: 310,
          coverArt: 'https://c.saavncdn.com/a2_live.jpg',
          addedAt: DateTime.now(),
        ),
        Song(
          id: 'acoustic',
          saavnId: 'acoustic',
          title: 'Tum Hi Ho (Unplugged Acoustic)',
          artist: 'Arijit Singh',
          album: 'Acoustic Sessions',
          duration: 255,
          coverArt: 'https://c.saavncdn.com/a2_acoustic.jpg',
          addedAt: DateTime.now(),
        ),
      ];

      final report = dedup.deduplicateTracks(songs);
      expect(report.totalInputCount, 4);
      expect(report.duplicatesRemoved, 0, reason: 'Remixes, live and unplugged must NEVER be merged');
      expect(report.uniqueItems.length, 4);
      expect(report.legitimateVariantsPreserved, greaterThanOrEqualTo(1));
    });

    test('Detects and strips duplicate CDN artwork URLs with dynamic resolution stems', () {
      final urls = [
        'https://c.saavncdn.com/152/Song-500x500.jpg',
        'https://c.saavncdn.com/152/Song-150x150.jpg',
        'https://c.saavncdn.com/152/Song-50x50.jpg',
        'https://c.saavncdn.com/830/DifferentSong-500x500.jpg',
      ];

      final deduped = dedup.deduplicateArtworkUrls(urls);
      expect(deduped.length, 2);
      expect(deduped.first, 'https://c.saavncdn.com/152/Song-500x500.jpg');
      expect(deduped.last, 'https://c.saavncdn.com/830/DifferentSong-500x500.jpg');
    });
  });

  group('Mood & Genre Intelligence Tests', () {
    late MoodGenreIntelligenceService moodService;

    setUp(() {
      moodService = MoodGenreIntelligenceService();
    });

    test('Accurately classifies Romantic Bollywood tracks', () {
      final song = Song(
        id: 's1',
        saavnId: 's1',
        title: 'Pyaar Hota Kayi Baar Hai',
        artist: 'Arijit Singh',
        album: 'Tu Jhoothi Main Makkaar',
        duration: 215,
        coverArt: '',
        addedAt: DateTime.now(),
      );

      final classification = moodService.classifySong(song);
      expect(classification.moods, contains(MusicalMood.romantic));
      expect(classification.genres, contains(MusicalGenre.regional));
      expect(classification.confidence, greaterThanOrEqualTo(0.8));
    });

    test('Strictly separates mood from genre categories', () {
      final song = Song(
        id: 's2',
        saavnId: 's2',
        title: 'Club Party Anthem',
        artist: 'Badshah',
        album: 'Desi Hip Hop Hits',
        duration: 180,
        coverArt: '',
        addedAt: DateTime.now(),
      );

      final classification = moodService.classifySong(song);
      // Mood is energetic
      expect(classification.moods, contains(MusicalMood.energetic));
      // Genre is hip-hop
      expect(classification.genres, contains(MusicalGenre.hipHop));
      // Mood is not confused with genre
      expect(classification.genres.contains(MusicalGenre.rock), isFalse);
    });

    test('Provides valid classification for Melancholic / Sad ballads', () {
      final song = Song(
        id: 's3',
        saavnId: 's3',
        title: 'Channa Mereya Heartbreak Ballad',
        artist: 'Arijit Singh',
        album: 'Ae Dil Hai Mushkil',
        duration: 289,
        coverArt: '',
        addedAt: DateTime.now(),
      );

      final classification = moodService.classifySong(song);
      expect(classification.moods, contains(MusicalMood.melancholic));
    });
  });

  group('Artwork Repair & Composite Cover Generation Tests', () {
    late ArtworkRepairService artworkRepair;

    setUp(() {
      artworkRepair = ArtworkRepairService();
    });

    test('Validates authentic artwork URLs and rejects invalid/broken strings', () {
      expect(artworkRepair.isValidArtworkUrl('https://c.saavncdn.com/art.jpg'), isTrue);
      expect(artworkRepair.isValidArtworkUrl('file:///C:/Music/art.jpg'), isTrue);
      expect(artworkRepair.isValidArtworkUrl(''), isFalse);
      expect(artworkRepair.isValidArtworkUrl('null'), isFalse);
      expect(artworkRepair.isValidArtworkUrl('default_artwork'), isFalse);
    });

    test('Generates deterministic Quad-Artwork composite when 4 tracks are available', () {
      final tracks = List.generate(
        4,
        (i) => Song(
          id: 'track_$i',
          saavnId: 'saavn_$i',
          title: 'Track $i',
          artist: 'Artist $i',
          album: 'Album $i',
          duration: 200,
          coverArt: 'https://c.saavncdn.com/art_$i.jpg',
          addedAt: DateTime.now(),
        ),
      );

      final composite = artworkRepair.generatePlaylistCover(
        playlistId: 'daily_mix_test',
        tracks: tracks,
      );

      expect(composite.isQuadComposite, isTrue);
      expect(composite.quadImageUrls.length, 4);
      expect(composite.primaryUrl, 'https://c.saavncdn.com/art_0.jpg');
      expect(composite.isFallback, isFalse);
    });

    test('Provides designed aesthetic fallback when track list is completely empty', () {
      final composite = artworkRepair.generatePlaylistCover(
        playlistId: 'daily_mix_1',
        tracks: [],
      );

      expect(composite.isFallback, isTrue);
      expect(composite.primaryUrl, isNotEmpty);
      expect(composite.primaryUrl.startsWith('http'), isTrue);
    });
  });

  group('Daily Mix Orchestration & Content Completeness Tests', () {
    test('DailyMixOrchestrator contains all 6 stable mix definitions with seed queries', () {
      final defs = DailyMixOrchestrator.definitions;
      expect(defs.length, 6);

      final expectedIds = [
        'daily_mix_1',
        'daily_mix_2',
        'daily_mix_3',
        'daily_mix_4',
        'daily_mix_5',
        'daily_mix_6',
      ];

      for (int i = 0; i < expectedIds.length; i++) {
        expect(defs[i].id, expectedIds[i]);
        expect(defs[i].title, isNotEmpty);
        expect(defs[i].seedQuery, isNotEmpty);
        expect(defs[i].description, isNotEmpty);
      }
    });

    test('getAllMixes returns populated dynamic playlists without empty covers', () {
      final mixes = DailyMixOrchestrator.instance.getAllMixes();
      expect(mixes.length, 6);

      for (final mix in mixes) {
        expect(mix.title, isNotEmpty);
        expect(mix.subtitle, isNotEmpty);
        expect(mix.coverArt, isNotNull);
        expect(mix.coverArt!, isNotEmpty);
        expect(mix.coverArt!.startsWith('http'), isTrue);
      }
    });
  });

  group('Content Health Service Auditing Tests', () {
    late ContentHealthService healthService;

    setUp(() {
      healthService = ContentHealthService();
    });

    test('Audits track collection and computes accurate health score and status', () {
      final healthyTracks = List.generate(
        15,
        (i) => Song(
          id: 'healthy_$i',
          saavnId: 'saavn_$i',
          title: 'Verified Title $i',
          artist: 'Verified Artist $i',
          album: 'Album $i',
          duration: 200,
          coverArt: 'https://c.saavncdn.com/img_$i.jpg',
          addedAt: DateTime.now(),
        ),
      );

      final report = healthService.auditTrackCollection(
        sectionId: 'test_sec',
        sectionName: 'Healthy Section',
        songs: healthyTracks,
        minimumExpectedItems: 10,
      );

      expect(report.status, ContentHealthStatus.healthy);
      expect(report.totalItems, 15);
      expect(report.validItems, 15);
      expect(report.missingArtworkCount, 0);
      expect(report.duplicateCount, 0);
      expect(report.healthScore, greaterThanOrEqualTo(0.88));
    });

    test('Flags incomplete empty collection with degraded/incomplete status', () {
      final report = healthService.auditTrackCollection(
        sectionId: 'empty_sec',
        sectionName: 'Empty Shelf',
        songs: [],
        minimumExpectedItems: 10,
      );

      expect(report.status, ContentHealthStatus.incomplete);
      expect(report.totalItems, 0);
      expect(report.healthScore, 0.0);
      expect(report.identifiedDeficits, contains('Section contains zero tracks'));
    });
  });
}
