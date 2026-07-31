import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/services/notification_service.dart';

class SocialService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Manually add a friend via UID
  Future<bool> addFriendByUid(String friendUid) async {
    final user = _auth.currentUser;
    if (user == null || user.uid == friendUid) return false;

    try {
      final friendDoc = await _firestore.collection('users').doc(friendUid).get();
      if (!friendDoc.exists) return false; // Invalid UID

      final batch = _firestore.batch();
      
      batch.set(_firestore.collection('users').doc(user.uid), {
        'friends': FieldValue.arrayUnion([friendUid])
      }, SetOptions(merge: true));
      
      batch.set(_firestore.collection('users').doc(friendUid), {
        'friends': FieldValue.arrayUnion([user.uid])
      }, SetOptions(merge: true));
      
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint("Error adding friend: $e");
      return false;
    }
  }

  // Get friends list stream
  Stream<DocumentSnapshot> getFriendsStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _firestore.collection('users').doc(user.uid).snapshots();
  }

  // Fetch friend details
  Future<Map<String, dynamic>?> getFriendDetails(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) return doc.data();
    } catch (e) {
      debugPrint("Error getting friend details: $e");
    }
    return null;
  }

  // Send a song to a friend's inbox
  Future<void> sendSong(String friendUid, Song song) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      final myDoc = await _firestore.collection('users').doc(user.uid).get();
      final myName = myDoc.data()?['name'] ?? 'A friend';

      final docRef = _firestore.collection('users').doc(friendUid).collection('inbox').doc();
      await docRef.set({
        'senderId': user.uid,
        'senderName': myName,
        'type': 'song',
        'payload': song.toJson(),
        'timestamp': FieldValue.serverTimestamp(),
        'reactions': {},
      });

      // Notify the friend
      final notifService = locator<NotificationService>();
      await notifService.notifyFriendsOfRoom(
        [friendUid], 
        myName, 
        'inbox_${docRef.id}' 
      );
    } catch (e) {
      debugPrint("Error sending song: $e");
    }
  }

  // Listen to inbox
  Stream<QuerySnapshot> getInboxStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inbox')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // React to an inbox message
  Future<void> reactToMessage(String messageId, String emoji) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('inbox')
          .doc(messageId)
          .set({
            'reactions': { user.uid: emoji }
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error reacting to message: $e");
    }
  }
}
