import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/core/utils/track_validation_engine.dart';
import 'package:it_feels_music/data/models/song_model.dart';

void main() {
  group('TrackValidationEngine Unit Tests', () {
    final originalSong = Song(
      id: 'saavn:123',
      saavnId: '123',
      title: 'Tum Hi Ho',
      artist: 'Arijit Singh, Mithoon',
      album: 'Aashiqui 2',
      duration: 262,
      coverArt: 'https://c.saavncdn.com/123-500x500.jpg',
      addedAt: DateTime.now(),
    );

    final fluteCover = Song(
      id: 'saavn:456',
      saavnId: '456',
      title: 'Tum Hi Ho - Flute Cover Instrumental',
      artist: 'Instrumental Artists',
      album: 'Best Flute Covers',
      duration: 240,
      coverArt: 'https://c.saavncdn.com/456-500x500.jpg',
      addedAt: DateTime.now(),
    );

    final karaokeTrack = Song(
      id: 'saavn:789',
      saavnId: '789',
      title: 'Tum Hi Ho (Karaoke With Female Chorus)',
      artist: 'Karaoke King',
      album: 'Bollywood Karaoke Vol 1',
      duration: 260,
      coverArt: 'https://c.saavncdn.com/789-500x500.jpg',
      addedAt: DateTime.now(),
    );

    final slowedReverbTrack = Song(
      id: 'saavn:101',
      saavnId: '101',
      title: 'Tum Hi Ho (Slowed + Reverb)',
      artist: 'Lofi Chills',
      album: 'Midnight Lofi',
      duration: 310,
      coverArt: 'https://c.saavncdn.com/101-500x500.jpg',
      addedAt: DateTime.now(),
    );

    final ringtoneTrack = Song(
      id: 'saavn:102',
      saavnId: '102',
      title: 'Tum Hi Ho Ringtone Best Part',
      artist: 'Unknown Artist',
      album: 'Ringtones 2024',
      duration: 25,
      coverArt: '',
      addedAt: DateTime.now(),
    );

    test('Prioritizes original vocal recording over instrumental/karaoke when context is standard vocal', () {
      final candidates = [ringtoneTrack, karaokeTrack, fluteCover, slowedReverbTrack, originalSong];
      final ranked = TrackValidationEngine.filterAndRank(
        candidates,
        queryContext: 'Tum Hi Ho',
        expectedArtist: 'Arijit Singh',
      );

      expect(ranked.isNotEmpty, isTrue);
      expect(ranked.first.id, equals(originalSong.id));
      expect(ranked.first.title, equals('Tum Hi Ho'));
    });

    test('Contextual instrumental query permits and elevates instrumental tracks', () {
      final resOriginal = TrackValidationEngine.evaluate(originalSong, queryContext: 'Tum Hi Ho instrumental');
      final resFlute = TrackValidationEngine.evaluate(fluteCover, queryContext: 'Tum Hi Ho instrumental');

      expect(resFlute.isValid, isTrue);
      expect(resFlute.isInstrumental, isTrue);
      expect(resFlute.confidenceScore, greaterThan(resOriginal.confidenceScore));
    });

    test('Penalizes ringtone tracks (< 45s) and invalidates them', () {
      final res = TrackValidationEngine.evaluate(ringtoneTrack, queryContext: 'Tum Hi Ho');
      expect(res.isValid, isFalse);
      expect(res.confidenceScore, lessThan(35.0));
    });

    test('Deduplicates identical recordings in filterAndRank', () {
      final duplicateOriginal = Song(
        id: 'search_duplicate',
        saavnId: '123_alt',
        title: 'Tum Hi Ho (Original Motion Picture Soundtrack)',
        artist: 'Arijit Singh',
        album: 'Aashiqui 2',
        duration: 262,
        coverArt: '',
        addedAt: DateTime.now(),
      );

      final candidates = [originalSong, duplicateOriginal];
      final deduped = TrackValidationEngine.filterAndRank(candidates, queryContext: 'Tum Hi Ho');

      expect(deduped.length, equals(1));
    });

    test('Rejects 8-bit, 16-bit, and chiptune emulation tracks', () {
      final emulationTrack1 = Song(
        id: 'emu:1',
        saavnId: 'emu1',
        title: 'Snowchild (16-Bit The Weeknd Emulation)',
        artist: 'Arcade Player',
        album: 'City of Mirrors',
        duration: 242,
        coverArt: '',
        addedAt: DateTime.now(),
      );

      final emulationTrack2 = Song(
        id: 'emu:2',
        saavnId: 'emu2',
        title: 'Final Lullaby (8-Bit The Weeknd Emulation)',
        artist: '8-Bit Arcade',
        album: 'Chiptune Hits',
        duration: 171,
        coverArt: '',
        addedAt: DateTime.now(),
      );

      final authenticTrack = Song(
        id: 'real:1',
        saavnId: 'real1',
        title: 'Snowchild',
        artist: 'The Weeknd',
        album: 'After Hours',
        duration: 247,
        coverArt: '',
        addedAt: DateTime.now(),
      );

      final res1 = TrackValidationEngine.evaluate(emulationTrack1);
      final res2 = TrackValidationEngine.evaluate(emulationTrack2);
      final resReal = TrackValidationEngine.evaluate(authenticTrack);

      expect(res1.isValid, isFalse);
      expect(res1.confidenceScore, lessThan(35.0));

      expect(res2.isValid, isFalse);
      expect(res2.confidenceScore, lessThan(35.0));

      expect(resReal.isValid, isTrue);
      expect(resReal.confidenceScore, greaterThanOrEqualTo(50.0));
    });

    test('Rejects SEO title-stuffed sound-alike cover tracks', () {
      final seoTrack = Song(
        id: 'seo:1',
        saavnId: 'seo1',
        title: 'Starboy The Weeknd',
        artist: 'Blue Pink',
        album: 'Single',
        duration: 238,
        coverArt: '',
        addedAt: DateTime.now(),
      );

      final res = TrackValidationEngine.evaluate(seoTrack);
      expect(res.isValid, isFalse);
      expect(res.rejectionReason, contains('SEO title-stuffed'));
    });
  });
}
