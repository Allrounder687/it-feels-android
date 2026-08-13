import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:it_feels_music/core/ai/providers/gemini_provider.dart';
import 'package:it_feels_music/core/ai/providers/chatgpt_provider.dart';
import 'package:it_feels_music/core/ai/providers/claude_provider.dart';
import 'package:it_feels_music/data/models/song_model.dart';

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

void main() {
  late MockHttpClient mockClient;

  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  setUp(() {
    mockClient = MockHttpClient();
  });

  group('GeminiProvider Tests', () {
    test('generatePlaylistFromRequest returns mapped songs on success', () async {
      final provider = GeminiProvider('fake_key', client: mockClient);

      when(() => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => http.Response(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': '```json\n{"playlist": ["Song 1"]}\n```'
                  }
                ]
              }
            }
          ]
        }),
        200,
      ));

      final localLibrary = [
        Song(id: '123', saavnId: '123', title: 'Song 1', artist: 'A', album: 'Al', duration: 100, coverArt: '', addedAt: DateTime.now()),
        Song(id: '456', saavnId: '456', title: 'Song 2', artist: 'B', album: 'Bl', duration: 100, coverArt: '', addedAt: DateTime.now())
      ];

      final result = await provider.generatePlaylistFromRequest(
        userRequest: 'Test request',
        localLibrary: localLibrary,
      );

      expect(result.length, 1);
      expect(result.first.id, '123');
      expect(result.first.title, 'Song 1');
    });
  });

  group('ChatGPTProvider Tests', () {
    test('suggestPlaylistName returns parsed name', () async {
      final provider = ChatGPTProvider('fake_key', client: mockClient);

      when(() => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': '{"suggested_name": "Cool Vibes"}'
              }
            }
          ]
        }),
        200,
      ));

      final result = await provider.suggestPlaylistName(
        initialName: 'Temp',
        songs: [],
      );

      expect(result, 'Cool Vibes');
    });
  });

  group('ClaudeProvider Tests', () {
    test('describePlaylistVibe returns parsed description', () async {
      final provider = ClaudeProvider('fake_key', client: mockClient);

      when(() => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => http.Response(
        jsonEncode({
          'content': [
            {
              'type': 'tool_use',
              'input': {
                'vibe': 'Chill and relaxed.'
              }
            }
          ]
        }),
        200,
      ));

      final result = await provider.describePlaylistVibe(songs: []);

      expect(result, 'Chill and relaxed.');
    });
  });
}
