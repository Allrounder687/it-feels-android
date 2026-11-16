import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/models/mix_chapter.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/features/connected_music/connected_music_models.dart';
import 'package:it_feels_music/features/connected_music/connected_music_service.dart';
import 'package:it_feels_music/features/discovery/discovery_feed_service.dart';
import 'package:it_feels_music/features/discovery/mix_chapter_service.dart';

class Repo extends Mock implements IMusicRepository {}

class PublicFeed implements PublicPlaylistGateway {
  int calls = 0;
  @override
  Stream<AccountSnapshot> discover(AccountAddon addon) async* {
    calls++;
    yield AccountSnapshot(
      complete: true,
      playlists: [
        RemotePlaylist(
          providerId: addon.id,
          id: 'public',
          title: 'Public curated collection',
          url: '${addon.origin}/playlist?list=public',
          requiresAccount: false,
        ),
      ],
    );
  }
}

Song track(String id, {String? title, String? artist, int duration = 180}) =>
    Song(
      id: id,
      saavnId: '',
      title: title ?? 'Recording $id',
      artist: artist ?? 'Artist $id',
      album: 'Album',
      duration: duration,
      coverArt: '',
      addedAt: DateTime(2026),
    );
void main() {
  setUpAll(() => registerFallbackValue(track('fallback')));
  late Repo repo;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = Repo();
    when(
      () => repo.searchPlaylists(any(), count: any(named: 'count')),
    ).thenAnswer(
      (call) async => [
        Playlist(
          id: call.positionalArguments.first as String,
          title: '${call.positionalArguments.first} collection',
          songCount: 50,
        ),
      ],
    );
    when(() => repo.searchSongs(any(), count: any(named: 'count'))).thenAnswer(
      (call) async => List.generate(
        8,
        (i) => track('${call.positionalArguments.first}:$i'),
      ),
    );
  });
  test(
    'a completely new listener gets six varied real-provider shelves and a sampler',
    () async {
      final feed = DiscoveryFeedService(repo);
      addTearDown(feed.dispose);
      await feed.refresh();
      expect(
        feed.picks.map((p) => p.category).toSet(),
        DiscoveryFeedService.categories.toSet(),
      );
      expect(feed.sampler, isNotEmpty);
      expect(feed.loading, false);
      expect(feed.message, isNull);
    },
  );
  test(
    'public YouTube playlists are usable without an account or saved library',
    () async {
      final gateway = PublicFeed();
      final feed = DiscoveryFeedService(repo, publicGateway: gateway);
      addTearDown(feed.dispose);
      await feed.refresh();
      expect(
        feed.picks
            .where((p) => p.remote != null)
            .single
            .remote!
            .requiresAccount,
        false,
      );
      expect(gateway.calls, 1);
    },
  );
  test(
    'parallel discovery refreshes coalesce and fresh cached shelves avoid refetch',
    () async {
      final feed = DiscoveryFeedService(repo);
      addTearDown(feed.dispose);
      await Future.wait([feed.refresh(), feed.refresh(), feed.refresh()]);
      await feed.refresh();
      verify(
        () => repo.searchPlaylists(any(), count: any(named: 'count')),
      ).called(6);
    },
  );
  test(
    'cold-start snapshot survives an offline refresh without an empty replacement',
    () async {
      final feed = DiscoveryFeedService(repo);
      await feed.refresh();
      final count = feed.picks.length;
      feed.dispose();
      when(
        () => repo.searchPlaylists(any(), count: any(named: 'count')),
      ).thenThrow(Exception('offline'));
      when(
        () => repo.searchSongs(any(), count: any(named: 'count')),
      ).thenThrow(Exception('offline'));
      final offline = DiscoveryFeedService(repo);
      addTearDown(offline.dispose);
      await offline.refresh(force: true);
      expect(offline.picks.length, count);
      expect(offline.sampler, isNotEmpty);
      expect(offline.message, contains('last discoveries'));
    },
  );
  test(
    'album search results and emulation playlists are not presented as curated playlists',
    () async {
      when(
        () => repo.searchPlaylists(any(), count: any(named: 'count')),
      ).thenAnswer(
        (_) async => [
          Playlist(
            id: 'album',
            title: 'An album',
            type: 'album',
            songCount: 10,
          ),
          Playlist(
            id: 'spam',
            title: '16-bit emulation collection',
            songCount: 40,
          ),
          Playlist(id: 'real', title: 'A real playlist', songCount: 40),
        ],
      );
      final feed = DiscoveryFeedService(repo);
      addTearDown(feed.dispose);
      await feed.refresh();
      expect(feed.picks.map((p) => p.catalogue!.id), ['real']);
    },
  );
  test(
    'sampler interleaves genres, removes duplicate IDs and caps artist concentration',
    () {
      final songs = DiscoveryFeedService.diverseSampler([
        List.generate(10, (i) => track('one$i', artist: 'One artist')),
        List.generate(10, (i) => track('two$i', artist: 'Second artist')),
        [track('one0', artist: 'One artist'), track('third')],
      ]);
      expect(songs.map((s) => s.id).toSet().length, songs.length);
      expect(songs.where((s) => s.artist == 'One artist').length, 3);
      expect(songs.take(2).map((s) => s.artist), [
        'One artist',
        'Second artist',
      ]);
    },
  );
  test(
    'built-in discovery needs no user prompt and recovers to sampler on generator failure',
    () async {
      final feed = DiscoveryFeedService(
        repo,
        generate: (_) async => throw Exception('not configured'),
      );
      addTearDown(feed.dispose);
      await feed.refresh();
      await feed.surprise();
      expect(feed.generated, isNotEmpty);
      expect(feed.generating, false);
    },
  );
  test(
    'chapter matching rejects unrelated songs and versions instead of choosing the top result',
    () {
      const chapter = MixChapter(
        title: 'Artist Name - Blue Sky',
        startSeconds: 0,
        endSeconds: 180,
      );
      final wrong = track(
        'wrong',
        title: 'Another song',
        artist: 'Artist Name',
      );
      final remix = track(
        'remix',
        title: 'Blue Sky Remix',
        artist: 'Artist Name',
      );
      final right = track('right', title: 'Blue Sky', artist: 'Artist Name');
      expect(
        MixChapterService.bestMatch(chapter, [wrong, remix, right])?.id,
        'right',
      );
      expect(MixChapterService.bestMatch(chapter, [wrong, remix]), isNull);
    },
  );
  test('chapter matching rejects recording-length mismatches', () {
    const chapter = MixChapter(
      title: 'Artist Name - Blue Sky',
      startSeconds: 0,
      endSeconds: 180,
    );
    expect(
      MixChapterService.bestMatch(chapter, [
        track('long', title: 'Blue Sky', artist: 'Artist Name', duration: 500),
      ]),
      isNull,
    );
  });
  test(
    'chapter matching preserves chapter order and intentional repeated songs',
    () async {
      when(
        () => repo.searchSongs(any(), count: any(named: 'count')),
      ).thenAnswer(
        (_) async => [track('blue', title: 'Blue Sky', artist: 'Artist Name')],
      );
      final result = await MixChapterService(repo).resolve([
        const MixChapter(
          title: 'Artist Name - Blue Sky',
          startSeconds: 0,
          endSeconds: 180,
        ),
        const MixChapter(title: 'Intro', startSeconds: 180, endSeconds: 200),
        const MixChapter(
          title: 'Artist Name - Blue Sky',
          startSeconds: 200,
          endSeconds: 380,
        ),
      ]);
      expect(result.map((r) => r.song?.id), ['blue', null, 'blue']);
      verify(
        () => repo.searchSongs('Artist Name - Blue Sky', count: 8),
      ).called(1);
    },
  );
  test('invalid chapter ranges are rejected', () {
    expect(
      () => MixChapter.fromJson({'title': 'Song', 'start': 40, 'end': 20}),
      throwsFormatException,
    );
    expect(
      () => MixChapter.fromJson({'title': '', 'start': 0}),
      throwsFormatException,
    );
  });
  test('mix-card download rejects a video source and returns only reliable chapter matches', () async {
    when(() => repo.getStreamUrl(any())).thenAnswer((_) async => 'https://cdn.example/file?mime=video%2Fmp4');
    when(() => repo.searchSongs(any(), count: any(named: 'count'))).thenAnswer((_) async => [track('blue', title: 'Blue Sky', artist: 'Artist Name')]);
    final result = await MixChapterService(repo).downloadable(AccountSnapshot(complete: true,
      tracks: [RemoteTrack('full', track('youtube:mix'))], chapters: const [MixChapter(title: 'Artist Name - Blue Sky', startSeconds: 0, endSeconds: 180)]));
    expect(result.tracks.single.id, 'blue'); expect(result.chapterCount, 1);
  });
  test('audio-only full mix downloads preserve the original long recording', () async {
    when(() => repo.getStreamUrl(any())).thenAnswer((_) async => 'https://cdn.example/mix.m4a');
    final full = track('youtube:mix', duration: 3600);
    final result = await MixChapterService(repo).downloadable(AccountSnapshot(complete: true, tracks: [RemoteTrack('full', full)]));
    expect(result.tracks.single, same(full)); expect(result.chapterCount, isNull);
    verifyNever(() => repo.searchSongs(any(), count: any(named: 'count')));
  });
  test('incomplete mix metadata cannot trigger a partial chapter download', () async {
    await expectLater(MixChapterService(repo).downloadable(const AccountSnapshot()), throwsFormatException);
    verifyNever(() => repo.getStreamUrl(any()));
  });
}
