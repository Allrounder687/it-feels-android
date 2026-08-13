import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/features/social/listen_together_service.dart';
import 'package:it_feels_music/features/social/room_service.dart';
import 'package:it_feels_music/features/social/social_service.dart';
import 'package:it_feels_music/services/notification_service.dart';
import 'package:it_feels_music/data/models/song_model.dart';

class MockFirebaseDatabase extends Mock implements FirebaseDatabase {}
class MockDatabaseReference extends Mock implements DatabaseReference {}
class MockDatabaseEvent extends Mock implements DatabaseEvent {}
class MockDataSnapshot extends Mock implements DataSnapshot {}
class MockRoomService extends Mock implements RoomService {}
class MockSocialService extends Mock implements SocialService {}
class MockNotificationService extends Mock implements NotificationService {}

void main() {
  late MockFirebaseDatabase mockDb;
  late MockDatabaseReference mockRef;
  late FakeFirebaseFirestore fakeFirestore;
  late MockRoomService mockRoomService;
  late MockSocialService mockSocialService;
  late MockNotificationService mockNotificationService;

  setUpAll(() {
    registerFallbackValue(Song(
      id: '',
      saavnId: '',
      title: '',
      artist: '',
      album: '',
      duration: 0,
      coverArt: '',
      addedAt: DateTime.now(),
    ));
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    mockDb = MockFirebaseDatabase();
    mockRef = MockDatabaseReference();
    fakeFirestore = FakeFirebaseFirestore();
    mockRoomService = MockRoomService();
    mockSocialService = MockSocialService();
    mockNotificationService = MockNotificationService();

    when(() => mockDb.ref('.info/serverTimeOffset')).thenReturn(mockRef);
    when(() => mockRef.onValue).thenAnswer((_) => const Stream.empty());

    if (locator.isRegistered<RoomService>()) locator.unregister<RoomService>();
    if (locator.isRegistered<SocialService>()) locator.unregister<SocialService>();
    if (locator.isRegistered<NotificationService>()) locator.unregister<NotificationService>();
    if (locator.isRegistered<FirebaseFirestore>()) locator.unregister<FirebaseFirestore>();

    locator.registerSingleton<RoomService>(mockRoomService);
    locator.registerSingleton<SocialService>(mockSocialService);
    locator.registerSingleton<NotificationService>(mockNotificationService);
    locator.registerSingleton<FirebaseFirestore>(fakeFirestore);
  });

  group('ListenTogetherService Tests', () {
    test('startBroadcasting creates room and notifies friends', () async {
      final service = ListenTogetherService(database: mockDb);

      await fakeFirestore.collection('users').doc('host123').set({
        'name': 'Host Name',
        'friends': ['friend1', 'friend2'],
      });

      when(() => mockRoomService.createRoom(
        any(), any(), any(), any(),
        isPublic: any(named: 'isPublic'),
        allowGuestControl: any(named: 'allowGuestControl'),
        streamUrl: any(named: 'streamUrl'),
        timestamp: any(named: 'timestamp'),
      )).thenAnswer((_) async => 'room_xyz');

      when(() => mockSocialService.updatePresence(any(), any(), roomId: any(named: 'roomId')))
          .thenAnswer((_) async {});

      when(() => mockNotificationService.notifyFriendsOfRoom(any(), any(), any()))
          .thenAnswer((_) async {});

      when(() => mockRoomService.listenToJoinRequests('room_xyz'))
          .thenAnswer((_) => const Stream.empty());

      final song = Song(
        id: '123',
        saavnId: '123',
        title: 'Title',
        artist: 'Artist',
        album: 'Album',
        duration: 200,
        coverArt: '',
        addedAt: DateTime.now(),
      );

      final roomId = await service.startBroadcasting(
        'host123', song, const Duration(seconds: 10), true, true
      );

      expect(roomId, 'room_xyz');
      expect(service.isHost, true);
      expect(service.currentRoomId, 'room_xyz');

      verify(() => mockNotificationService.notifyFriendsOfRoom(
        ['friend1', 'friend2'], 'Host Name', 'room_xyz'
      )).called(1);
    });
  });
}
