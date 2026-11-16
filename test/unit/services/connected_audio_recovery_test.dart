import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/data/services/addon_audio_transport.dart';
import 'package:it_feels_music/data/services/connected_track_audio_resolver.dart';

Song recording(
  String id, {
  String title = 'Shape of You',
  String artist = 'Ed Sheeran',
  int duration = 233,
  String? url,
}) => Song(
  id: id,
  saavnId: '',
  title: title,
  artist: artist,
  album: '',
  duration: duration,
  coverArt: '',
  addedAt: DateTime(2026),
  streamUrl: url,
);

class RecoveryRepository extends MusicRepository {
  int searches = 0;
  final List<Song> candidates;
  RecoveryRepository(this.candidates, Future<String?> Function(Song) resolve)
    : super(addonResolve: resolve);
  @override
  Future<List<Song>> searchSongs(
    String query, {
    int page = 1,
    int count = 20,
  }) async {
    searches++;
    return candidates;
  }
}

void main() {
  test(
    'provider-supplied streamUrl survives JSON mapping and cache round trips',
    () {
      final song = Song.fromJson({
        'id': 'saavn:audio',
        'title': 'Song',
        'artist': 'Artist',
        'streamUrl': 'https://cdn.example/audio.m4a',
      });
      expect(song.streamUrl, 'https://cdn.example/audio.m4a');
      expect(Song.fromJson(song.toJson()).streamUrl, song.streamUrl);
    },
  );
  test('composer-first artist credits still match the credited singer', () {
    expect(
      ConnectedTrackAudioResolver.matches(
        recording(
          'youtube:track',
          title: 'Tum Hi Ho',
          artist: 'Arijit Singh',
          duration: 262,
        ),
        [
          recording(
            'saavn:correct',
            title: 'Tum Hi Ho',
            artist: 'Mithoon, Arijit Singh',
            duration: 262,
          ),
        ],
      ),
      hasLength(1),
    );
  });
  test(
    'expired signed media URLs are not reused from the stream cache',
    () async {
      var calls = 0;
      final repository = RecoveryRepository([], (_) async {
        calls++;
        return 'https://cdn.example/audio.m4a?expire=1';
      });
      final original = recording('youtube:expired');
      await repository.getStreamUrl(original);
      await repository.getStreamUrl(original);
      expect(calls, 2);
    },
  );
  test(
    'a real audio result does not require a redundant success flag',
    () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'audioUrl': 'https://cdn.example/song.m4a'}),
          200,
        ),
      );
      expect(
        await AddonAudioTransport.resolve(
          'https://provider.example/resolve',
          client: client,
        ),
        'https://cdn.example/song.m4a',
      );
    },
  );
  test('nested results and audioStreams are supported', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'data': {
            'audioStreams': [
              {'url': 'https://cdn.example/audio', 'mimeType': 'audio/webm'},
            ],
          },
        }),
        200,
      ),
    );
    expect(
      await AddonAudioTransport.resolve(
        'https://provider.example/resolve',
        client: client,
      ),
      'https://cdn.example/audio',
    );
  });
  test('empty success and explicit failures never become media URLs', () async {
    for (final data in [
      {'success': true, 'streams': []},
      {'success': false, 'audioUrl': 'https://cdn.example/a.m4a'},
    ]) {
      final client = MockClient(
        (_) async => http.Response(jsonEncode(data), 200),
      );
      expect(
        await AddonAudioTransport.resolve(
          'https://provider.example/resolve',
          client: client,
        ),
        isNull,
      );
    }
  });
  test(
    'an extensionless direct audio response is streamed without JSON decoding',
    () async {
      final client = MockClient((request) async {
        expect(request.headers['Range'], 'bytes=0-0');
        return http.Response('', 206, headers: {'content-type': 'audio/webm'});
      });
      expect(
        await AddonAudioTransport.resolve(
          'https://cdn.example/resource',
          client: client,
        ),
        'https://cdn.example/resource',
      );
    },
  );
  test(
    'video containers are rejected even when a muxed stream has audio',
    () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'streams': [
              {
                'url': 'https://cdn.example/video',
                'mimeType': 'video/mp4',
                'videoOnly': false,
              },
            ],
          }),
          200,
        ),
      );
      expect(
        await AddonAudioTransport.resolve(
          'https://provider.example/resolve',
          client: client,
        ),
        isNull,
      );
    },
  );
  test(
    'matching rejects wrong artists, recording variants, and duration mismatches',
    () {
      final original = recording('youtube:video');
      final good = recording('saavn:correct');
      expect(
        ConnectedTrackAudioResolver.matches(original, [
          recording('saavn:wrong', artist: 'Different Singer'),
          recording('saavn:live', title: 'Shape of You (Live)'),
          recording('saavn:duration', duration: 310),
          good,
        ]),
        [good],
      );
    },
  );
  test(
    'official-video title decoration is removed without losing artist checks',
    () {
      final original = recording(
        'youtube:video',
        title: 'Ed Sheeran - Shape of You [Official Music Video]',
        artist: 'Ed Sheeran - Topic',
      );
      expect(
        ConnectedTrackAudioResolver.matches(original, [
          recording('saavn:correct'),
        ]),
        hasLength(1),
      );
    },
  );
  test(
    'a long mix never turns into an unrelated short catalogue recording',
    () async {
      var searches = 0;
      expect(
        await ConnectedTrackAudioResolver.resolve(
          recording('youtube:mix', duration: 3600),
          search: (_) async {
            searches++;
            return [];
          },
          resolveCandidate: (_) async => null,
        ),
        isNull,
      );
      expect(searches, 0);
    },
  );
  test(
    'play and download share one resolution and recover from empty original streams',
    () async {
      var calls = 0;
      final gate = Completer<void>();
      final repository = RecoveryRepository(
        [recording('saavn:correct', url: 'https://cdn.example/song.m4a')],
        (_) async {
          calls++;
          await gate.future;
          return null;
        },
      );
      final original = recording('youtube:video');
      final play = repository.getStreamUrl(original);
      final download = repository.getStreamUrl(original);
      gate.complete();
      expect(await play, 'https://cdn.example/song.m4a');
      expect(await download, 'https://cdn.example/song.m4a');
      expect(calls, 1);
      expect(repository.searches, 1);
      expect(
        await repository.getStreamUrl(original),
        'https://cdn.example/song.m4a',
      );
      expect(calls, 1);
    },
  );
  test(
    'Spotify/YouTube metadata survives persistence without a fabricated Saavn ID',
    () {
      for (final id in ['spotify:track', 'youtube:video']) {
        final restored = Song.fromJson(recording(id).toJson());
        expect(restored.id, id);
        expect(restored.saavnId, isEmpty);
      }
    },
  );
}
