import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/data/services/stream_resolver.dart';

void main() {
  group('StreamResolver Match Scoring', () {
    test('normalizeString strips suffixes and parenthesis correctly', () {
      expect(StreamResolver.normalizeString('Song Title (Remastered 2024)'), 'song title');
      expect(StreamResolver.normalizeString('Song Title [Live at Wembley]'), 'song title');
      expect(StreamResolver.normalizeString('Song Title feat. Artist B'), 'song title');
      expect(StreamResolver.normalizeString('Song Title ft. Artist C'), 'song title');
      expect(StreamResolver.normalizeString('Song Title - Remastered'), 'song title -'); // We strip 'remastered.*', so 'song title - ' is left.
      expect(StreamResolver.normalizeString('Perfect (Duet with Beyoncé)'), 'perfect');
    });

    test('Match scoring logic evaluation', () {
      // Simulate the logic in _resolveSpotifyCascade
      final targetTitle = 'Perfect';
      final targetArtists = ['ed sheeran'];
      final targetDurationMs = 263000;

      final cleanTargetTitle = StreamResolver.normalizeString(targetTitle);

      // Candidate 1: Perfect match
      final candidate1Title = StreamResolver.normalizeString('Perfect');
      final candidate1Artists = ['ed sheeran'];
      final candidate1Duration = 263000;

      bool titleMatch1 = candidate1Title == cleanTargetTitle || candidate1Title.contains(cleanTargetTitle) || cleanTargetTitle.contains(candidate1Title);
      bool artistMatch1 = targetArtists.any((ta) => candidate1Artists.any((ca) => ca.contains(ta) || ta.contains(ca)));
      bool durationMatch1 = (candidate1Duration - targetDurationMs).abs() <= 15000;

      expect(titleMatch1 && artistMatch1 && durationMatch1, true);

      // Candidate 2: Title has extra text but should pass normalizeString
      final candidate2Title = StreamResolver.normalizeString('Perfect (Acoustic)');
      bool titleMatch2 = candidate2Title == cleanTargetTitle || candidate2Title.contains(cleanTargetTitle) || cleanTargetTitle.contains(candidate2Title);
      expect(titleMatch2, true);

      // Candidate 3: Duration mismatch
      final candidate3Duration = 300000; // >15s difference
      bool durationMatch3 = (candidate3Duration - targetDurationMs).abs() <= 15000;
      expect(durationMatch3, false);

      // Candidate 4: Artist overlap
      final candidate4Artists = ['ed sheeran', 'beyonce'];
      bool artistMatch4 = targetArtists.any((ta) => candidate4Artists.any((ca) => ca.contains(ta) || ta.contains(ca)));
      expect(artistMatch4, true);
    });
  });
}
