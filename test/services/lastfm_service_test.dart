import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/services/lastfm_service.dart';
import 'package:it_feels_music/data/models/song_model.dart';

class MockClient extends Mock implements http.Client {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockClient mockClient;
  late LastfmService lastfmService;

  final dummySong = Song(
    id: '1',
    saavnId: 'saavn1',
    title: 'Test Title',
    artist: 'Test Artist',
    album: 'Test Album',
    duration: 200,
    coverArt: 'cover.jpg',
    encryptedMediaUrl: 'url',
    addedAt: DateTime.now(),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    mockClient = MockClient();
    lastfmService = LastfmService(
      client: mockClient,
    );
    registerFallbackValue(Uri());
  });

  group('LastfmService Tests', () {
    test('isConfigured is true when keys exist', () {
      expect(lastfmService.isConfigured, isTrue);
    });

    test('authenticate sets preferences on success', () async {
      when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
        (_) async => http.Response(json.encode({
          'name': 'testuser', 'sessionKey': 'testsessionkey'
        }), 200),
      );

      final success = await lastfmService.authenticate('testuser', 'password');
      expect(success, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('lastfm_session_key_v1'), 'testsessionkey');
      expect(prefs.getString('lastfm_username_v1'), 'testuser');
    });

    test('updateNowPlaying sends request if authenticated', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastfm_session_key_v1', 'testsessionkey');

      when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
        (_) async => http.Response('{}', 200),
      );

      await lastfmService.updateNowPlaying(dummySong);

      verify(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
    });

    test('scrobble sends request if authenticated', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastfm_session_key_v1', 'testsessionkey');

      when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
        (_) async => http.Response('{}', 200),
      );

      await lastfmService.scrobble(dummySong, DateTime.now());

      verify(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
    });
  });
}
