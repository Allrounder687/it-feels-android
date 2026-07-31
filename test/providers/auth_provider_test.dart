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

  group('AuthNotifier State Machine Tests', () {
    test('initial state is login', () {
      final state = container.read(authProvider);
      expect(state.viewState, AuthViewState.login);
      expect(state.isAuthenticated, false);
      expect(state.errorMessage, isEmpty);
    });

    test('submitAuth handles invalid email', () async {
      final notifier = container.read(authProvider.notifier);
      final success = await notifier.submitAuth('invalidemail', 'password123');
      final state = container.read(authProvider);
      
      expect(success, false);
      expect(state.errorMessage, 'Please enter a valid email');
    });

    test('submitAuth handles short password', () async {
      final notifier = container.read(authProvider.notifier);
      final success = await notifier.submitAuth('test@example.com', '123');
      final state = container.read(authProvider);
      
      expect(success, false);
      expect(state.errorMessage, 'Password must be at least 6 characters');
    });

    test('toggleView changes viewState', () {
      final notifier = container.read(authProvider.notifier);
      notifier.toggleView(AuthViewState.signup);
      
      final state = container.read(authProvider);
      expect(state.viewState, AuthViewState.signup);
    });

    test('submitAuth calls signInWithEmail when in login state', () async {
      const email = 'test@example.com';
      const password = 'password123';
      
      when(() => mockAuthService.signInWithEmail(email, password)).thenAnswer((_) async => MockUserCredential());
      
      final notifier = container.read(authProvider.notifier);
      final success = await notifier.submitAuth(email, password);

      expect(success, true);
      verify(() => mockAuthService.signInWithEmail(email, password)).called(1);
    });

    test('auth state changes correctly when user logs in', () async {
      final mockUser = MockUser();
      when(() => mockUser.providerData).thenReturn([]);
      when(() => mockUser.emailVerified).thenReturn(true);
      when(() => mockAuthService.currentUser).thenReturn(mockUser);
      when(() => mockCloudSyncService.initializeSync(any())).thenAnswer((_) async {});
      
      final notifier = container.read(authProvider.notifier);
      expect(notifier.isAuthenticated, true);
    });
  });
}
