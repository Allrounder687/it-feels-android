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
  
  // Create a new Listen Together Room (Audio)
  Future<String> createRoom(String hostId, Song currentSong, Duration position, bool isPlaying, {bool isPublic = false, bool allowGuestControl = false, String? streamUrl, int? timestamp}) async {
    final roomId = _generateRoomCode();
    final roomRef = _rtdb.ref('rooms/$roomId');
    await roomRef.keepSynced(true);
    
    await roomRef.set({
      'type': 'audio',
      'hostId': hostId,
      'isPublic': isPublic,
      'allowGuestControl': allowGuestControl,
      'songId': currentSong.id,
      'saavnId': currentSong.saavnId,
      'title': currentSong.title,
      'artist': currentSong.artist,
      'coverArt': currentSong.coverArt,
      'streamUrl': streamUrl,
      'positionMs': position.inMilliseconds,
      'isPlaying': isPlaying,
      'timestamp': timestamp ?? ServerValue.timestamp,
    }).timeout(const Duration(seconds: 10));
    
    // Auto-cleanup on disconnect
    roomRef.onDisconnect().remove();
    return roomId;
  }

  // Update room state (only called by host)
  Future<void> updateRoomState(String roomId, Song currentSong, Duration position, bool isPlaying, {String? streamUrl, int? timestamp}) async {
    final roomRef = _rtdb.ref('rooms/$roomId');
    await roomRef.update({
      'type': 'audio',
      'songId': currentSong.id,
      'saavnId': currentSong.saavnId,
      'title': currentSong.title,
      'artist': currentSong.artist,
      'coverArt': currentSong.coverArt,
      'streamUrl': streamUrl,
      'positionMs': position.inMilliseconds,
      'isPlaying': isPlaying,
      'timestamp': timestamp ?? ServerValue.timestamp,
    }).timeout(const Duration(seconds: 10));
  }

  // Create a new Listen Together Room (Video)
  Future<String> createVideoRoom(String hostId, Map<String, dynamic> videoDetails, Duration position, bool isPlaying, {bool isPublic = false, bool allowGuestControl = false}) async {
    final roomId = _generateRoomCode();
    final roomRef = _rtdb.ref('rooms/$roomId');
    await roomRef.keepSynced(true);
    
    await roomRef.set({
      'type': 'video',
      'hostId': hostId,
      'isPublic': isPublic,
      'allowGuestControl': allowGuestControl,
      'videoId': videoDetails['id'] ?? '',
      'title': videoDetails['title'] ?? 'Unknown Video',
      'uploader': videoDetails['uploader'] ?? 'YouTube',
      'thumbnail': videoDetails['thumbnail'] ?? '',
      'positionMs': position.inMilliseconds,
      'isPlaying': isPlaying,
      'timestamp': ServerValue.timestamp,
    }).timeout(const Duration(seconds: 10));
    
    roomRef.onDisconnect().remove();
    return roomId;
  }

  // Update room state for video (called by host or allowed guest)
  Future<void> updateVideoRoomState(String roomId, Map<String, dynamic> videoDetails, Duration position, bool isPlaying) async {
    final roomRef = _rtdb.ref('rooms/$roomId');
    await roomRef.update({
      'type': 'video',
      'videoId': videoDetails['id'] ?? '',
      'title': videoDetails['title'] ?? 'Unknown Video',
      'uploader': videoDetails['uploader'] ?? 'YouTube',
      'thumbnail': videoDetails['thumbnail'] ?? '',
      'positionMs': position.inMilliseconds,
      'isPlaying': isPlaying,
      'timestamp': ServerValue.timestamp,
    }).timeout(const Duration(seconds: 10));
  }

  // Toggle guest control
  Future<void> setGuestControl(String roomId, bool allow) async {
    await _rtdb.ref('rooms/$roomId').update({
      'allowGuestControl': allow,
    });
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
