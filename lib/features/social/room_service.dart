import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoomService {
  final FirebaseDatabase _rtdb;

  RoomService({FirebaseDatabase? rtdb}) : _rtdb = rtdb ?? FirebaseDatabase.instanceFor(
    app: Firebase.app(), 
    databaseURL: Firebase.app().options.databaseURL,
  );
  
  // Create a new Listen Together Room
  Future<String> createRoom(String hostId, Song currentSong, Duration position, bool isPlaying, {bool isPublic = false}) async {
    final roomId = _generateRoomCode();
    final roomRef = _rtdb.ref('rooms/$roomId');
    await roomRef.keepSynced(true);
    
    await roomRef.set({
      'hostId': hostId,
      'isPublic': isPublic,
      'songId': currentSong.id,
      'saavnId': currentSong.saavnId,
      'title': currentSong.title,
      'artist': currentSong.artist,
      'coverArt': currentSong.coverArt,
      'positionMs': position.inMilliseconds,
      'isPlaying': isPlaying,
      'timestamp': ServerValue.timestamp,
    }).timeout(const Duration(seconds: 10));
    
    // Auto-cleanup on disconnect
    roomRef.onDisconnect().remove();
    return roomId;
  }

  // Update room state (only called by host)
  Future<void> updateRoomState(String roomId, Song currentSong, Duration position, bool isPlaying) async {
    final roomRef = _rtdb.ref('rooms/$roomId');
    await roomRef.update({
      'songId': currentSong.id,
      'saavnId': currentSong.saavnId,
      'title': currentSong.title,
      'artist': currentSong.artist,
      'coverArt': currentSong.coverArt,
      'positionMs': position.inMilliseconds,
      'isPlaying': isPlaying,
      'timestamp': ServerValue.timestamp,
    }).timeout(const Duration(seconds: 10));
  }

  // Listen to room state (called by guests)
  Stream<DatabaseEvent> listenToRoom(String roomId) {
    final ref = _rtdb.ref('rooms/$roomId');
    ref.keepSynced(true);
    return ref.onValue;
  }

  // Get public rooms
  Stream<DatabaseEvent> getPublicRooms() {
    return _rtdb.ref('rooms').orderByChild('isPublic').equalTo(true).onValue;
  }

  // End room
  Future<void> endRoom(String roomId) async {
    await _rtdb.ref('rooms/$roomId').remove();
  }

  // Request to join a room
  Future<void> requestJoinRoom(String roomId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final firestore = FirebaseFirestore.instance;
    final myDoc = await firestore.collection('users').doc(user.uid).get();
    final myName = myDoc.data()?['name'] ?? 'A friend';
    
    await _rtdb.ref('rooms/$roomId/join_requests/${user.uid}').set({
      'name': myName,
      'timestamp': ServerValue.timestamp,
    });
  }

  // Host listens to join requests
  Stream<DatabaseEvent> listenToJoinRequests(String roomId) {
    return _rtdb.ref('rooms/$roomId/join_requests').onChildAdded;
  }

  // Accept join request
  Future<void> acceptJoinRequest(String roomId, String guestId) async {
    await _rtdb.ref('rooms/$roomId/allowed_guests/$guestId').set(true);
    await _rtdb.ref('rooms/$roomId/join_requests/$guestId').remove();
  }

  // Decline join request
  Future<void> declineJoinRequest(String roomId, String guestId) async {
    await _rtdb.ref('rooms/$roomId/join_requests/$guestId').remove();
  }

  // Add song to collaborative Jam Queue
  Future<void> addSongToJamQueue(String roomId, Song song, String addedBy) async {
    final queueRef = _rtdb.ref('rooms/$roomId/queue').push();
    await queueRef.set({
      'songId': song.id,
      'saavnId': song.saavnId,
      'title': song.title,
      'artist': song.artist,
      'coverArt': song.coverArt,
      'addedBy': addedBy,
      'timestamp': ServerValue.timestamp,
    });
  }

  // Listen to Jam Queue additions
  Stream<DatabaseEvent> jamQueueStream(String roomId) {
    return _rtdb.ref('rooms/$roomId/queue').orderByChild('timestamp').onChildAdded;
  }


  // Guest listens to allowed status
  Stream<DatabaseEvent> listenToAllowedStatus(String roomId, String guestId) {
    return _rtdb.ref('rooms/$roomId/allowed_guests/$guestId').onValue;
  }

  // Generate a random 6 digit numeric code
  String _generateRoomCode() {
    final rand = Random();
    int code = rand.nextInt(900000) + 100000;
    return code.toString();
  }

  // Deep Link Auto-Friending: Magically adds both users as friends
  Future<void> autoFriend(String hostId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == hostId) return;
    
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    
    final myDoc = firestore.collection('users').doc(currentUser.uid);
    final hostDoc = firestore.collection('users').doc(hostId);
    
    batch.set(myDoc, {
      'friends': FieldValue.arrayUnion([hostId])
    }, SetOptions(merge: true));
    
    batch.set(hostDoc, {
      'friends': FieldValue.arrayUnion([currentUser.uid])
    }, SetOptions(merge: true));
    
    try {
      await batch.commit();
    } catch (e) {
      // Silently fail if permissions prevent cross-writes, though zero-cog implies open rules for friends array
    }
  }
}
