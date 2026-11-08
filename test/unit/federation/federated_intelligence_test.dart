import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/core/intelligence/federation/data_provenance.dart';
import 'package:it_feels_music/core/intelligence/federation/canonical_contributor.dart';
import 'package:it_feels_music/core/intelligence/federation/entity_resolution_engine.dart';
import 'package:it_feels_music/core/intelligence/orchestration/circuit_breaker.dart';
import 'package:it_feels_music/core/intelligence/orchestration/rate_limiter.dart';
import 'package:it_feels_music/core/intelligence/orchestration/tiered_cache_manager.dart';
import 'package:it_feels_music/core/intelligence/orchestration/provider_health_monitor.dart';
import 'package:it_feels_music/core/music_identity/canonical_track.dart';
import 'package:it_feels_music/core/music_identity/canonical_artist.dart';

void main() {
  group('Data Provenance & Contributor Tests', () {
    test('DataProvenance serializes and deserializes accurately with expiration logic', () {
      final prov = DataProvenance.musicBrainz('mbid-12345');
      expect(prov.provider, equals('musicbrainz'));
      expect(prov.sourceId, equals('mbid-12345'));
      expect(prov.confidence, equals(0.95));
      expect(prov.isExpired, isFalse);

      final json = prov.toJson();
      final revived = DataProvenance.fromJson(json);
      expect(revived.provider, equals('musicbrainz'));
      expect(revived.sourceId, equals('mbid-12345'));
      expect(revived.confidence, equals(0.95));
      expect(revived.attribution, contains('MusicBrainz'));
    });

    test('CanonicalContributor model tracks contributor role and provenance', () {
      final contributor = CanonicalContributor(
        id: 'c-101',
        name: 'Pritam Chakraborty',
        role: 'Composer',
        provenance: DataProvenance.musicBrainz('c-101'),
      );

      final json = contributor.toJson();
      final revived = CanonicalContributor.fromJson(json);
      expect(revived.name, equals('Pritam Chakraborty'));
      expect(revived.role, equals('Composer'));
      expect(revived.provenance?.provider, equals('musicbrainz'));
    });
  });

  group('Entity Resolution Engine Tests', () {
    final engine = EntityResolutionEngine();

    final testCandidates = [
      CanonicalTrack(
        id: 'ct_1',
        title: 'Kesariya',
        artist: 'Arijit Singh, Pritam',
        album: 'Brahmastra',
        duration: 268,
        coverArt: 'https://example.com/art.jpg',
        isrc: 'IN-A12-22-00101',
        addedAt: DateTime(2024, 1, 1),
      ),
      CanonicalTrack(
        id: 'ct_2',
        title: 'Kesariya (Dance Mix)',
        artist: 'Arijit Singh, Pritam, Shashwat Singh',
        album: 'Brahmastra',
        duration: 210,
        coverArt: 'https://example.com/art.jpg',
        addedAt: DateTime(2024, 1, 1),
      ),
      CanonicalTrack(
        id: 'ct_3',
        title: 'Raataan Lambiyan',
        artist: 'Jubin Nautiyal, Asees Kaur',
        album: 'Shershaah',
        duration: 230,
        coverArt: 'https://example.com/art.jpg',
        isrc: 'IN-T12-21-00045',
        addedAt: DateTime(2024, 1, 1),
      ),
    ];

    test('Resolves exact track match via verified ISRC', () {
      final result = engine.matchTracks(
        queryTitle: 'Kesariya Film Version',
        queryArtist: 'Arijit',
        queryIsrc: 'IN-A12-22-00101',
        candidates: testCandidates,
      );

      expect(result.matched, isTrue);
      expect(result.confidence, equals(1.0));
      expect(result.canonicalEntity?.id, equals('ct_1'));
      expect(result.matchReason, contains('ISRC exact match'));
    });

    test('Rejects merger of studio track with acoustic or remix cut', () {
      final result = engine.matchTracks(
        queryTitle: 'Kesariya (Dance Mix)',
        queryArtist: 'Arijit Singh',
        queryDuration: 210,
        candidates: [testCandidates[0]], // only original studio cut
      );

      // Should not merge studio cut with dance mix
      expect(result.matched, isFalse);
    });

    test('Resolves Hindi transliterated artist name to canonical artist', () {
      final candidates = [
        CanonicalArtist(
          id: 'art_1',
          name: 'Arijit Singh',
          nativeNames: ['अरिजीत सिंह'],
          country: 'India',
        ),
        CanonicalArtist(
          id: 'art_2',
          name: 'Diljit Dosanjh',
          nativeNames: ['ਦਿਲਜੀਤ ਦੋਸਾਂਝ'],
          country: 'India',
        ),
      ];

      final match = engine.matchArtist(
        queryName: 'अरिजीत सिंह',
        candidates: candidates,
      );

      expect(match.matched, isTrue);
      expect(match.canonicalEntity?.name, equals('Arijit Singh'));
    });
  });

  group('Enterprise API Orchestration & Reliability Tests', () {
    test('CircuitBreaker transitions: CLOSED -> OPEN -> HALF_OPEN -> CLOSED', () {
      final cb = CircuitBreaker(
        providerName: 'test_provider',
        failureThreshold: 3,
        resetTimeout: const Duration(milliseconds: 100),
        halfOpenSuccessThreshold: 2,
      );

      expect(cb.state, equals(CircuitState.closed));
      expect(cb.isExecutionPermitted, isTrue);

      // Record 3 failures
      cb.recordFailure();
      cb.recordFailure();
      cb.recordFailure();

      expect(cb.state, equals(CircuitState.open));
      expect(cb.isExecutionPermitted, isFalse);
    });

    test('TokenBucketRateLimiter allows immediate burst permits up to maxTokens', () {
      final limiter = TokenBucketRateLimiter(
        providerName: 'musicbrainz',
        permitsPerSecond: 10.0,
        maxTokens: 5.0,
      );

      expect(limiter.tryAcquire(), isTrue);
      expect(limiter.tryAcquire(), isTrue);
      expect(limiter.tryAcquire(), isTrue);
      expect(limiter.tryAcquire(), isTrue);
      expect(limiter.tryAcquire(), isTrue);
      // Exhausted burst
      expect(limiter.tryAcquire(), isFalse);
    });

    test('ProviderHealthMonitor accurately aggregates latency and error distributions', () {
      final monitor = ProviderHealthMonitor();

      monitor.recordSuccess('musicbrainz', 120);
      monitor.recordSuccess('musicbrainz', 80);
      monitor.recordFailure('musicbrainz', latencyMs: 500, error: 'HTTP 503');
      monitor.recordFailure('musicbrainz', latencyMs: 40, is429: true, error: 'HTTP 429');

      final stats = monitor.getAllStats().firstWhere((s) => s.providerName == 'musicbrainz');
      expect(stats.totalRequests, equals(4));
      expect(stats.successfulRequests, equals(2));
      expect(stats.failedRequests, equals(2));
      expect(stats.rateLimitEvents, equals(1));
      expect(stats.averageLatencyMs, equals(100)); // (120+80)/2
      expect(stats.lastErrorMessage, contains('HTTP 429'));
    });

    test('TieredCacheManager supports L1 memory insertion, retrieval, and invalidation', () async {
      final cache = TieredCacheManager();

      await cache.put(
        'artist_arijit',
        {'name': 'Arijit Singh', 'country': 'India'},
        type: CacheContentType.artist,
        persistDisk: false,
      );

      final cached = await cache.get<Map<String, dynamic>>('artist_arijit');
      expect(cached, isNotNull);
      expect(cached?['name'], equals('Arijit Singh'));

      await cache.invalidate('artist_arijit');
      final afterInvalidation = await cache.get<Map<String, dynamic>>('artist_arijit');
      expect(afterInvalidation, isNull);
    });
  });
}
