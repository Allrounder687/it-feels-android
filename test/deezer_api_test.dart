import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:it_feels_music/data/services/deezer_api_service.dart';

class MockClient extends Mock implements http.Client {}

void main() {
  late MockClient mockClient;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    mockClient = MockClient();
    DeezerApiService.httpClient = mockClient;
  });

  test('DeezerApiService getCharts returns tracks and playlists from response', () async {
    final mockResponse = {
      'tracks': {
        'data': [
          {
            'id': 12345,
            'title': 'Test Track',
            'artist': {'name': 'Test Artist'},
            'album': {'title': 'Test Album', 'cover_medium': 'cover_url'},
            'duration': '180',
            'explicit_lyrics': false,
          }
        ]
      },
      'playlists': {
        'data': [
          {
            'id': 54321,
            'title': 'Test Playlist',
            'picture_medium': 'playlist_url',
            'nb_tracks': 10,
            'type': 'playlist',
          }
        ]
      }
    };

    when(() => mockClient.get(
          any(),
          headers: any(named: 'headers'),
        )).thenAnswer((_) async => http.Response(jsonEncode(mockResponse), 200));

    final api = DeezerApiService();
    final charts = await api.getCharts();

    expect(charts['tracks'], isNotEmpty);
    expect(charts['playlists'], isNotEmpty);
    expect(charts['tracks'][0].title, 'Test Track');
    expect(charts['tracks'][0].artist, 'Test Artist');
    expect(charts['playlists'][0].title, 'Test Playlist');
  });
}
