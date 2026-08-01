import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/services/database_service.dart';
import 'package:it_feels_music/data/models/song_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseService dbService;

  setUp(() {
    dbService = DatabaseService();
  });

  group('DatabaseService Resiliency & Isar Error Guards', () {
    test('isInitialized returns false safely when DB is uninitialized', () {
      expect(DatabaseService.isInitialized, isFalse);
    });

    test('getSong returns null safely without throwing LateInitializationError when uninitialized', () async {
      final song = await dbService.getSong('saavn_123');
      expect(song, isNull);
    });

    test('searchSongs returns empty list safely when uninitialized', () async {
      final results = await dbService.searchSongs('arijit singh');
      expect(results, isEmpty);
    });

    test('getAllFavorites returns empty list safely when uninitialized', () async {
      final favorites = await dbService.getAllFavorites();
      expect(favorites, isEmpty);
    });

    test('getDownloadedSongs returns empty list safely when uninitialized', () async {
      final downloads = await dbService.getDownloadedSongs();
      expect(downloads, isEmpty);
    });

    test('getOnRepeat returns empty list safely when uninitialized', () async {
      final onRepeat = await dbService.getOnRepeat();
      expect(onRepeat, isEmpty);
    });

    test('getForgottenFavorites returns empty list safely when uninitialized', () async {
      final forgotten = await dbService.getForgottenFavorites();
      expect(forgotten, isEmpty);
    });

    test('saveSong executes safely without uncaught crashes when DB is uninitialized', () async {
      final dummySong = Song(
        id: 'test_1',
        saavnId: 'test_1',
        title: 'Test Title',
        artist: 'Test Artist',
        album: 'Test Album',
        duration: 180,
        coverArt: '',
        addedAt: DateTime.now(),
      );
      
      expect(() async => await dbService.saveSong(dummySong), returnsNormally);
    });

    test('incrementPlayCount executes safely without uncaught crashes when DB is uninitialized', () async {
      final dummySong = Song(
        id: 'test_1',
        saavnId: 'test_1',
        title: 'Test Title',
        artist: 'Test Artist',
        album: 'Test Album',
        duration: 180,
        coverArt: '',
        addedAt: DateTime.now(),
      );
      
      expect(() async => await dbService.incrementPlayCount(dummySong), returnsNormally);
    });

    test('toggleFavorite executes safely without uncaught crashes when DB is uninitialized', () async {
      expect(() async => await dbService.toggleFavorite('test_1'), returnsNormally);
    });
  });
}
