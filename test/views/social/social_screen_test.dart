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
import 'package:it_feels_music/data/services/lyrics_service.dart';
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
// ignore: subtype_of_sealed_class
class MockDocumentSnapshot extends Mock implements DocumentSnapshot {}
// ignore: subtype_of_sealed_class
class MockQuerySnapshot extends Mock implements QuerySnapshot {}
// ignore: subtype_of_sealed_class
class MockQueryDocumentSnapshot extends Mock implements QueryDocumentSnapshot {}
class MockDatabaseEvent extends Mock implements DatabaseEvent {}
class MockLyricsService extends Mock implements LyricsService {}

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
    final mockLyricsService = MockLyricsService();

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
    locator.registerSingleton<LyricsService>(mockLyricsService);
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
        child: const MaterialApp(
          home: Scaffold(body: SocialScreen()),
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

  testWidgets('Friends list network call is cached by Riverpod and survives UI rebuilds without infinite loading', (WidgetTester tester) async {
    when(() => mockSocialService.getInboxStream()).thenAnswer((_) => const Stream.empty());
    when(() => mockRoomService.getPublicRooms()).thenAnswer((_) => const Stream.empty());

    final mockDocSnap = MockDocumentSnapshot();
    when(() => mockDocSnap.exists).thenReturn(true);
    when(() => mockDocSnap.data()).thenReturn({
      'friends': ['cached_friend_1']
    });

    when(() => mockSocialService.getFriendsStream()).thenAnswer((_) => Stream.value(mockDocSnap));
    when(() => mockSocialService.getFriendDetails('cached_friend_1')).thenAnswer((_) async => {
      'uid': 'cached_friend_1',
      'displayName': 'Cached Friend',
      'username': 'cached1'
    });
    when(() => mockSocialService.getPresenceStream(any())).thenAnswer((_) => const Stream.empty());

    // Wrap in StatefulBuilder to trigger rebuilds
    StateSetter? setTestState;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: appProviderContainer,
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setTestState = setState;
                return const SocialScreen();
              }
            )
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap on Friends tab
    await tester.tap(find.text('FRIENDS 👥'));
    await tester.pumpAndSettle();

    // Verify friend is rendered
    expect(find.text('Cached Friend'), findsOneWidget);

    // Trigger 5 rapid UI rebuilds (simulating animations or presence stream updates)
    for (int i = 0; i < 5; i++) {
      setTestState!((){});
      await tester.pump();
    }

    // Verify friend is STILL rendered and no loading skeleton is showing
    expect(find.text('Cached Friend'), findsOneWidget);

    // Verify that the getFriendDetails was ONLY CALLED ONCE despite 5 rebuilds!
    verify(() => mockSocialService.getFriendDetails('cached_friend_1')).called(1);
  });
}
