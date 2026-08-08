import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:it_feels_music/features/social/social_service.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/services/notification_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {
  @override
  String get uid => 'test_uid_123';
  @override
  String? get email => 'test@example.com';
}
class MockFirebaseDatabase extends Mock implements FirebaseDatabase {}
class MockDatabaseReference extends Mock implements DatabaseReference {}
class MockOnDisconnect extends Mock implements OnDisconnect {}
class MockNotificationService extends Mock implements NotificationService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockFirebaseDatabase mockRtdb;
  late MockNotificationService mockNotificationService;
  late SocialService socialService;

  final Song dummySong = Song(
    id: 'song1', saavnId: 's1', title: 'Test Song', artist: 'Test Artist',
    album: 'Test Album', duration: 180, coverArt: 'cover.jpg',
    encryptedMediaUrl: 'url', addedAt: DateTime.now(),
  );

  setUp(() async {
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    fakeFirestore = FakeFirebaseFirestore();
    mockRtdb = MockFirebaseDatabase();
    mockNotificationService = MockNotificationService();

    when(() => mockAuth.currentUser).thenReturn(mockUser);

    if (!locator.isRegistered<NotificationService>()) {
      locator.registerSingleton<NotificationService>(mockNotificationService);
    }

    socialService = SocialService(
      firestore: fakeFirestore,
      auth: mockAuth,
      rtdb: mockRtdb,
    );
    registerFallbackValue(dummySong);
  });

  tearDown(() => locator.reset());

  group('SocialService - Friend Management', () {
    test('addFriendByUid adds friend successfully', () async {
      await fakeFirestore.collection('users').doc('friend_uid_456').set({'name': 'Friend'});
      await fakeFirestore.collection('users').doc('test_uid_123').set({'name': 'Me'});
      expect(await socialService.addFriendByUid('friend_uid_456'), isTrue);
      final myDoc = await fakeFirestore.collection('users').doc('test_uid_123').get();
      expect(myDoc.data()?['friends'], contains('friend_uid_456'));
    });

    test('addFriendByUid fails for non-existent user', () async {
      expect(await socialService.addFriendByUid('non_existent_uid'), isFalse);
    });

    test('addFriendByQuery adds friend by email', () async {
      await fakeFirestore.collection('users').doc('friend_uid_456').set({'name': 'Friend', 'email': 'friend@example.com'});
      await fakeFirestore.collection('users').doc('test_uid_123').set({'name': 'Me'});
      expect(await socialService.addFriendByQuery('friend@example.com'), isTrue);
    });

    test('removeFriend removes friend successfully', () async {
      await fakeFirestore.collection('users').doc('friend_uid_456').set({'friends': ['test_uid_123']});
      await fakeFirestore.collection('users').doc('test_uid_123').set({'friends': ['friend_uid_456']});
      expect(await socialService.removeFriend('friend_uid_456'), isTrue);
      final myDoc = await fakeFirestore.collection('users').doc('test_uid_123').get();
      expect(myDoc.data()?['friends'], isNot(contains('friend_uid_456')));
    });

    test('setFriendNickname sets nickname in Firestore', () async {
      await fakeFirestore.collection('users').doc('test_uid_123').set({'name': 'Me'});
      await socialService.setFriendNickname('friend_uid_456', 'MyBuddy');
      final myDoc = await fakeFirestore.collection('users').doc('test_uid_123').get();
      expect(myDoc.data()?['friend_names'], {'friend_uid_456': 'MyBuddy'});
    });
  });

  group('SocialService - Inbox & Messaging', () {
    test('sendSong writes to friend inbox with correct fields', () async {
      await fakeFirestore.collection('users').doc('test_uid_123').set({'name': 'Me'});
      await fakeFirestore.collection('users').doc('friend_uid_456').set({});
      when(() => mockNotificationService.notifyFriendsOfRoom(any(), any(), any())).thenAnswer((_) async => {});
      await socialService.sendSong('friend_uid_456', dummySong);
      final snap = await fakeFirestore.collection('users').doc('friend_uid_456').collection('inbox').get();
      expect(snap.docs, hasLength(1));
      expect(snap.docs.first.data()['senderId'], 'test_uid_123');
      expect(snap.docs.first.data()['type'], 'song');
      expect(snap.docs.first.data()['payload']['title'], 'Test Song');
      expect(snap.docs.first.data()['isRead'], isFalse);
    });

    test('markAsRead sets isRead to true', () async {
      await fakeFirestore.collection('users').doc('test_uid_123').collection('inbox').doc('msg1').set({'isRead': false});
      await socialService.markAsRead('msg1');
      final doc = await fakeFirestore.collection('users').doc('test_uid_123').collection('inbox').doc('msg1').get();
      expect(doc.data()?['isRead'], isTrue);
    });

    test('getInboxStream returns non-null stream when authenticated', () {
      expect(socialService.getInboxStream(), isNotNull);
    });

    test('getUnreadCountStream emits correct unread count', () async {
      await fakeFirestore.collection('users').doc('test_uid_123').collection('inbox').add({'isRead': false});
      await fakeFirestore.collection('users').doc('test_uid_123').collection('inbox').add({'isRead': true});
      expect(await socialService.getUnreadCountStream().first, 1);
    });
  });

  group('SocialService - Presence', () {
    test('updatePresence calls set() with correct data', () async {
      final mockDbRef = MockDatabaseReference();
      final mockOnDisconnect = MockOnDisconnect();
      when(() => mockRtdb.ref(any())).thenReturn(mockDbRef);
      when(() => mockDbRef.set(any())).thenAnswer((_) async => {});
      when(() => mockDbRef.onDisconnect()).thenReturn(mockOnDisconnect);
      when(() => mockOnDisconnect.remove()).thenAnswer((_) async => {});
      await socialService.updatePresence(dummySong, true);
      final captured = verify(() => mockDbRef.set(captureAny())).captured;
      final data = captured.first as Map;
      expect(data['is_playing'], isTrue);
      expect(data['song_title'], 'Test Song');
    });
  });
}
