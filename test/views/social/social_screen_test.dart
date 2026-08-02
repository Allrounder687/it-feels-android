import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:it_feels_music/features/social/social_screen.dart';
import 'package:it_feels_music/features/social/social_service.dart';
import 'package:it_feels_music/features/social/room_service.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/main.dart';

// Mocks
class MockSocialService extends Mock implements SocialService {}
class MockRoomService extends Mock implements RoomService {}
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot {}
class MockQuerySnapshot extends Mock implements QuerySnapshot {}
class MockQueryDocumentSnapshot extends Mock implements QueryDocumentSnapshot {}
class MockDatabaseEvent extends Mock implements DatabaseEvent {}

class MockAudioPlayerNotifier extends AudioPlayerNotifier {
  @override
  AudioPlayerState build() {
    return const AudioPlayerState();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSocialService mockSocialService;
  late MockRoomService mockRoomService;
  late MockFirebaseAuth mockFirebaseAuth;
  late FakeFirebaseFirestore fakeFirestore;
  late MockUser mockUser;

  setUpAll(() {
    appProviderContainer = ProviderContainer(
      overrides: [
        audioPlayerProvider.overrideWith(() => MockAudioPlayerNotifier()),
      ],
    );
  });

  setUp(() async {
    mockSocialService = MockSocialService();
    mockRoomService = MockRoomService();
    mockFirebaseAuth = MockFirebaseAuth();
    fakeFirestore = FakeFirebaseFirestore();
    mockUser = MockUser();

    when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
    when(() => mockFirebaseAuth.authStateChanges()).thenAnswer((_) => Stream.value(mockUser));
    when(() => mockUser.uid).thenReturn('test_uid');
    when(() => mockUser.isAnonymous).thenReturn(false);


    // Setup basic client_config to prevent null stream errors
    await fakeFirestore.collection('client_config').doc('social').set({
      'inboxMessage': 'HAVE FUN GUYS',
      'showInboxMessage': true
    });

    // Reset and register locators
    locator.reset();
    locator.registerSingleton<SocialService>(mockSocialService);
    locator.registerSingleton<RoomService>(mockRoomService);
    locator.registerSingleton<FirebaseAuth>(mockFirebaseAuth);
    locator.registerSingleton<FirebaseFirestore>(fakeFirestore);
  });

  testWidgets('SocialScreen gracefully handles corrupted friends list data', (tester) async {
    // 1. Setup mock streams for SocialScreen
    when(() => mockSocialService.getInboxStream()).thenAnswer((_) => const Stream.empty());
    when(() => mockRoomService.getPublicRooms()).thenAnswer((_) => const Stream.empty());

    // 2. Setup the corrupted DocumentSnapshot stream for Friends
    final mockDocSnap = MockDocumentSnapshot();
    when(() => mockDocSnap.exists).thenReturn(true);
    
    // Injecting raw Strings (UIDs) inside the friends array
    when(() => mockDocSnap.data()).thenReturn({
      'friends': [
        'valid_uid_1',
        123, // corrupt data (int)
        null,
      ]
    });

    when(() => mockSocialService.getFriendsStream()).thenAnswer((_) => Stream.value(mockDocSnap));
    when(() => mockSocialService.getFriendDetails('valid_uid_1')).thenAnswer((_) async => {
      'uid': 'valid_uid_1',
      'displayName': 'Valid Friend',
      'username': 'valid1'
    });
    when(() => mockSocialService.getPresenceStream(any())).thenAnswer((_) => const Stream.empty());

    // 3. Pump the Widget Tree
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: appProviderContainer,
        child: MaterialApp(
          home: Scaffold(body: const SocialScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 4. Tap on Friends tab
    await tester.tap(find.text('FRIENDS 👥'));
    await tester.pumpAndSettle();

    // 5. Verify no crash occurred (No ErrorWidget shown)
    expect(find.byType(ErrorWidget), findsNothing);

    // 6. Verify that it parsed the valid friend but ignored the corrupt one
    // It should render 'Valid Friend'
    expect(find.text('Valid Friend'), findsOneWidget);
  });
}
