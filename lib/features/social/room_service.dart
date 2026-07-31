import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:firebase_core/firebase_core.dart';

class RoomService {
  final FirebaseDatabase _rtdb;

  RoomService({FirebaseDatabase? rtdb}) : _rtdb = rtdb ?? FirebaseDatabase.instanceFor(
    app: Firebase.app(), 
    databaseURL: Firebase.app().options.databaseURL,
  );
  
  // Create a new Listen Together Room
  Future<String> createRoom(String hostId, Song currentSong, Duration position, bool isPlaying) async {
    final roomId = _generateRoomCode();
    final roomRef = _rtdb.ref('rooms/$roomId');
    await roomRef.keepSynced(true);
    
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
    }).timeout(const Duration(seconds: 10));
    
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
    }).timeout(const Duration(seconds: 10));
  }

  // Listen to room state (called by guests)
  Stream<DatabaseEvent> listenToRoom(String roomId) {
    final ref = _rtdb.ref('rooms/$roomId');
    ref.keepSynced(true);
    return ref.onValue;
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
