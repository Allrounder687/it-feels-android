import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:it_feels_music/data/services/radio_api_service.dart';

class MockClient extends Mock implements http.Client {}

void main() {
  late MockClient mockClient;
  late RadioApiService radioApiService;

  setUp(() {
    mockClient = MockClient();
    radioApiService = RadioApiService(client: mockClient);
    registerFallbackValue(Uri());
  });

  group('RadioApiService Tests', () {
    test('getTopStations maps json response to Songs list', () async {
      final mockResponseJson = [
        {
          'stationuuid': 'uuid-1234',
          'name': 'Radio Jazz',
          'country': 'USA',
          'tags': 'jazz,classic',
          'favicon': 'favicon.png',
          'url_resolved': 'http://stream.url'
        }
      ];

      when(() => mockClient.get(any())).thenAnswer(
        (_) async => http.Response(json.encode(mockResponseJson), 200),
      );

      final stations = await radioApiService.getTopStations(limit: 1);
      expect(stations, hasLength(1));
      expect(stations.first.id, 'radio:uuid-1234');
      expect(stations.first.title, 'Radio Jazz');
      expect(stations.first.artist, 'USA');
      expect(stations.first.album, 'Live FM');
      expect(stations.first.duration, 0); // live streams
    });

    test('searchStations queries API endpoints and merges results', () async {
      final mockResponseJson = [
        {
          'stationuuid': 'uuid-1',
          'name': 'Rock Radio',
          'country': 'Canada',
          'tags': 'rock',
          'favicon': '',
          'url': 'http://stream2.url'
        }
      ];

      when(() => mockClient.get(any())).thenAnswer(
        (_) async => http.Response(json.encode(mockResponseJson), 200),
      );

      final stations = await radioApiService.searchStations('rock', limit: 1);
      expect(stations, hasLength(1));
      expect(stations.first.id, 'radio:uuid-1');
      expect(stations.first.title, 'Rock Radio');
    });
  });
}
