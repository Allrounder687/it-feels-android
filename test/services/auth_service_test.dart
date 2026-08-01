import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:it_feels_music/services/auth_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockFirebaseAuth mockAuth;
  late AuthService authService;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    authService = AuthService(auth: mockAuth);
  });

  group('AuthService Resiliency Tests', () {
    test('signInAnonymously catches exceptions safely when anonymous auth is restricted', () async {
      when(() => mockAuth.signInAnonymously()).thenThrow(
        FirebaseAuthException(
          code: 'admin-restricted-operation',
          message: 'This operation is restricted to administrators only.',
        ),
      );

      final cred = await authService.signInAnonymously();
      expect(cred, isNull);
    });

    test('signInAnonymously succeeds when allowed', () async {
      final mockUserCred = MockUserCredential();
      when(() => mockAuth.signInAnonymously()).thenAnswer((_) async => mockUserCred);

      final cred = await authService.signInAnonymously();
      expect(cred, equals(mockUserCred));
    });
  });
}

class MockUserCredential extends Mock implements UserCredential {
  @override
  User? get user => null;
}
