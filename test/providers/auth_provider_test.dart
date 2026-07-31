import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/features/auth/auth_provider.dart';
import 'package:it_feels_music/services/auth_service.dart';
import 'package:it_feels_music/services/cloud_sync_service.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

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
  setUpAll(() {
    registerFallbackValue(MockUser());
  });

  late MockAuthService mockAuthService;
  late MockCloudSyncService mockCloudSyncService;
  late StreamController<User?> userStreamController;
  late ProviderContainer container;

  setUp(() {
    mockAuthService = MockAuthService();
    mockCloudSyncService = MockCloudSyncService();
    userStreamController = StreamController<User?>.broadcast();
    
    when(() => mockAuthService.userStream).thenAnswer((_) => userStreamController.stream);
    when(() => mockAuthService.currentUser).thenReturn(null);

    if (!locator.isRegistered<AuthService>()) {
      locator.registerSingleton<AuthService>(mockAuthService);
    }
    if (!locator.isRegistered<CloudSyncService>()) {
      locator.registerSingleton<CloudSyncService>(mockCloudSyncService);
    }

    container = ProviderContainer();
  });

  tearDown(() {
    userStreamController.close();
    container.dispose();
    locator.reset();
  });

  group('AuthNotifier State Machine Tests (Anti-Enumeration Flow)', () {
    test('initial state is emailInput', () {
      final state = container.read(authProvider);
      expect(state.viewState, AuthViewState.emailInput);
      expect(state.isAuthenticated, false);
      expect(state.errorMessage, isEmpty);
    });

    test('submitEmail sets viewState to loginPassword unconditionally', () async {
      const email = 'test@example.com';
      final notifier = container.read(authProvider.notifier);

      await notifier.submitEmail(email);
      final state = container.read(authProvider);

      expect(state.viewState, AuthViewState.loginPassword);
      expect(state.email, email);
    });

    test('submitEmail handles invalid email', () async {
      final notifier = container.read(authProvider.notifier);
      await notifier.submitEmail('invalidemail');
      final state = container.read(authProvider);
      
      expect(state.errorMessage, 'Please enter a valid email');
      expect(state.viewState, AuthViewState.emailInput);
    });

    test('submitPassword calls signInWithEmail when in loginPassword state', () async {
      const email = 'test@example.com';
      const password = 'password123';
      
      when(() => mockAuthService.signInWithEmail(email, password)).thenAnswer((_) async => MockUserCredential());
      
      final notifier = container.read(authProvider.notifier);
      await notifier.submitEmail(email);
      expect(container.read(authProvider).viewState, AuthViewState.loginPassword);

      final success = await notifier.submitPassword(password);

      expect(success, true);
      verify(() => mockAuthService.signInWithEmail(email, password)).called(1);
    });

    test('submitPassword sets signupPassword state if sign in throws user-not-found / invalid-credential', () async {
      const email = 'new@example.com';
      const password = 'password123';
      
      when(() => mockAuthService.signInWithEmail(email, password))
          .thenThrow(FakeFirebaseAuthException('invalid-credential'));
      
      final notifier = container.read(authProvider.notifier);
      await notifier.submitEmail(email);
      final success = await notifier.submitPassword(password);
      final state = container.read(authProvider);

      expect(success, false);
      expect(state.viewState, AuthViewState.signupPassword);
      expect(state.errorMessage, contains('Click "Create Account"'));
    });
    
    test('submitPassword calls signUpWithEmail when in signupPassword state', () async {
      const email = 'new@example.com';
      const password = 'password123';
      
      when(() => mockAuthService.signInWithEmail(email, password))
          .thenThrow(FakeFirebaseAuthException('invalid-credential'));
          
      final notifier = container.read(authProvider.notifier);
      await notifier.submitEmail(email);
      await notifier.submitPassword(password);
      
      expect(container.read(authProvider).viewState, AuthViewState.signupPassword);

      when(() => mockAuthService.signUpWithEmail(email, password)).thenAnswer((_) async => MockUserCredential());

      final success = await notifier.submitPassword(password);

      expect(success, true);
      verify(() => mockAuthService.signUpWithEmail(email, password)).called(1);
    });

    test('auth state changes correctly when user logs in', () async {
      final mockUser = MockUser();
      when(() => mockAuthService.currentUser).thenReturn(mockUser);
      when(() => mockCloudSyncService.initializeSync(any())).thenAnswer((_) async {});
      
      container.read(authProvider);

      userStreamController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 300));

      final state = container.read(authProvider);
      expect(container.read(authProvider.notifier).isAuthenticated, true);
      expect(state.viewState, AuthViewState.authenticated);
    });
  });
}
