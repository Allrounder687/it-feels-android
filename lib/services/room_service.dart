import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../data/models/song_model.dart';

class RoomService {
  final FirebaseDatabase _rtdb;

  RoomService({FirebaseDatabase? rtdb}) : _rtdb = rtdb ?? FirebaseDatabase.instance;
  
  // Create a new Listen Together Room
  Future<String> createRoom(String hostId, Song currentSong, Duration position, bool isPlaying) async {
    final roomId = _generateRoomCode();
    final roomRef = _rtdb.ref('rooms/$roomId');
    
    await roomRef.set({
      'hostId': hostId,
      'songId': currentSong.id,
      'saavnId': currentSong.saavnId,
      'title': currentSong.title,
      'artist': currentSong.artist,
      'coverArt': currentSong.coverArt,
      'positionMs': position.inMilliseconds,
      'isPlaying': isPlaying,
      'timestamp': ServerValue.timestamp,
    });
    
    // Auto-cleanup on disconnect
    roomRef.onDisconnect().remove();
    return roomId;
  }

  // Update room state (only called by host)
  Future<void> updateRoomState(String roomId, String songId, Duration position, bool isPlaying) async {
    final roomRef = _rtdb.ref('rooms/$roomId');
    await roomRef.update({
      'songId': songId,
      'positionMs': position.inMilliseconds,
      'isPlaying': isPlaying,
      'timestamp': ServerValue.timestamp,
    });
  }

  // Listen to room state (called by guests)
  Stream<DatabaseEvent> listenToRoom(String roomId) {
    return _rtdb.ref('rooms/$roomId').onValue;
  }

  // End room
  Future<void> endRoom(String roomId) async {
    await _rtdb.ref('rooms/$roomId').remove();
  }

  // Generate a random 6 digit numeric code
  String _generateRoomCode() {
    final rand = Random();
    int code = rand.nextInt(900000) + 100000;
    return code.toString();
  }
}
