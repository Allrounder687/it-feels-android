import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'database_service.dart';

class CloudSyncService {
  final FirebaseFirestore _firestore;
  final DatabaseService _dbService;
  StreamSubscription? _favoritesSubscription;

  CloudSyncService({FirebaseFirestore? firestore, DatabaseService? dbService}) 
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _dbService = dbService ?? DatabaseService();

  // Initialize Sync Listeners if user is logged in
  void initializeSync(User user) {
    _startFavoritesListener(user.uid);
    // Trigger initial push to merge any local offline changes to the cloud
    pushLocalFavoritesToCloud(user.uid);
  }

  void stopSync() {
    _favoritesSubscription?.cancel();
  }

  // ----------------------------------------------------
  // Push (Local -> Cloud)
  // ----------------------------------------------------
  Future<void> pushLocalFavoritesToCloud(String uid) async {
    try {
      final localFavorites = await _dbService.getAllFavorites();
      
      // Batch write to Firestore for efficiency
      final batch = _firestore.batch();
      final favoritesRef = _firestore.collection('users').doc(uid).collection('favorites');

      for (var song in localFavorites) {
        final docRef = favoritesRef.doc(song.id);
        batch.set(docRef, _songToMap(song), SetOptions(merge: true));
      }

      await batch.commit();
      debugPrint('[CloudSyncService] Pushed ${localFavorites.length} favorites to cloud.');
    } catch (e) {
      debugPrint('[CloudSyncService] Error pushing to cloud: $e');
    }
  }

  // ----------------------------------------------------
  // Listen (Cloud -> Local)
  // ----------------------------------------------------
  void _startFavoritesListener(String uid) {
    _favoritesSubscription?.cancel();
    
    _favoritesSubscription = _firestore
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .snapshots()
        .listen((snapshot) async {
      
      debugPrint('[CloudSyncService] Cloud favorites updated, merging locally...');
      final List<Song> cloudSongs = [];

      for (var doc in snapshot.docs) {
        try {
          cloudSongs.add(_mapToSong(doc.data(), doc.id));
        } catch (e) {
          debugPrint('[CloudSyncService] Error parsing cloud song ${doc.id}: $e');
        }
      }

      // Merge into local Isar DB
      for (var cloudSong in cloudSongs) {
        final localSong = await _dbService.getSong(cloudSong.id);
        if (localSong == null) {
          // It's a new favorite from another device
          cloudSong.isFavorite = true;
          cloudSong.addedAt = DateTime.now();
          await _dbService.saveSong(cloudSong);
        } else if (!localSong.isFavorite) {
          // We had it locally, but it wasn't a favorite. Now it is.
          await _dbService.toggleFavorite(localSong.id);
        }
      }
    });
  }

  // ----------------------------------------------------
  // Helpers
  // ----------------------------------------------------
  Map<String, dynamic> _songToMap(Song song) {
    return {
      'id': song.id,
      'saavnId': song.saavnId,
      'title': song.title,
      'artist': song.artist,
      'album': song.album,
      'coverArt': song.coverArt,
      'duration': song.duration,
      'hasLyrics': song.hasLyrics,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  Song _mapToSong(Map<String, dynamic> data, String docId) {
    return Song(
      id: data['id'] ?? docId,
      saavnId: data['saavnId'] ?? docId.replaceFirst('saavn:', ''),
      title: data['title'] ?? 'Unknown',
      artist: data['artist'] ?? 'Unknown',
      album: data['album'] ?? 'Unknown',
      coverArt: data['coverArt'] ?? '',
      duration: data['duration'] ?? 0,
      hasLyrics: data['hasLyrics'] ?? false,
      addedAt: DateTime.now(),
      isFavorite: true,
      searchVector: Song.generateSearchVector(
        data['title'] ?? '',
        data['artist'] ?? '',
        data['album'] ?? '',
      )
    );
  }
}
