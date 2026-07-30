import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:it_feels_music/providers/auth_provider.dart';
import 'package:it_feels_music/services/auth_service.dart';
import 'package:it_feels_music/services/cloud_sync_service.dart';

class MockAuthService extends Mock implements AuthService {}
class MockCloudSyncService extends Mock implements CloudSyncService {}
class MockUser extends Mock implements User {}
class MockUserCredential extends Mock implements UserCredential {}
class FakeFirebaseAuthException extends Fake implements FirebaseAuthException {
  @override
  final String code;
  @override
  final String? message;
  FakeFirebaseAuthException(this.code, [this.message]);
}

void main() {
  late MockAuthService mockAuthService;
  late MockCloudSyncService mockCloudSyncService;
  late AuthProvider authProvider;
  late StreamController<User?> userStreamController;

  setUp(() {
    mockAuthService = MockAuthService();
    mockCloudSyncService = MockCloudSyncService();
    userStreamController = StreamController<User?>();
    
    when(() => mockAuthService.userStream).thenAnswer((_) => userStreamController.stream);
    when(() => mockAuthService.currentUser).thenReturn(null);

    authProvider = AuthProvider(
      authService: mockAuthService,
      cloudSyncService: mockCloudSyncService,
    );
  });

  tearDown(() {
    userStreamController.close();
  });

  group('AuthProvider State Machine Tests (Anti-Enumeration Flow)', () {
    test('initial state is emailInput', () {
      expect(authProvider.viewState, AuthViewState.emailInput);
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.errorMessage, isEmpty);
    });

    test('submitEmail sets viewState to loginPassword unconditionally', () async {
      const email = 'test@example.com';

      await authProvider.submitEmail(email);

      expect(authProvider.viewState, AuthViewState.loginPassword);
      expect(authProvider.email, email);
    });

    test('submitEmail handles invalid email', () async {
      await authProvider.submitEmail('invalidemail');
      
      expect(authProvider.errorMessage, 'Please enter a valid email');
      expect(authProvider.viewState, AuthViewState.emailInput);
    });

    test('submitPassword calls signInWithEmail when in loginPassword state', () async {
      const email = 'test@example.com';
      const password = 'password123';
      
      when(() => mockAuthService.signInWithEmail(email, password)).thenAnswer((_) async => MockUserCredential());
      
      await authProvider.submitEmail(email);
      expect(authProvider.viewState, AuthViewState.loginPassword);

      final success = await authProvider.submitPassword(password);

      expect(success, true);
      verify(() => mockAuthService.signInWithEmail(email, password)).called(1);
    });

    test('submitPassword sets signupPassword state if sign in throws user-not-found / invalid-credential', () async {
      const email = 'new@example.com';
      const password = 'password123';
      
      when(() => mockAuthService.signInWithEmail(email, password))
          .thenThrow(FakeFirebaseAuthException('invalid-credential'));
      
      await authProvider.submitEmail(email);
      final success = await authProvider.submitPassword(password);

      expect(success, false);
      expect(authProvider.viewState, AuthViewState.signupPassword);
      expect(authProvider.errorMessage, contains('Click "Create Account"'));
    });
    
    test('submitPassword calls signUpWithEmail when in signupPassword state', () async {
      const email = 'new@example.com';
      const password = 'password123';
      
      // First, simulate failing login to get into signup state
      when(() => mockAuthService.signInWithEmail(email, password))
          .thenThrow(FakeFirebaseAuthException('invalid-credential'));
          
      await authProvider.submitEmail(email);
      await authProvider.submitPassword(password);
      
      // Now in signup state
      expect(authProvider.viewState, AuthViewState.signupPassword);

      // Now mock the sign up
      when(() => mockAuthService.signUpWithEmail(email, password)).thenAnswer((_) async => MockUserCredential());

      final success = await authProvider.submitPassword(password);

      expect(success, true);
      verify(() => mockAuthService.signUpWithEmail(email, password)).called(1);
    });

    test('auth state changes correctly when user logs in', () async {
      final mockUser = MockUser();
      when(() => mockAuthService.currentUser).thenReturn(mockUser);
      
      // Simulate stream emitting a user
      userStreamController.add(mockUser);
      await Future.delayed(Duration.zero); // yield to event loop

      expect(authProvider.isAuthenticated, true);
      expect(authProvider.viewState, AuthViewState.authenticated);
    });
  });
}
