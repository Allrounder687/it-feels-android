import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:it_feels_music/services/auth_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUserCredential extends Mock implements UserCredential {}
class MockUser extends Mock implements User {}

void main() {
  late MockFirebaseAuth mockAuth;
  late AuthService authService;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    authService = AuthService(auth: mockAuth);
  });

  group('AuthService Anonymous Authentication Tests', () {
    test('successful anonymous sign in returns UserCredential', () async {
      final mockCred = MockUserCredential();
      final mockUser = MockUser();
      when(() => mockUser.uid).thenReturn('anon_123');
      when(() => mockCred.user).thenReturn(mockUser);
      when(() => mockAuth.signInAnonymously()).thenAnswer((_) async => mockCred);

      final result = await authService.signInAnonymously();
      expect(result, isNotNull);
      expect(result!.user!.uid, equals('anon_123'));
      expect(authService.isAnonymousSupported, isTrue);
    });

    test('gracefully handles admin-restricted-operation when Anonymous sign-in is disabled', () async {
      when(() => mockAuth.signInAnonymously()).thenThrow(
        FirebaseAuthException(
          code: 'admin-restricted-operation',
          message: 'This operation is restricted to administrators only.',
        ),
      );

      final result = await authService.signInAnonymously();
      expect(result, isNull);
      expect(authService.isAnonymousSupported, isFalse);

      // Verify second attempt returns immediately without calling FirebaseAuth again
      final secondResult = await authService.signInAnonymously();
      expect(secondResult, isNull);
      verify(() => mockAuth.signInAnonymously()).called(1);
    });

    test('gracefully handles unknown-error with restricted to administrators only message', () async {
      when(() => mockAuth.signInAnonymously()).thenThrow(
        FirebaseAuthException(
          code: 'unknown-error',
          message: 'This operation is restricted to administrators only.',
        ),
      );

      final result = await authService.signInAnonymously();
      expect(result, isNull);
      expect(authService.isAnonymousSupported, isFalse);
    });
  });
}
