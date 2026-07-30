import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:it_feels_music/services/cloud_sync_service.dart';
import 'package:it_feels_music/services/database_service.dart';
import 'package:it_feels_music/data/models/song_model.dart';

class MockDatabaseService extends Mock implements DatabaseService {}
class MockUser extends Mock implements User {
  @override
  String get uid => 'test_uid_123';
}

void main() {
  late MockDatabaseService mockDbService;
  late FakeFirebaseFirestore fakeFirestore;
  late CloudSyncService syncService;
  late MockUser mockUser;

  setUp(() {
    mockDbService = MockDatabaseService();
    fakeFirestore = FakeFirebaseFirestore();
    mockUser = MockUser();

    syncService = CloudSyncService(
      firestore: fakeFirestore,
      dbService: mockDbService,
    );
  });

  tearDown(() {
    syncService.stopSync();
  });

  group('CloudSyncService - Push Local Favorites to Cloud', () {
    test('successfully pushes local favorites to Firestore', () async {
      final localSong1 = Song(
        id: 'saavn:111',
        saavnId: '111',
        title: 'Local Song 1',
        artist: 'Artist 1',
        album: 'Album 1',
        coverArt: 'url1',
        duration: 180,
        addedAt: DateTime.now(),
        isFavorite: true,
      );

      final localSong2 = Song(
        id: 'saavn:222',
        saavnId: '222',
        title: 'Local Song 2',
        artist: 'Artist 2',
        album: 'Album 2',
        coverArt: 'url2',
        duration: 200,
        addedAt: DateTime.now(),
        isFavorite: true,
      );

      when(() => mockDbService.getAllFavorites()).thenAnswer((_) async => [localSong1, localSong2]);

      await syncService.pushLocalFavoritesToCloud(mockUser.uid);

      // Verify Firestore data
      final snapshot = await fakeFirestore
          .collection('users')
          .doc(mockUser.uid)
          .collection('favorites')
          .get();

      expect(snapshot.docs.length, 2);
      expect(snapshot.docs.any((d) => d.id == 'saavn:111'), isTrue);
      expect(snapshot.docs.any((d) => d.id == 'saavn:222'), isTrue);
      
      final doc1 = snapshot.docs.firstWhere((d) => d.id == 'saavn:111').data();
      expect(doc1['title'], 'Local Song 1');
      expect(doc1['saavnId'], '111');
    });

    test('handles empty local favorites safely', () async {
      when(() => mockDbService.getAllFavorites()).thenAnswer((_) async => []);

      await syncService.pushLocalFavoritesToCloud(mockUser.uid);

      final snapshot = await fakeFirestore
          .collection('users')
          .doc(mockUser.uid)
          .collection('favorites')
          .get();

      expect(snapshot.docs.length, 0);
    });
  });

  group('CloudSyncService - Listen Cloud to Local', () {
    test('merges remote favorites into local db', () async {
      // Provide fallback behavior for DatabaseService mock
      registerFallbackValue(Song(id: 'dummy', saavnId: 'dummy', title: '', artist: '', album: '', duration: 0, coverArt: '', addedAt: DateTime.now()));
      
      when(() => mockDbService.getAllFavorites()).thenAnswer((_) async => []);
      
      when(() => mockDbService.getSong(any())).thenAnswer((_) async => null);
      when(() => mockDbService.saveSong(any())).thenAnswer((_) async => {});

      // Start the listener
      syncService.initializeSync(mockUser);

      // Add a song directly to Firestore (simulating another device)
      await fakeFirestore
          .collection('users')
          .doc(mockUser.uid)
          .collection('favorites')
          .doc('saavn:333')
          .set({
        'id': 'saavn:333',
        'saavnId': '333',
        'title': 'Cloud Song',
        'artist': 'Cloud Artist',
        'album': 'Cloud Album',
        'coverArt': 'url3',
        'duration': 150,
        'hasLyrics': false,
      });

      // Wait a moment for stream to trigger
      await Future.delayed(const Duration(milliseconds: 100));

      // It should have queried local DB and saved the new song
      verify(() => mockDbService.getSong('saavn:333')).called(greaterThanOrEqualTo(1));
      
      final captured = verify(() => mockDbService.saveSong(captureAny())).captured;
      final savedSong = captured.last as Song;
      
      expect(savedSong.id, 'saavn:333');
      expect(savedSong.title, 'Cloud Song');
      expect(savedSong.isFavorite, true);
    });

    test('toggles favorite status if song already exists locally but is not favorite', () async {
      final existingLocalSong = Song(
        id: 'saavn:444',
        saavnId: '444',
        title: 'Existing Song',
        artist: 'Artist',
        album: 'Album',
        coverArt: '',
        duration: 100,
        addedAt: DateTime.now(),
        isFavorite: false, // NOT favorite yet
      );

      registerFallbackValue(existingLocalSong);
      when(() => mockDbService.getAllFavorites()).thenAnswer((_) async => []);
      when(() => mockDbService.getSong('saavn:444')).thenAnswer((_) async => existingLocalSong);
      when(() => mockDbService.toggleFavorite('saavn:444')).thenAnswer((_) async => {});

      syncService.initializeSync(mockUser);

      await fakeFirestore
          .collection('users')
          .doc(mockUser.uid)
          .collection('favorites')
          .doc('saavn:444')
          .set({
        'id': 'saavn:444',
        'saavnId': '444',
        'title': 'Existing Song',
      });

      await Future.delayed(const Duration(milliseconds: 100));

      verify(() => mockDbService.toggleFavorite('saavn:444')).called(1);
    });
  });
}
