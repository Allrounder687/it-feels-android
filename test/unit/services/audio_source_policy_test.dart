import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:it_feels_music/core/utils/audio_source_policy.dart';

void main() {
  test(
    'session-granted audio is checked on the network even with a declared audio MIME',
    () async {
      final denied = MockClient(
        (_) async =>
            http.Response('', 403, headers: {'content-type': 'audio/mp4'}),
      );
      expect(
        await AudioSourcePolicy.probe(
          'https://cdn.example/audio.m4a',
          client: denied,
          verifyNetwork: true,
        ),
        false,
      );
    },
  );
  test('audio URL takes precedence over a mixed video stream', () {
    expect(
      AudioSourcePolicy.select({
        'streamUrl': 'https://cdn.example/video?mime=video%2Fmp4',
        'audioUrl': 'https://cdn.example/audio.m4a',
      }),
      'https://cdn.example/audio.m4a',
    );
  });
  test(
    'a provider returning only video streams cannot fall back to its first video',
    () {
      expect(
        AudioSourcePolicy.select({
          'streams': [
            {
              'url': 'https://cdn.example/video',
              'mimeType': 'video/mp4',
              'quality': '1080p',
            },
          ],
        }),
        isNull,
      );
    },
  );
  test(
    'audio-only MP4 and WebM containers are accepted by MIME, not file extension',
    () async {
      final audio = MockClient(
        (_) async =>
            http.Response('', 206, headers: {'content-type': 'audio/webm'}),
      );
      expect(
        await AudioSourcePolicy.probe(
          'https://cdn.example/container.webm',
          client: audio,
        ),
        true,
      );
      final video = MockClient(
        (_) async =>
            http.Response('', 206, headers: {'content-type': 'video/mp4'}),
      );
      expect(
        await AudioSourcePolicy.probe(
          'https://cdn.example/container.mp4',
          client: video,
        ),
        false,
      );
    },
  );
  test('proxy wrapping cannot hide a declared video MIME', () {
    final wrapped = Uri.https('localhost', '/proxy', {
      'url': 'https://cdn.example/file?mime=video%2Fmp4',
    }).toString();
    expect(AudioSourcePolicy.declaredAudio(wrapped), false);
  });
  test(
    'ambiguous and unavailable sources fail closed for full-mix downloads',
    () async {
      final unknown = MockClient(
        (_) async => http.Response(
          '',
          200,
          headers: {'content-type': 'application/octet-stream'},
        ),
      );
      final denied = MockClient(
        (_) async =>
            http.Response('', 403, headers: {'content-type': 'audio/mpeg'}),
      );
      expect(
        await AudioSourcePolicy.probe(
          'https://cdn.example/file',
          client: unknown,
        ),
        false,
      );
      expect(
        await AudioSourcePolicy.probe(
          'https://cdn.example/file',
          client: denied,
        ),
        false,
      );
    },
  );
}
