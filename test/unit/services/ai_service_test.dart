import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:it_feels_music/services/ai_service.dart';
import 'package:it_feels_music/core/ai/ai_provider.dart';
import 'package:it_feels_music/data/models/song_model.dart';

class MockAIProvider extends Mock implements AIProvider {}

void main() {
  late AIService aiService;
  late MockAIProvider mockProvider;

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    aiService = AIService.instance; // It's a singleton, but we can re-initialize it
    mockProvider = MockAIProvider();
    when(() => mockProvider.id).thenReturn('mock_ai');
    when(() => mockProvider.displayName).thenReturn('Mock AI');
  });

  group('AIService Tests', () {
    test('initializes with providers and selects first', () async {
      await aiService.initialize([mockProvider]);
      
      expect(aiService.isInitialized, true);
      expect(aiService.currentProviderId, 'mock_ai');
      expect(aiService.activeProvider, mockProvider);
    });

    test('generatePlaylistFromRequest returns AIResponse successfully', () async {
      await aiService.initialize([mockProvider]);

      final localLibrary = [
        Song(id: '1', saavnId: '1', title: 'Song 1', artist: 'A', album: 'Al', duration: 100, coverArt: '', addedAt: DateTime.now())
      ];

      when(() => mockProvider.generatePlaylistFromRequest(
        userRequest: any(named: 'userRequest'),
        localLibrary: any(named: 'localLibrary'),
        maxResponseTime: any(named: 'maxResponseTime'),
      )).thenAnswer((_) async => localLibrary);

      final response = await aiService.generatePlaylistFromRequest(
        userRequest: 'Play something',
        localLibrary: localLibrary,
      );

      expect(response.success, true);
      expect(response.resultSongs, isNotEmpty);
      expect(response.providerId, 'mock_ai');
    });

    test('describePlaylistVibe handles API failure and locks out provider temporarily', () async {
      await aiService.initialize([mockProvider]);

      when(() => mockProvider.describePlaylistVibe(songs: any(named: 'songs')))
          .thenThrow(Exception('503 Service Unavailable'));

      final response = await aiService.describePlaylistVibe(songs: []);
      
      expect(response.success, false);
      expect(response.error, contains('unavailable')); // Parsed user-facing message

      // The provider should now be temporarily locked out
      expect(aiService.isAvailable, false);
    });
  });
}
