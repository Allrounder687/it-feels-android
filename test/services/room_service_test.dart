import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:it_feels_music/features/social/room_service.dart';
import 'package:it_feels_music/data/models/song_model.dart';

class MockFirebaseDatabase extends Mock implements FirebaseDatabase {}
class MockDatabaseReference extends Mock implements DatabaseReference {}
class MockOnDisconnect extends Mock implements OnDisconnect {}

void main() {
  late MockFirebaseDatabase mockDb;
  late MockDatabaseReference mockRef;
  late MockOnDisconnect mockOnDisconnect;
  late RoomService roomService;

  setUp(() {
    mockDb = MockFirebaseDatabase();
    mockRef = MockDatabaseReference();
    mockOnDisconnect = MockOnDisconnect();

    when(() => mockDb.ref(any())).thenReturn(mockRef);
    when(() => mockRef.keepSynced(any())).thenAnswer((_) async {});
    when(() => mockRef.onDisconnect()).thenReturn(mockOnDisconnect);
    when(() => mockOnDisconnect.remove()).thenAnswer((_) async {});

    roomService = RoomService(rtdb: mockDb);
  });

  group('RoomService', () {
    test('createRoom generates 6 digit code and pushes state', () async {
      final song = Song(
        id: '123',
        saavnId: '123',
        title: 'Title',
        artist: 'Artist',
        album: 'Album',
        coverArt: 'url',
        duration: 100,
        addedAt: DateTime.now(),
      );

      when(() => mockRef.set(any())).thenAnswer((_) async {});

      final roomId = await roomService.createRoom('host123', song, const Duration(seconds: 10), true);

      expect(roomId.length, 6);
      expect(int.tryParse(roomId), isNotNull);

      verify(() => mockDb.ref('rooms/$roomId')).called(1);
      
      final captured = verify(() => mockRef.set(captureAny())).captured;
      final data = captured.first as Map<String, dynamic>;
      
      expect(data['hostId'], 'host123');
      expect(data['songId'], '123');
      expect(data['positionMs'], 10000);
      expect(data['isPlaying'], true);
      expect(data['timestamp'], isNotNull);
      
      verify(() => mockRef.onDisconnect()).called(1);
      verify(() => mockOnDisconnect.remove()).called(1);
    });

    test('updateRoomState updates position and playing state', () async {
      when(() => mockRef.update(any())).thenAnswer((_) async {});

      final song = Song(
        id: '456',
        saavnId: '456',
        title: 'Title',
        artist: 'Artist',
        album: 'Album',
        coverArt: 'url',
        duration: 100,
        addedAt: DateTime.now(),
      );
      await roomService.updateRoomState('123456', song, const Duration(seconds: 20), false);

      verify(() => mockDb.ref('rooms/123456')).called(1);
      
      final captured = verify(() => mockRef.update(captureAny())).captured;
      final data = captured.first as Map<String, Object?>;
      
      expect(data['songId'], '456');
      expect(data['positionMs'], 20000);
      expect(data['isPlaying'], false);
    });

    test('endRoom removes room reference', () async {
      when(() => mockRef.remove()).thenAnswer((_) async {});

      await roomService.endRoom('123456');

      verify(() => mockDb.ref('rooms/123456')).called(1);
      verify(() => mockRef.remove()).called(1);
    });
  });
}
