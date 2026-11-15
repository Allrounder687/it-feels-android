import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/core/intelligence/playlists/listening_collection_service.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';

class _Repository extends Mock implements IMusicRepository {}

Song song(
  String id, {
  String artist = 'Arijit Singh',
  int year = 2020,
  String album = 'Album',
}) => Song(
  id: id,
  saavnId: id,
  title: 'Original $id',
  artist: artist,
  album: album,
  duration: 200,
  coverArt: '',
  year: year,
  addedAt: DateTime(2020),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repository repository;
  late ListeningCollectionService service;
  const artistMix = ListeningCollection(
    id: 'artist:arijit',
    title: 'Arijit Mix',
    query: 'Arijit Singh',
    artist: 'Arijit Singh',
    kind: ListeningCollectionKind.artist,
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = _Repository();
    service = ListeningCollectionService(repository, random: Random(42));
  });

  test(
    'cold start exposes 66 real query definitions with unique identities',
    () {
      final catalogue = ListeningCollection.catalogue([], now: DateTime(2026));
      expect(catalogue.length, 66);
      expect(catalogue.map((c) => c.id).toSet().length, catalogue.length);
      expect(
        catalogue
            .where((c) => c.kind == ListeningCollectionKind.year)
            .first
            .year,
        2026,
      );
    },
  );

  test(
    'listening history supplies artist, album and song radio definitions',
    () {
      final catalogue = ListeningCollection.catalogue([
        song('a', artist: 'My Artist'),
      ]);
      expect(catalogue.first.artist, 'My Artist');
      expect(
        catalogue.any((c) => c.kind == ListeningCollectionKind.album),
        isTrue,
      );
      expect(
        catalogue
            .singleWhere((c) => c.kind == ListeningCollectionKind.radio)
            .seed!
            .id,
        'a',
      );
    },
  );

  test('year and decade filters reject incorrectly tagged results', () {
    final candidates = [
      song('old', year: 1999),
      song('new', year: 2020),
      song('other', year: 2021),
    ];
    const year = ListeningCollection(
      id: 'year:2020',
      title: '2020',
      query: '2020',
      year: 2020,
      kind: ListeningCollectionKind.year,
    );
    const decade = ListeningCollection(
      id: 'decade:2020',
      title: '2020s',
      query: '2020s',
      year: 2020,
      kind: ListeningCollectionKind.decade,
    );
    expect(
      ListeningCollectionService.select(year, candidates).map((s) => s.id),
      ['new'],
    );
    expect(ListeningCollectionService.select(decade, candidates).length, 2);
  });

  test('artist selection rejects unrelated artists and duplicate IDs', () {
    final tracks = ListeningCollectionService.select(artistMix, [
      song('a'),
      song('a'),
      song('b', artist: 'Arijit Singh, Pritam'),
      song('c', artist: 'Another Artist'),
    ]);
    expect(tracks.map((s) => s.id), ['a', 'b']);
  });

  test('cache avoids repeated requests and survives provider outage', () async {
    await SharedPreferences.getInstance();
    when(
      () => repository.searchSongs('Arijit Singh', count: 60),
    ).thenAnswer((_) async => [song('a'), song('b'), song('c')]);
    final first = await service.load(artistMix);
    expect(
      (await service.load(artistMix)).map((s) => s.id),
      first.map((s) => s.id),
    );
    verify(() => repository.searchSongs('Arijit Singh', count: 60)).called(1);
    when(
      () => repository.searchSongs('Arijit Singh', count: 60),
    ).thenThrow(Exception('offline'));
    expect((await service.load(artistMix, refresh: true)).length, 3);
  });

  test('explicit refresh changes first track without losing tracks', () async {
    when(
      () => repository.searchSongs('Arijit Singh', count: 60),
    ).thenAnswer((_) async => List.generate(12, (i) => song('$i')));
    final first = await service.load(artistMix);
    final second = await service.load(artistMix, refresh: true);
    expect(second.first.id, isNot(first.first.id));
    expect(second.map((s) => s.id).toSet(), first.map((s) => s.id).toSet());
  });

  test('parallel taps share a single repository request', () async {
    when(
      () => repository.searchSongs('Arijit Singh', count: 60),
    ).thenAnswer((_) async => [song('a')]);
    await Future.wait([service.load(artistMix), service.load(artistMix)]);
    verify(() => repository.searchSongs('Arijit Singh', count: 60)).called(1);
  });

  test(
    'song radio uses recommendations and places seed exactly once',
    () async {
      final seed = song('seed');
      when(
        () => repository.getRecommendedSongs(seed),
      ).thenAnswer((_) async => [seed, seed, song('next')]);
      final tracks = await service.load(ListeningCollection.songRadio(seed));
      expect(tracks.map((s) => s.id), ['seed', 'next']);
      verifyNever(
        () => repository.searchSongs(any(), count: any(named: 'count')),
      );
    },
  );

  test('corrupt snapshot is rebuilt from addons', () async {
    SharedPreferences.setMockInitialValues({
      'listening_collection_v1:artist:arijit': '{broken',
    });
    when(
      () => repository.searchSongs('Arijit Singh', count: 60),
    ).thenAnswer((_) async => [song('a')]);
    expect((await service.load(artistMix)).single.id, 'a');
  });
}
