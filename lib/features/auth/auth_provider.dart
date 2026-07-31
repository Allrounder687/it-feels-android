import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:it_feels_music/services/auth_service.dart';
import 'package:it_feels_music/services/cloud_sync_service.dart';
import 'package:it_feels_music/services/backend_api_service.dart';

enum AuthViewState { emailInput, loginPassword, signupPassword, loading, emailVerificationPending, authenticated }

@immutable
class AuthState {
  final AuthViewState viewState;
  final String email;
  final String errorMessage;

  const AuthState({
    this.viewState = AuthViewState.emailInput,
    this.email = '',
    this.errorMessage = '',
  });

  User? get currentUser { try { return FirebaseAuth.instance.currentUser; } catch (_) { return null; } }
  bool get isAuthenticated => currentUser != null;

  AuthState copyWith({
    AuthViewState? viewState,
    String? email,
    String? errorMessage,
  }) {
    return AuthState(
      viewState: viewState ?? this.viewState,
      email: email ?? this.email,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthService _authService;
  late final CloudSyncService _cloudSyncService;

  User? get currentUser => _authService.currentUser;
  bool get isAuthenticated => currentUser != null;

  @override
  AuthState build() {
    _authService = locator.isRegistered<AuthService>() ? locator<AuthService>() : AuthService();
    _cloudSyncService = locator.isRegistered<CloudSyncService>() ? locator<CloudSyncService>() : CloudSyncService();

    _authService.userStream.listen((user) {
      if (user != null) {
        final isPasswordProvider = user.providerData.any((info) => info.providerId == 'password');
        if (isPasswordProvider && !user.emailVerified) {
          state = state.copyWith(viewState: AuthViewState.emailVerificationPending);
          _cloudSyncService.stopSync();
        } else {
          state = state.copyWith(viewState: AuthViewState.authenticated);
          _cloudSyncService.initializeSync(user);
        }
      } else {
        state = state.copyWith(viewState: AuthViewState.emailInput);
        _cloudSyncService.stopSync();
      }
    });

    return const AuthState();
  }

  void resetFlow() {
    if (!isAuthenticated) {
      state = state.copyWith(
        viewState: AuthViewState.emailInput,
        email: '',
        errorMessage: '',
      );
    }
  }

  Future<void> submitEmail(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      state = state.copyWith(errorMessage: 'Please enter a valid email');
      return;
    }
    
    state = state.copyWith(
      email: email,
      errorMessage: '',
      viewState: AuthViewState.loginPassword,
    );
  }

  Future<bool> submitPassword(String password) async {
    if (password.length < 6) {
      state = state.copyWith(errorMessage: 'Password must be at least 6 characters');
      return false;
    }

    final previousState = state.viewState;
    state = state.copyWith(viewState: AuthViewState.loading, errorMessage: '');

    try {
      if (previousState == AuthViewState.signupPassword) {
        await _authService.signUpWithEmail(state.email, password);
      } else {
        await _authService.signInWithEmail(state.email, password);
      }
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        state = state.copyWith(
          errorMessage: 'Account not found. Click "Create Account" to register.',
          viewState: AuthViewState.signupPassword,
        );
      } else if (e.code == 'wrong-password') {
        state = state.copyWith(
          errorMessage: 'Incorrect password.',
          viewState: AuthViewState.loginPassword,
        );
      } else {
        state = state.copyWith(
          errorMessage: e.message ?? 'Authentication failed',
          viewState: previousState,
        );
      }
      return false;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'An unexpected error occurred',
        viewState: previousState,
      );
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    final previousState = state.viewState;
    state = state.copyWith(viewState: AuthViewState.loading, errorMessage: '');

    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null) {
        state = state.copyWith(viewState: previousState);
        return false;
      }
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        errorMessage: e.message ?? 'Google Sign-In failed',
        viewState: previousState,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'An unexpected error occurred',
        viewState: previousState,
      );
      return false;
    }
  }

  Future<void> checkVerificationStatus() async {
    try {
      await _authService.reloadUser();
      final user = _authService.currentUser;
      if (user != null && user.emailVerified) {
        state = state.copyWith(viewState: AuthViewState.authenticated);
        _cloudSyncService.initializeSync(user);
        if (user.email != null) {
          BackendApiService.sendWelcomeEmail(user.email!);
        }
      } else {
        state = state.copyWith(errorMessage: 'Email not verified yet. Please check your inbox.');
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to check verification status.');
    }
  }

  Future<void> resendVerificationEmail() async {
    try {
      await _authService.resendVerificationEmail();
      state = state.copyWith(errorMessage: 'Verification email resent successfully!');
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to resend verification email. Please try again later.');
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}

typedef AuthProvider = AuthNotifier;
