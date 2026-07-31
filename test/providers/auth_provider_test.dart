import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:it_feels_music/features/auth/auth_provider.dart';
import 'package:it_feels_music/services/auth_service.dart';
import 'package:it_feels_music/services/cloud_sync_service.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';

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
  late AuthNotifier authNotifier;
  late StreamController<User?> userStreamController;

  setUp(() {
    mockAuthService = MockAuthService();
    mockCloudSyncService = MockCloudSyncService();
    userStreamController = StreamController<User?>();
    
    when(() => mockAuthService.userStream).thenAnswer((_) => userStreamController.stream);
    when(() => mockAuthService.currentUser).thenReturn(null);

    if (!locator.isRegistered<AuthService>()) {
      locator.registerSingleton<AuthService>(mockAuthService);
    }
    if (!locator.isRegistered<CloudSyncService>()) {
      locator.registerSingleton<CloudSyncService>(mockCloudSyncService);
    }

    authNotifier = AuthNotifier();
  });

  tearDown(() {
    userStreamController.close();
    locator.reset();
  });

  group('AuthNotifier State Machine Tests (Anti-Enumeration Flow)', () {
    test('initial state is emailInput', () {
      expect(authNotifier.state.viewState, AuthViewState.emailInput);
      expect(authNotifier.state.isAuthenticated, false);
      expect(authNotifier.state.errorMessage, isEmpty);
    });

    test('submitEmail sets viewState to loginPassword unconditionally', () async {
      const email = 'test@example.com';

      await authNotifier.submitEmail(email);

      expect(authNotifier.state.viewState, AuthViewState.loginPassword);
      expect(authNotifier.state.email, email);
    });

    test('submitEmail handles invalid email', () async {
      await authNotifier.submitEmail('invalidemail');
      
      expect(authNotifier.state.errorMessage, 'Please enter a valid email');
      expect(authNotifier.state.viewState, AuthViewState.emailInput);
    });

    test('submitPassword calls signInWithEmail when in loginPassword state', () async {
      const email = 'test@example.com';
      const password = 'password123';
      
      when(() => mockAuthService.signInWithEmail(email, password)).thenAnswer((_) async => MockUserCredential());
      
      await authNotifier.submitEmail(email);
      expect(authNotifier.state.viewState, AuthViewState.loginPassword);

      final success = await authNotifier.submitPassword(password);

      expect(success, true);
      verify(() => mockAuthService.signInWithEmail(email, password)).called(1);
    });

    test('submitPassword sets signupPassword state if sign in throws user-not-found / invalid-credential', () async {
      const email = 'new@example.com';
      const password = 'password123';
      
      when(() => mockAuthService.signInWithEmail(email, password))
          .thenThrow(FakeFirebaseAuthException('invalid-credential'));
      
      await authNotifier.submitEmail(email);
      final success = await authNotifier.submitPassword(password);

      expect(success, false);
      expect(authNotifier.state.viewState, AuthViewState.signupPassword);
      expect(authNotifier.state.errorMessage, contains('Click "Create Account"'));
    });
    
    test('submitPassword calls signUpWithEmail when in signupPassword state', () async {
      const email = 'new@example.com';
      const password = 'password123';
      
      when(() => mockAuthService.signInWithEmail(email, password))
          .thenThrow(FakeFirebaseAuthException('invalid-credential'));
          
      await authNotifier.submitEmail(email);
      await authNotifier.submitPassword(password);
      
      expect(authNotifier.state.viewState, AuthViewState.signupPassword);

      when(() => mockAuthService.signUpWithEmail(email, password)).thenAnswer((_) async => MockUserCredential());

      final success = await authNotifier.submitPassword(password);

      expect(success, true);
      verify(() => mockAuthService.signUpWithEmail(email, password)).called(1);
    });

    test('auth state changes correctly when user logs in', () async {
      final mockUser = MockUser();
      when(() => mockAuthService.currentUser).thenReturn(mockUser);
      
      userStreamController.add(mockUser);
      await Future.delayed(Duration.zero);

      expect(authNotifier.state.isAuthenticated, true);
      expect(authNotifier.state.viewState, AuthViewState.authenticated);
    });
  });
}
