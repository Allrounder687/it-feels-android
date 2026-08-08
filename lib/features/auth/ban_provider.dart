import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

class BanState {
  final bool isBanned;
  const BanState({this.isBanned = false});
}

class BanNotifier extends Notifier<BanState> {
  StreamSubscription<DocumentSnapshot>? _subscription;

  @override
  BanState build() {
    _listenToAuth();
    
    ref.onDispose(() {
      _subscription?.cancel();
    });
    
    return const BanState();
  }

  void _listenToAuth() {
    ref.listen(authProvider, (previous, next) {
      if (next.isAuthenticated && next.currentUser != null) {
        _startListening(next.currentUser!.uid);
      } else {
        _stopListening();
      }
    }, fireImmediately: true);
  }

  void _startListening(String uid) {
    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        final isBanned = data?['isBanned'] ?? false;
        if (state.isBanned != isBanned) {
          state = BanState(isBanned: isBanned);
        }
      }
    });
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
    state = const BanState(isBanned: false);
  }
}
