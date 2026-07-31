import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:it_feels_music/services/backend_api_service.dart';

void main() {
  group('BackendApiService - Multi-Tier Stream Resolution Engine', () {
    setUp(() {
      // Clear cache before each test
      BackendApiService.clearVideoStreamCache('test_video_id');
      // Set to proxy mode for tests
      BackendApiService.useProxyBackend = true;
    });

    test('Priority 1 (yt-dlp) failover to Priority 2 (Piped API) on 500 Error', () async {
      // Mock HTTP Client
      final mockClient = MockClient((request) async {
        final url = request.url.toString();

        // 1. Mock yt-dlp backend failure (returns 500 instantly)
        if (url.contains('it-feels-android.onrender.com/api/streams')) {
          return http.Response('Server Error', 500);
        }

        // 2. Mock Piped API success (Fallback Priority 2)
        if (url.contains('pipedapi')) {
          return http.Response(
            json.encode({
              'title': 'Test Piped Video',
              'videoStreams': [
                {'url': 'https://piped.video/stream.mp4', 'quality': '1080p', 'mimeType': 'video/mp4', 'videoOnly': false}
              ],
              'audioStreams': [
                {'url': 'https://piped.video/audio.m4a'}
              ]
            }),
            200,
          );
        }

        return http.Response('Not Found', 404);
      });

      // Inject the mock client
      BackendApiService.httpClient = mockClient;

      // Execute stream resolution
      final result = await BackendApiService.getVideoStreams('test_video_id', query: 'test query', bypassCache: true);

      // Verify that it correctly failed over to Piped API and returned the Piped data
      expect(result['title'], equals('Test Piped Video'));
      expect(result['streams'].length, equals(1));
      expect(result['streams'].first['url'], equals('https://piped.video/stream.mp4'));
      expect(result['audioUrl'], equals('https://piped.video/audio.m4a'));
    });

    test('Priority 1 (yt-dlp) success prevents fallback', () async {
      // Mock HTTP Client
      final mockClient = MockClient((request) async {
        final url = request.url.toString();

        // 1. Mock yt-dlp backend success
        if (url.contains('it-feels-android.onrender.com/api/streams')) {
          return http.Response(
            json.encode({
              'title': 'Test 4K Video',
              'streams': [
                {'url': 'https://yt.dlp/4k.mp4', 'quality': '2160p (4K)', 'hasAudio': true}
              ],
              'audioUrl': 'https://yt.dlp/audio.m4a'
            }),
            200,
          );
        }

        // 2. Mock Piped API (should NOT be reached)
        if (url.contains('pipedapi')) {
          return http.Response('Should not be called', 500);
        }

        return http.Response('Not Found', 404);
      });

      BackendApiService.httpClient = mockClient;

      final result = await BackendApiService.getVideoStreams('test_video_id', query: 'test query', bypassCache: true);

      expect(result, isNotEmpty);
      expect(result['title'], isNotNull);
      expect(result['streams'], isNotEmpty);
      expect(result['streams'].length, greaterThanOrEqualTo(1));
    });

    test('11-character YouTube ID formatting', () async {
      // This test ensures that when a Saavn ID with a 'youtube:' prefix is passed,
      // it is correctly cleaned up before hitting the fallback APIs.
      
      final mockClient = MockClient((request) async {
        final url = request.url.toString();
        // The ID should be cleanly extracted to 'dQw4w9WgXcQ'
        if (url.contains('dQw4w9WgXcQ')) {
          return http.Response(
            json.encode({
              'title': 'Rick Roll',
              'videoStreams': [{'url': 'mock_url', 'quality': '1080p'}],
              'audioStreams': []
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      BackendApiService.httpClient = mockClient;
      
      // Temporarily disable yt-dlp to force Piped fallback for this specific test
      final originalYtDlp = BackendApiService.ytDlpBackendUrl;
      BackendApiService.ytDlpBackendUrl = '';

      final result = await BackendApiService.getVideoStreams('youtube:dQw4w9WgXcQ', bypassCache: true);

      expect(result['title'], isNotNull);

      // Restore
      BackendApiService.ytDlpBackendUrl = originalYtDlp;
    });
  });
}
