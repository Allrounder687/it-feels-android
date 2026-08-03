import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages here if needed
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initialize() async {
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) return;

    // Request permissions
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission for notifications');
      await _saveTokenToDatabase();

      // Auto-subscribe to global announcements for zero-cognitive-load push marketing
      try {
        await _messaging.subscribeToTopic('global_announcements');
        
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _messaging.subscribeToTopic('friend_updates_${user.uid}');
        }
        debugPrint('Subscribed to push topics');
      } catch (e) {
        debugPrint('Failed to subscribe to topic: $e');
      }

      // Listen for token refreshes
      _messaging.onTokenRefresh.listen((token) async {
        await _updateToken(token);
      });
    }

    // Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');
      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
      }
    });

    // Background message handler registration
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  Future<void> _saveTokenToDatabase() async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await _updateToken(token);
      }
    } catch (e) {
      debugPrint("Failed to get FCM token: $e");
    }
  }

  Future<void> _updateToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'fcmTokens': FieldValue.arrayUnion([token])
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("Failed to save FCM token to Firestore: $e");
      }
    }
  }

  // Writes to a push queue. A simple Firebase Function can process this queue and send FCM.
  Future<void> notifyFriendsOfRoom(List<String> friendIds, String hostName, String roomId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || friendIds.isEmpty) return;

      final batch = _firestore.batch();
      for (final friendId in friendIds) {
        final docRef = _firestore.collection('push_queue').doc();
        batch.set(docRef, {
          'topic': 'friend_updates_$friendId',
          'title': '🎵 Listen Together',
          'body': '$hostName just started a Listen Together room! Tap to join.',
          'data': {
            'action': 'join_room',
            'roomId': roomId,
          },
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending'
        });
      }
      await batch.commit();
      debugPrint("Queued push notifications for ${friendIds.length} friends.");
    } catch (e) {
      debugPrint("Failed to notify friends: $e");
    }
  }
}
