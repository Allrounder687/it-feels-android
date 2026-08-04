import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  // Get current user stream
  Stream<User?> get userStream => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  late final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Sign In Anonymously
  Future<UserCredential?> signInAnonymously() async {
    try {
      final cred = await _auth.signInAnonymously();
      if (cred.user != null) {
        await _syncUserToFirestore(cred.user!);
      }
      return cred;
    } catch (e) {
      debugPrint('[AuthService] Anonymous sign-in disabled in Firebase Console: $e');
      return null;
    }
  }

  // Sign In with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User canceled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await _auth.signInWithCredential(credential);
      if (cred.user != null) {
        await _syncUserToFirestore(cred.user!);
      }
      return cred;
    } catch (e) {
      rethrow;
    }
  }
  // Sign In
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (cred.user != null) {
        await _syncUserToFirestore(cred.user!);
      }
      return cred;
    } catch (e) {
      rethrow;
    }
  }

  // Sign Up
  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null && !credential.user!.emailVerified) {
        await credential.user!.sendEmailVerification();
      }
      if (credential.user != null) {
        await _syncUserToFirestore(credential.user!);
      }
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  // Reload current user to update emailVerified status
  Future<void> reloadUser() async {
    if (_auth.currentUser != null) {
      await _auth.currentUser!.reload();
    }
  }

  // Resend Verification Email
  Future<void> resendVerificationEmail() async {
    if (_auth.currentUser != null && !_auth.currentUser!.emailVerified) {
      await _auth.currentUser!.sendEmailVerification();
      debugPrint('[AuthService] Verification email sent successfully to: ${_auth.currentUser!.email}');
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Send Password Reset
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> _syncUserToFirestore(User user) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snapshot = await docRef.get();
      
      if (!snapshot.exists) {
        // Auto-generate a default username based on email
        String baseName = user.isAnonymous ? 'guest' : (user.email?.split('@')[0] ?? 'user');
        String generatedUsername = '@${baseName}_${user.uid.substring(0, 4)}'.toLowerCase();
        
        await docRef.set({
          'email': user.isAnonymous ? 'Guest User' : user.email,
          'uid': user.uid,
          'username': generatedUsername,
          'isAnonymous': user.isAnonymous,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
          'totalUsageSeconds': 0,
          'isBanned': false,
        });
      } else {
        // Generate a username for existing users if they don't have one
        Map<String, dynamic> data = snapshot.data() ?? {};
        if (!data.containsKey('username')) {
          String baseName = user.isAnonymous ? 'guest' : (user.email?.split('@')[0] ?? 'user');
          String generatedUsername = '@${baseName}_${user.uid.substring(0, 4)}'.toLowerCase();
          await docRef.update({
            'username': generatedUsername,
            'email': user.isAnonymous ? 'Guest User' : user.email,
            'isAnonymous': user.isAnonymous,
            'lastLogin': FieldValue.serverTimestamp(),
          });
        } else {
          await docRef.update({
            'email': user.isAnonymous ? 'Guest User' : user.email,
            'isAnonymous': user.isAnonymous,
            'lastLogin': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error syncing user to Firestore: $e');
    }
  }
}
