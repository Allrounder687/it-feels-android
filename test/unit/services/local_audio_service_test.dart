import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/local_audio_service.dart';

class MockOnAudioQuery extends Mock implements OnAudioQuery {}
class MockSongModel extends Mock implements SongModel {}

void main() {
  late MockOnAudioQuery mockAudioQuery;
  late LocalAudioService service;

  setUp(() {
    mockAudioQuery = MockOnAudioQuery();
    service = LocalAudioService(audioQuery: mockAudioQuery);
  });

  group('LocalAudioService Permissions', () {
    test('requestPermission returns true if permissionStatus is true', () async {
      when(() => mockAudioQuery.permissionsStatus()).thenAnswer((_) async => true);

      final result = await service.requestPermission();
      expect(result, isTrue);
      verify(() => mockAudioQuery.permissionsStatus()).called(1);
      verifyNever(() => mockAudioQuery.permissionsRequest());
    });

    test('requestPermission requests permission if status is false', () async {
      when(() => mockAudioQuery.permissionsStatus()).thenAnswer((_) async => false);
      when(() => mockAudioQuery.permissionsRequest()).thenAnswer((_) async => true);

      final result = await service.requestPermission();
      expect(result, isTrue);
      verify(() => mockAudioQuery.permissionsStatus()).called(1);
      verify(() => mockAudioQuery.permissionsRequest()).called(1);
    });
  });

  group('LocalAudioService scanLocalMusic', () {
    test('scanLocalMusic returns empty list if permission denied', () async {
      when(() => mockAudioQuery.permissionsStatus()).thenAnswer((_) async => false);
      when(() => mockAudioQuery.permissionsRequest()).thenAnswer((_) async => false);

      final result = await service.scanLocalMusic();
      expect(result, isEmpty);
    });

    test('scanLocalMusic queries and maps local songs successfully when permission granted', () async {
      when(() => mockAudioQuery.permissionsStatus()).thenAnswer((_) async => true);

      final mockSong1 = MockSongModel();
      when(() => mockSong1.id).thenReturn(101);
      when(() => mockSong1.title).thenReturn('Test Song 1');
      when(() => mockSong1.artist).thenReturn('Artist A');
      when(() => mockSong1.album).thenReturn('Album X');
      when(() => mockSong1.duration).thenReturn(180000); // 180s
      when(() => mockSong1.data).thenReturn('/storage/emulated/0/Music/song1.mp3');

      final mockSong2 = MockSongModel();
      when(() => mockSong2.id).thenReturn(102);
      when(() => mockSong2.title).thenReturn('Test Song 2');
      when(() => mockSong2.artist).thenReturn(null);
      when(() => mockSong2.album).thenReturn(null);
      when(() => mockSong2.duration).thenReturn(null);
      when(() => mockSong2.data).thenReturn('/storage/emulated/0/Music/song2.mp3');

      when(() => mockAudioQuery.querySongs(
            sortType: any(named: 'sortType'),
            orderType: any(named: 'orderType'),
            uriType: any(named: 'uriType'),
            ignoreCase: any(named: 'ignoreCase'),
          )).thenAnswer((_) async => [mockSong1, mockSong2]);

      final result = await service.scanLocalMusic();
      
      expect(result.length, 2);
      
      expect(result[0].id, 'local:101');
      expect(result[0].title, 'Test Song 1');
      expect(result[0].artist, 'Artist A');
      expect(result[0].album, 'Album X');
      expect(result[0].duration, 180);
      expect(result[0].encryptedMediaUrl, 'file:///storage/emulated/0/Music/song1.mp3');

      expect(result[1].id, 'local:102');
      expect(result[1].artist, 'Unknown Artist');
      expect(result[1].album, 'Unknown Album');
      expect(result[1].duration, 0);
      expect(result[1].encryptedMediaUrl, 'file:///storage/emulated/0/Music/song2.mp3');
    });

    test('scanLocalMusic returns empty list on query exceptions', () async {
      when(() => mockAudioQuery.permissionsStatus()).thenAnswer((_) async => true);
      when(() => mockAudioQuery.querySongs(
            sortType: any(named: 'sortType'),
            orderType: any(named: 'orderType'),
            uriType: any(named: 'uriType'),
            ignoreCase: any(named: 'ignoreCase'),
          )).thenThrow(Exception('DB error'));

      final result = await service.scanLocalMusic();
      expect(result, isEmpty);
    });
  });
}
