import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';

enum AuthViewState { emailInput, loginPassword, signupPassword, loading, authenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final CloudSyncService _cloudSyncService;
  
  AuthViewState _viewState = AuthViewState.emailInput;
  String _email = '';
  String _errorMessage = '';

  AuthViewState get viewState => _viewState;
  String get email => _email;
  String get errorMessage => _errorMessage;
  User? get currentUser => _authService.currentUser;
  bool get isAuthenticated => currentUser != null;

  AuthProvider({AuthService? authService, CloudSyncService? cloudSyncService}) 
      : _authService = authService ?? AuthService(),
        _cloudSyncService = cloudSyncService ?? CloudSyncService() {
    _authService.userStream.listen((user) {
      if (user != null) {
        _viewState = AuthViewState.authenticated;
        _cloudSyncService.initializeSync(user);
      } else {
        _viewState = AuthViewState.emailInput;
        _cloudSyncService.stopSync();
      }
      notifyListeners();
    });
  }

  void resetFlow() {
    if (!isAuthenticated) {
      _viewState = AuthViewState.emailInput;
      _email = '';
      _errorMessage = '';
      notifyListeners();
    }
  }

  Future<void> submitEmail(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      _errorMessage = 'Please enter a valid email';
      notifyListeners();
      return;
    }
    
    _email = email;
    _errorMessage = '';
    _viewState = AuthViewState.loginPassword;
    notifyListeners();
  }

  Future<bool> submitPassword(String password) async {
    if (password.length < 6) {
      _errorMessage = 'Password must be at least 6 characters';
      notifyListeners();
      return false;
    }

    final previousState = _viewState;
    _viewState = AuthViewState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      if (previousState == AuthViewState.signupPassword) {
        // They explicitly clicked "Create Account"
        await _authService.signUpWithEmail(_email, password);
      } else {
        // Try logging in first
        await _authService.signInWithEmail(_email, password);
      }
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        // User doesn't exist (or wrong password, but due to anti-enumeration, Firebase might return invalid-credential for both)
        // We will offer them to sign up.
        _errorMessage = 'Account not found. Click "Create Account" to register.';
        _viewState = AuthViewState.signupPassword;
      } else if (e.code == 'wrong-password') {
        _errorMessage = 'Incorrect password.';
        _viewState = AuthViewState.loginPassword;
      } else {
        _errorMessage = e.message ?? 'Authentication failed';
        _viewState = previousState;
      }
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred';
      _viewState = previousState;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    final previousState = _viewState;
    _viewState = AuthViewState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null) {
        // User canceled the login
        _viewState = previousState;
        notifyListeners();
        return false;
      }
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Google Sign-In failed';
      _viewState = previousState;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred';
      _viewState = previousState;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}
