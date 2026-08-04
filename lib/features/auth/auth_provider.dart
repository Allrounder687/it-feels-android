import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:it_feels_music/services/auth_service.dart';
import 'package:it_feels_music/services/cloud_sync_service.dart';
import 'package:it_feels_music/services/telemetry_service.dart';
import 'package:it_feels_music/services/backend_api_service.dart';

enum AuthViewState { login, signup, loading, emailVerificationPending, authenticated, forgotPassword }

@immutable
class AuthState {
  final AuthViewState viewState;
  final String email;
  final String errorMessage;

  const AuthState({
    this.viewState = AuthViewState.login,
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
  late final TelemetryService _telemetryService;

  User? get currentUser => _authService.currentUser;
  bool get isAuthenticated => currentUser != null;

  @override
  AuthState build() {
    _authService = locator.isRegistered<AuthService>() ? locator<AuthService>() : AuthService();
    _cloudSyncService = locator.isRegistered<CloudSyncService>() ? locator<CloudSyncService>() : CloudSyncService();
    _telemetryService = locator.isRegistered<TelemetryService>() ? locator<TelemetryService>() : TelemetryService();

    _authService.userStream.listen((user) {
      if (user != null) {
        final isPasswordProvider = (user.providerData ?? []).any((info) => info.providerId == 'password');
        if (isPasswordProvider && !user.emailVerified) {
          state = state.copyWith(viewState: AuthViewState.emailVerificationPending);
        } else {
          state = state.copyWith(viewState: AuthViewState.authenticated);
        }
        // Zero Cognitive Overload: Start essential services immediately regardless of verification
        _cloudSyncService.initializeSync(user);
        _telemetryService.startTracking(user);
      } else {
        state = state.copyWith(viewState: AuthViewState.login);
        _cloudSyncService.stopSync();
        _telemetryService.stopTracking();
        // Automatically sign in anonymously if no user is present (Guest mode)
        try {
          _authService.signInAnonymously();
        } catch (e) {
          debugPrint('Anonymous sign-in failed: $e');
        }
      }
    });

    return const AuthState();
  }

  void resetFlow() {
    if (!isAuthenticated || (currentUser?.isAnonymous ?? false)) {
      state = state.copyWith(
        viewState: AuthViewState.login,
        email: '',
        errorMessage: '',
      );
    }
  }
  
  void toggleView(AuthViewState newState) {
    state = state.copyWith(viewState: newState, errorMessage: '');
  }

  Future<bool> submitAuth(String email, String password) async {
    if (email.isEmpty || !email.contains('@')) {
      state = state.copyWith(errorMessage: 'Please enter a valid email');
      return false;
    }
    if (password.length < 6) {
      state = state.copyWith(errorMessage: 'Password must be at least 6 characters');
      return false;
    }

    final previousState = state.viewState;
    state = state.copyWith(viewState: AuthViewState.loading, errorMessage: '');

    try {
      if (previousState == AuthViewState.signup) {
        await _authService.signUpWithEmail(email, password);
      } else {
        await _authService.signInWithEmail(email, password);
      }
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        state = state.copyWith(
          errorMessage: 'Email is already registered. Please log in.',
          viewState: AuthViewState.login,
        );
      } else if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password' || e.code == 'internal-error') {
        state = state.copyWith(
          errorMessage: 'Invalid email or password.',
          viewState: previousState,
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

  Future<void> submitForgotPassword(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      state = state.copyWith(errorMessage: 'Please enter a valid email');
      return;
    }
    
    state = state.copyWith(viewState: AuthViewState.loading, errorMessage: '');
    try {
      await _authService.sendPasswordReset(email);
      state = state.copyWith(
        viewState: AuthViewState.login,
        errorMessage: 'Password reset link sent to $email.',
      );
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        viewState: AuthViewState.forgotPassword,
        errorMessage: e.message ?? 'Failed to send reset link (${e.code}).',
      );
    } catch (e) {
      state = state.copyWith(
        viewState: AuthViewState.forgotPassword,
        errorMessage: 'Failed to send reset link: ${e.toString().replaceAll('Exception: ', '')}',
      );
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
      debugPrint("FirebaseAuthException in Google Sign-In: ${e.code} - ${e.message}");
      state = state.copyWith(
        errorMessage: e.message ?? 'Google Sign-In failed (${e.code})',
        viewState: previousState,
      );
      return false;
    } catch (e) {
      debugPrint("Google Sign In Exception: $e");
      final str = e.toString();
      String cleanMsg;
      if (str.contains('10:') || str.contains('DEVELOPER_ERROR')) {
        cleanMsg = 'Google Sign-In configuration error (ApiException 10). Your SHA-1 key must be registered in Firebase Console for package com.itfeels.music.';
      } else if (str.contains('12500')) {
        cleanMsg = 'Google Sign-In failed (ApiException 12500). Check Google Play Services.';
      } else if (str.contains('PlatformException')) {
        cleanMsg = 'Google Sign-In failed ($str). Check Firebase Console SHA-1 configuration.';
      } else {
        cleanMsg = str.replaceAll('Exception: ', '');
      }
      state = state.copyWith(
        errorMessage: cleanMsg,
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
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthNotifier] checkVerificationStatus Firebase error: ${e.code} - ${e.message}');
      state = state.copyWith(errorMessage: e.message ?? 'Failed to check verification status.');
    } catch (e) {
      debugPrint('[AuthNotifier] checkVerificationStatus error: $e');
      state = state.copyWith(errorMessage: 'Failed to check verification status.');
    }
  }

  Future<void> resendVerificationEmail() async {
    try {
      await _authService.resendVerificationEmail();
      state = state.copyWith(errorMessage: 'Verification email resent successfully!');
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthNotifier] resendVerificationEmail Firebase error: ${e.code} - ${e.message}');
      if (e.code == 'too-many-requests') {
        state = state.copyWith(errorMessage: 'Too many requests. Please wait a minute before requesting another link.');
      } else {
        state = state.copyWith(errorMessage: e.message ?? 'Failed to send verification email.');
      }
    } catch (e) {
      debugPrint('[AuthNotifier] resendVerificationEmail error: $e');
      state = state.copyWith(errorMessage: 'Failed to send verification email.');
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}

typedef AuthProvider = AuthNotifier;
