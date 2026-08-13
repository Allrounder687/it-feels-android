import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/data/models/song_model.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient mockClient;
  late MusicApiService apiService;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    mockClient = MockHttpClient();
    MusicApiService.httpClient = mockClient;
    apiService = MusicApiService();
  });

  tearDown(() {
    MusicApiService.httpClient = http.Client(); // Reset back to default
  });

  group('MusicApiService Autocomplete Search Tests', () {
    test('searchAll returns empty collections for blank query', () async {
      final res = await apiService.searchAll('   ');
      expect(res['songs'], isEmpty);
      expect(res['albums'], isEmpty);
      expect(res['playlists'], isEmpty);
    });

    test('searchAll parses autocomplete json successfully', () async {
      final mockResponse = {
        'songs': {
          'data': [
            {
              'id': 'song_1',
              'title': 'Test Song',
              'more_info': {
                'artistMap': {
                  'primary_artists': [
                    {'name': 'Artist A'}
                  ]
                },
                'album': 'Album A',
                'duration': '180',
                'encrypted_media_url': 'some_base64',
                'has_lyrics': 'true',
                'language': 'english',
                'year': '2024',
                '320kbps': 'true'
              },
              'image': 'https://image.com/150x150.jpg'
            }
          ]
        },
        'albums': {
          'data': [
            {
              'id': 'album_1',
              'title': 'Test Album',
              'image': 'https://image.com/150x150.jpg',
              'perma_url': 'https://saavn.com/album/1'
            }
          ]
        },
        'playlists': {
          'data': [
            {
              'id': 'playlist_1',
              'title': 'Test Playlist',
              'image': 'https://image.com/150x150.jpg',
              'perma_url': 'https://saavn.com/playlist/1'
            }
          ]
        }
      };

      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(json.encode(mockResponse), 200));

      final result = await apiService.searchAll('some query');

      expect(result['songs'], hasLength(1));
      expect(result['albums'], hasLength(1));
      expect(result['playlists'], hasLength(1));

      final Song song = result['songs'][0];
      expect(song.id, equals('saavn:song_1'));
      expect(song.title, equals('Test Song'));
      expect(song.artist, equals('Artist A'));
    });
  });

  group('MusicApiService Details & Cache/Bhakti Filter Tests', () {
    test('fetchPlaylistDetails returns all songs (Bhakti filter removed)', () async {
      final mockPlaylistResponse = {
        'id': 'playlist_123',
        'title': 'Chill Hits',
        'list': [
          {
            'id': 'secular_1',
            'title': 'A Normal Song',
            'more_info': {
              'artistMap': {
                'primary_artists': [
                  {'name': 'Artist A'}
                ]
              },
              'album': 'Normal Album',
              'duration': '200',
              'encrypted_media_url': 'base64_url',
              'has_lyrics': 'false',
              'language': 'english',
              'year': '2024'
            },
            'image': 'https://image.com/150x150.jpg'
          },
          {
            'id': 'bhakti_1',
            'title': 'Hanuman Chalisa Devotional',
            'more_info': {
              'artistMap': {
                'primary_artists': [
                  {'name': 'Singer B'}
                ]
              },
              'album': 'Bhakti Album',
              'duration': '300',
              'encrypted_media_url': 'base64_url',
              'has_lyrics': 'false',
              'language': 'hindi',
              'year': '2020'
            },
            'image': 'https://image.com/150x150.jpg'
          }
        ]
      };

      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(json.encode(mockPlaylistResponse), 200));

      final playlist = await apiService.fetchPlaylistDetails('playlist_123');
      final songsList = playlist['songs'] as List<Song>;

      // Both songs should remain
      expect(songsList, hasLength(2));
      expect(songsList[0].id, equals('saavn:secular_1'));
      expect(songsList[1].id, equals('saavn:bhakti_1'));
    });

    test('fetchPlaylistDetails utilizes cache for subsequent requests', () async {
      final mockPlaylistResponse = {
        'id': 'playlist_123',
        'title': 'Chill Hits',
        'list': []
      };

      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(json.encode(mockPlaylistResponse), 200));

      // Fetch once
      await apiService.fetchPlaylistDetails('playlist_123');
      // Fetch twice
      await apiService.fetchPlaylistDetails('playlist_123');

      // Verify HTTP get was only called exactly ONCE due to caching
      verify(() => mockClient.get(any(), headers: any(named: 'headers'))).called(1);
    });

    test('fetchAlbumDetails processes and extracts album songs successfully', () async {
      final mockAlbumResponse = {
        'id': 'album_789',
        'title': 'Lover',
        'list': [
          {
            'id': 'song_lover',
            'title': 'Cruel Summer',
            'more_info': {
              'artistMap': {
                'primary_artists': [
                  {'name': 'Taylor Swift'}
                ]
              },
              'album': 'Lover',
              'duration': '178',
              'encrypted_media_url': 'enc_url',
              'has_lyrics': 'true',
              'language': 'english',
              'year': '2019'
            },
            'image': 'https://image.com/150x150.jpg'
          }
        ]
      };

      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(json.encode(mockAlbumResponse), 200));

      final album = await apiService.fetchAlbumDetails('album_789');
      final songsList = album['songs'] as List<Song>;

      expect(songsList, hasLength(1));
      expect(songsList[0].title, equals('Cruel Summer'));
    });
  });
}
