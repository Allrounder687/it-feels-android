import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/core/intelligence/ai/ai_discovery_orchestrator.dart';

void main() {
  group('AIDiscoveryOrchestrator Tests', () {
    final orchestrator = AIDiscoveryOrchestrator();

    test('extracts structured constraints from natural language prompt', () {
      const prompt = 'Late night romantic Bollywood songs with Arijit Singh and acoustic vibe';
      final constraints = orchestrator.extractConstraints(prompt);

      expect(constraints.genres, contains('Bollywood'));
      expect(constraints.genres, contains('Acoustic'));
      expect(constraints.moods, contains('Late Night'));
      expect(constraints.moods, contains('Romantic'));
      expect(constraints.targetArtists, contains('Arijit Singh'));
      expect(constraints.suggestedTitle, isNotEmpty);
      expect(constraints.searchKeywords, isNotEmpty);
    });

    test('extracts era and tempo correctly', () {
      const prompt = 'Fast high energy Punjabi workout tracks from 90s';
      final constraints = orchestrator.extractConstraints(prompt);

      expect(constraints.genres, contains('Punjabi'));
      expect(constraints.tempo, 'fast');
      expect(constraints.era, '90s');
      expect(constraints.moods, contains('High Energy'));
    });

    test('generates graceful fallback title and keywords for abstract prompts', () {
      const prompt = 'Rainy day coffee in Paris';
      final constraints = orchestrator.extractConstraints(prompt);

      expect(constraints.suggestedTitle, isNotEmpty);
      expect(constraints.searchKeywords, contains('Rainy day coffee in Paris'));
    });
  });
}
