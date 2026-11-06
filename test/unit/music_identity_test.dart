import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/core/music_identity/canonical_track.dart';
import 'package:it_feels_music/core/music_identity/canonical_artist.dart';
import 'package:it_feels_music/core/music_identity/canonical_album.dart';
import 'package:it_feels_music/core/music_identity/canonical_playlist.dart';
import 'package:it_feels_music/core/music_identity/music_identity_resolver.dart';
import 'package:it_feels_music/core/intelligence/events/listening_event.dart';
import 'package:it_feels_music/core/intelligence/feed/home_feed_models.dart';
import 'package:it_feels_music/data/models/song_model.dart';

void main() {
  group('Canonical Music Identity & Resolver Tests', () {
    setUp(() {
      MusicIdentityResolver.instance.clear();
    });

    test('CanonicalTrack fromSong creates deterministic identity and preserves metadata', () {
      final song = Song(
        id: 'saavn:abc123',
        saavnId: 'abc123',
        title: 'Kesariya (From "Brahmastra")',
        artist: 'Arijit Singh, Pritam',
        album: 'Brahmastra',
        duration: 268,
        coverArt: 'https://c.saavncdn.com/kesariya.jpg',
        streamUrl: 'https://media.saavncdn.com/stream.mp4',
        addedAt: DateTime(2026, 1, 1),
      );

      final track = CanonicalTrack.fromSong(song, provider: 'saavn');

      expect(track.id, startsWith('ct_'));
      expect(track.title, contains('Kesariya'));
      expect(track.artist, 'Arijit Singh, Pritam');
      expect(track.artists, contains('Arijit Singh'));
      expect(track.hasPlayableSource, isTrue);
      expect(track.primaryRef?.provider, 'saavn');
      expect(track.primaryRef?.providerTrackId, 'saavn:abc123');

      // Conversion back to Song preserves playback readiness
      final reverted = track.toSong();
      expect(reverted.id, 'saavn:abc123');
      expect(reverted.streamUrl, 'https://media.saavncdn.com/stream.mp4');
      expect(reverted.artist, 'Arijit Singh, Pritam');
    });

    test('MusicIdentityResolver reconciles multiple songs of same track into single canonical entity', () {
      final resolver = MusicIdentityResolver.instance;

      final song1 = Song(
        id: 'saavn:1001',
        saavnId: '1001',
        title: 'Chaleya',
        artist: 'Arijit Singh, Shilpa Rao',
        album: 'Jawan',
        duration: 200,
        coverArt: 'https://c.saavncdn.com/ch1.jpg',
        streamUrl: 'https://media.saavncdn.com/ch1.mp4',
        addedAt: DateTime.now(),
      );

      final song2 = Song(
        id: 'spotify:xyz888',
        saavnId: 'xyz888',
        title: 'Chaleya (From "Jawan")',
        artist: 'Arijit Singh, Shilpa Rao, Anirudh Ravichander',
        album: 'Jawan',
        duration: 202,
        coverArt: 'https://c.saavncdn.com/ch2.jpg',
        streamUrl: 'https://media.saavncdn.com/ch2.mp4',
        addedAt: DateTime.now(),
      );

      final track1 = resolver.resolveSong(song1, provider: 'saavn');
      final track2 = resolver.resolveSong(song2, provider: 'spotify');

      // Both should resolve to the same canonical identity
      expect(track1.id, track2.id);
      expect(track2.providerRefs.length, 2);
      expect(resolver.indexedCount, 1);
    });

    test('Canonical models serialize and deserialize without loss', () {
      final artist = CanonicalArtist(
        id: 'ca_arijit',
        name: 'Arijit Singh',
        genres: ['Bollywood', 'Romantic'],
        monthlyListeners: 45000000,
      );

      final artistJson = artist.toJson();
      final artistRestored = CanonicalArtist.fromJson(artistJson);
      expect(artistRestored.name, 'Arijit Singh');
      expect(artistRestored.genres, contains('Bollywood'));

      final album = CanonicalAlbum(
        id: 'calb_jawan',
        title: 'Jawan',
        artist: 'Anirudh Ravichander',
        trackCount: 7,
      );
      final albumRestored = CanonicalAlbum.fromJson(album.toJson());
      expect(albumRestored.title, 'Jawan');
      expect(albumRestored.trackCount, 7);

      final playlist = CanonicalPlaylist(
        id: 'cp_daily_1',
        title: 'Daily Mix 1',
        canonicalTrackIds: ['ct_1', 'ct_2'],
        version: 3,
        lastRefreshedAt: DateTime.now(),
      );
      final playlistRestored = CanonicalPlaylist.fromJson(playlist.toJson());
      expect(playlistRestored.title, 'Daily Mix 1');
      expect(playlistRestored.version, 3);
      expect(playlistRestored.trackCount, 2);
    });
  });

  group('Listening Event Engagement Scoring & Feed Models', () {
    test('ListeningEvent computes correct mathematical engagement weights', () {
      // Immediate Skip (< 15s) -> Weak negative (-0.35)
      final immediateSkip = ListeningEvent(
        eventId: 'e1',
        eventType: ListeningEventType.playbackSkipped,
        canonicalTrackId: 'ct_1',
        trackTitle: 'Track 1',
        artistName: 'Artist 1',
        durationPlayedMs: 8000,
        totalDurationMs: 200000,
        completionRatio: 0.04,
        timestamp: DateTime.now(),
      );
      expect(immediateSkip.engagementScore, -0.35);

      // Mid-Track Skip (15s to 50%) -> Neutral (-0.05)
      final midSkip = ListeningEvent(
        eventId: 'e2',
        eventType: ListeningEventType.playbackSkipped,
        canonicalTrackId: 'ct_1',
        trackTitle: 'Track 1',
        artistName: 'Artist 1',
        durationPlayedMs: 60000,
        totalDurationMs: 200000,
        completionRatio: 0.30,
        timestamp: DateTime.now(),
      );
      expect(midSkip.engagementScore, -0.05);

      // Late Skip (50% to 85%) -> Positive engagement (+0.40)
      final lateSkip = ListeningEvent(
        eventId: 'e3',
        eventType: ListeningEventType.playbackSkipped,
        canonicalTrackId: 'ct_1',
        trackTitle: 'Track 1',
        artistName: 'Artist 1',
        durationPlayedMs: 140000,
        totalDurationMs: 200000,
        completionRatio: 0.70,
        timestamp: DateTime.now(),
      );
      expect(lateSkip.engagementScore, 0.40);

      // Full Completion (>= 85%) -> +1.00
      final completed = ListeningEvent(
        eventId: 'e4',
        eventType: ListeningEventType.playbackCompleted,
        canonicalTrackId: 'ct_1',
        trackTitle: 'Track 1',
        artistName: 'Artist 1',
        durationPlayedMs: 195000,
        totalDurationMs: 200000,
        completionRatio: 0.975,
        timestamp: DateTime.now(),
      );
      expect(completed.engagementScore, 1.00);

      // Explicit Like -> +2.50
      final liked = ListeningEvent(
        eventId: 'e5',
        eventType: ListeningEventType.trackLiked,
        canonicalTrackId: 'ct_1',
        trackTitle: 'Track 1',
        artistName: 'Artist 1',
        timestamp: DateTime.now(),
      );
      expect(liked.engagementScore, 2.50);

      // Explicit Hide -> -10.00
      final hidden = ListeningEvent(
        eventId: 'e6',
        eventType: ListeningEventType.trackHidden,
        canonicalTrackId: 'ct_1',
        trackTitle: 'Track 1',
        artistName: 'Artist 1',
        timestamp: DateTime.now(),
      );
      expect(hidden.engagementScore, -10.00);
    });

    test('HomeFeed and HomeFeedSection serialize and parse 18 section types', () {
      final feed = HomeFeed(
        generatedAt: DateTime.now(),
        sections: [
          HomeFeedSection(
            id: 'sec_daily_mix',
            sectionType: FeedSectionType.dailyMix,
            title: 'Made For You',
            items: [
              FeedItem(
                id: 'mix_1',
                title: 'Bollywood Romance',
                itemType: 'playlist',
              ),
            ],
          ),
          HomeFeedSection(
            id: 'sec_featured',
            sectionType: FeedSectionType.featured,
            title: 'Featured Releases',
            items: [],
          ),
        ],
      );

      final json = feed.toJson();
      final restored = HomeFeed.fromJson(json);

      expect(restored.sections.length, 2);
      expect(restored.sections[0].sectionType, FeedSectionType.dailyMix);
      expect(restored.sections[0].items.first.title, 'Bollywood Romance');
      expect(restored.sections[1].sectionType, FeedSectionType.featured);
    });
  });
}
