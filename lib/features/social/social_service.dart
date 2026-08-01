import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class SocialService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instanceFor(
    app: Firebase.app(), 
    databaseURL: Firebase.app().options.databaseURL,
  );

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

  // Add a friend via Username or Email or UID
  Future<bool> addFriendByQuery(String query) async {
    final user = _auth.currentUser;
    if (user == null || query.isEmpty) return false;
    
    query = query.trim().toLowerCase();
    
    try {
      // If it looks like a UID (length > 20 and no @), try direct UID add
      if (query.length > 20 && !query.contains('@')) {
        return await addFriendByUid(query);
      }
      
      QuerySnapshot snapshot;
      if (query.contains('@') && !query.startsWith('@')) {
        // Looks like an email
        snapshot = await _firestore.collection('users').where('email', isEqualTo: query).limit(1).get();
      } else {
        // Looks like a username
        if (!query.startsWith('@')) query = '@$query';
        snapshot = await _firestore.collection('users').where('username', isEqualTo: query).limit(1).get();
      }

      if (snapshot.docs.isNotEmpty) {
        return await addFriendByUid(snapshot.docs.first.id);
      }
      
      return false; // User not found
    } catch (e) {
      debugPrint("Error finding friend by query: $e");
      return false;
    }
  }

  // Remove a friend
  Future<bool> removeFriend(String friendUid) async {
    final user = _auth.currentUser;
    if (user == null || friendUid.isEmpty) return false;

    try {
      final batch = _firestore.batch();
      
      batch.set(_firestore.collection('users').doc(user.uid), {
        'friends': FieldValue.arrayRemove([friendUid])
      }, SetOptions(merge: true));

      batch.set(_firestore.collection('users').doc(friendUid), {
        'friends': FieldValue.arrayRemove([user.uid])
      }, SetOptions(merge: true));

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint("Error removing friend: $e");
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

  // Set Friend Nickname
  Future<void> setFriendNickname(String friendUid, String nickname) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'friend_names': { friendUid: nickname }
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error setting friend nickname: $e");
    }
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
        'isRead': false,
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

  // Send a playlist to a friend's inbox
  Future<void> sendPlaylist(String friendUid, Map<String, dynamic> playlistJson) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      final myDoc = await _firestore.collection('users').doc(user.uid).get();
      final myName = myDoc.data()?['name'] ?? 'A friend';

      final docRef = _firestore.collection('users').doc(friendUid).collection('inbox').doc();
      await docRef.set({
        'senderId': user.uid,
        'senderName': myName,
        'type': 'playlist',
        'payload': playlistJson,
        'timestamp': FieldValue.serverTimestamp(),
        'reactions': {},
        'isRead': false,
      });

      // Notify the friend
      final notifService = locator<NotificationService>();
      await notifService.notifyFriendsOfRoom(
        [friendUid], 
        myName, 
        'inbox_${docRef.id}' 
      );
    } catch (e) {
      debugPrint("Error sending playlist: $e");
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

  // Delete message
  Future<void> deleteMessage(String messageId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inbox')
        .doc(messageId)
        .delete();
  }

  // Mark message as read
  Future<void> markAsRead(String messageId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inbox')
        .doc(messageId)
        .update({'isRead': true});
  }

  // Get unread count stream
  Stream<int> getUnreadCountStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);
    
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inbox')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // React to a message
  Future<void> reactToMessage(String messageId, String emoji) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final docRef = _firestore.collection('users').doc(user.uid).collection('inbox').doc(messageId);
      final docSnap = await docRef.get();
      
      await docRef.set({
        'reactions': { user.uid: emoji }
      }, SetOptions(merge: true));

      // Share reaction: Send a notification back to the sender
      if (docSnap.exists) {
        final data = docSnap.data()!;
        final senderId = data['senderId'];
        if (senderId != null && senderId != user.uid) {
          final myDoc = await _firestore.collection('users').doc(user.uid).get();
          final myName = myDoc.data()?['name'] ?? 'A friend';
          
          String title = data['type'] == 'playlist' 
              ? (data['payload']['title'] ?? 'Playlist') 
              : (data['payload']['title'] ?? 'Song');

          await _firestore.collection('users').doc(senderId).collection('inbox').add({
            'senderId': user.uid,
            'senderName': myName,
            'type': 'reaction',
            'payload': {
              'emoji': emoji,
              'targetTitle': title,
            },
            'timestamp': FieldValue.serverTimestamp(),
            'reactions': {},
            'isRead': false,
          });
        }
      }

    } catch (e) {
      debugPrint("Error reacting to message: $e");
    }
  }

  // Update real-time presence (what they are listening to)
  Future<void> updatePresence(Song? song, bool isPlaying, {String? roomId}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final presenceRef = _rtdb.ref('presence/${user.uid}');
    
    if (song != null && isPlaying) {
      await presenceRef.set({
        'is_playing': true,
        'song_title': song.title,
        'artist': song.artist,
        'timestamp': ServerValue.timestamp,
        if (roomId != null) 'room_id': roomId,
      });
      presenceRef.onDisconnect().remove();
    } else {
      await presenceRef.remove();
    }
  }

  // Get a friend's presence stream
  Stream<DatabaseEvent> getPresenceStream(String friendUid) {
    return _rtdb.ref('presence/$friendUid').onValue;
  }
}
