import 'dart:async';
import 'package:flutter/material.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/features/social/room_service.dart';
import 'package:it_feels_music/features/social/social_service.dart';
import 'package:it_feels_music/services/notification_service.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:it_feels_music/data/services/audio_engine_service.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/main.dart';

class ListenTogetherService {
  final RoomService _roomService = locator<RoomService>();
  final SocialService _socialService = locator<SocialService>();
  final NotificationService _notifService = locator<NotificationService>();
  
  StreamSubscription? _roomSubscription;
  StreamSubscription? _joinRequestSubscription;
  StreamSubscription? _offsetSubscription;
  
  String? currentRoomId;
  bool isHost = false;
  int _serverTimeOffset = 0;

  final FirebaseDatabase _database;
  FirebaseFirestore get _firestore => locator.isRegistered<FirebaseFirestore>() ? locator<FirebaseFirestore>() : FirebaseFirestore.instance;

  ListenTogetherService({FirebaseDatabase? database}) : _database = database ?? FirebaseDatabase.instance {
    _offsetSubscription = _database.ref('.info/serverTimeOffset').onValue.listen((event) {
      _serverTimeOffset = (event.snapshot.value as int?) ?? 0;
    });
  }

  int get estimatedServerTime => DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;

  void dispose() {
    _roomSubscription?.cancel();
    _joinRequestSubscription?.cancel();
    _offsetSubscription?.cancel();
  }

  Future<String?> startBroadcasting(String uid, Song currentSong, Duration position, bool isPlaying, bool isPremium, {String? streamUrl}) async {
    final roomId = await _roomService.createRoom(
      uid, 
      currentSong, 
      position, 
      isPlaying, 
      isPublic: isPremium, 
      allowGuestControl: true,
      streamUrl: streamUrl,
      timestamp: estimatedServerTime,
    );
    
    currentRoomId = roomId;
    isHost = true;
    _socialService.updatePresence(currentSong, isPlaying, roomId: roomId);
    
    // Zero-cognitive load friending: Notify all friends
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final friends = List<String>.from(data['friends'] ?? []);
        final myName = data['name'] ?? 'Your friend';
        if (friends.isNotEmpty) {
          await _notifService.notifyFriendsOfRoom(friends, myName, roomId);
        }
      }
    } catch (e) {
      debugPrint("Error fetching friends to notify: $e");
    }
    
    // Listen for join requests
    _joinRequestSubscription?.cancel();
    _joinRequestSubscription = _roomService.listenToJoinRequests(roomId).listen((event) {
      if (event.snapshot.value != null) {
        final guestId = event.snapshot.key!;
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final guestName = data['name'] ?? 'Someone';
        
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('$guestName wants to join your room!', style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.midnightPrimary,
            duration: const Duration(seconds: 10),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: 'Accept',
              textColor: Colors.white,
              onPressed: () {
                _roomService.acceptJoinRequest(roomId, guestId);
              },
            ),
          ),
        );
      }
    });

    return roomId;
  }

  Future<void> joinSession(String roomId) async {
    currentRoomId = roomId;
    isHost = false;
    final engine = locator<AudioEngineService>();
    
    _roomSubscription?.cancel();
    _roomSubscription = _roomService.listenToRoom(roomId).listen((event) async {
      if (event.snapshot.value == null) {
        leaveSession();
        return;
      }
      
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final hostId = data['hostId']?.toString();
      if (hostId != null) {
        _roomService.autoFriend(hostId);
      }
      
      final songId = data['songId']?.toString();
      final isPlaying = data['isPlaying'] as bool? ?? false;
      final positionMs = data['positionMs'] as int? ?? 0;
      
      final currentSong = engine.currentSong;
      
      if (songId != null && (currentSong == null || currentSong.id != songId)) {
        // Need to play new song, tell the Notifier/Engine!
        // We will just use the dummy for now, or let the engine figure it out
        final dummy = Song(
          id: songId, 
          saavnId: data['saavnId'] ?? songId,
          title: data['title'] ?? 'Host Track', 
          artist: data['artist'] ?? 'Unknown',
          album: data['coverArt'] ?? 'Unknown',
          coverArt: data['coverArt'] ?? '', 
          duration: 0, 
          addedAt: DateTime.now()
        );
        appProviderContainer.read(audioPlayerProvider.notifier).playSong(dummy, predefinedStreamUrl: data['streamUrl']); 
      }
      
      final timestamp = data['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
      final elapsedMs = isPlaying ? (estimatedServerTime - timestamp) : 0;
      // Clamp elapsed time to a reasonable bounds (e.g. max 10 seconds latency compensation)
      final safeElapsedMs = elapsedMs > 0 && elapsedMs < 10000 ? elapsedMs : 0;
      final targetPositionMs = positionMs + safeElapsedMs;
      
      final diff = (engine.position.inMilliseconds - targetPositionMs).abs();
      if (diff > 500) {
        await engine.seek(Duration(milliseconds: targetPositionMs));
      }
      
      if (isPlaying != engine.isPlaying) {
        if (isPlaying) {
          await engine.play();
        } else {
          await engine.pause();
        }
      }
    });
  }

  void leaveSession() {
    if (isHost && currentRoomId != null) {
      _roomService.endRoom(currentRoomId!);
    }
    _roomSubscription?.cancel();
    _joinRequestSubscription?.cancel();
    currentRoomId = null;
    isHost = false;
  }
  
  void updatePresence(Song? song, bool isPlaying) {
    _socialService.updatePresence(song, isPlaying, roomId: currentRoomId);
  }
  
  void updateRoomState(Song song, Duration position, bool isPlaying, {String? streamUrl}) {
    if (currentRoomId != null && isHost) {
      _roomService.updateRoomState(currentRoomId!, song, position, isPlaying, streamUrl: streamUrl, timestamp: estimatedServerTime);
    }
  }
}
