import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'dart:io';

class LocalAudioService {
  final OnAudioQuery _audioQuery;

  LocalAudioService({OnAudioQuery? audioQuery}) : _audioQuery = audioQuery ?? OnAudioQuery();

  Future<bool> requestPermission() async {
    if (Platform.isIOS) return true;
    
    // Android 13+ uses READ_MEDIA_AUDIO, older uses READ_EXTERNAL_STORAGE
    bool permissionStatus = await _audioQuery.permissionsStatus();
    if (!permissionStatus) {
      permissionStatus = await _audioQuery.permissionsRequest();
    }
    return permissionStatus;
  }

  Future<List<Song>> scanLocalMusic() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      debugPrint('[LocalAudioService] Permission denied');
      return [];
    }

    try {
      final List<SongModel> localSongs = await _audioQuery.querySongs(
        sortType: null,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      final List<Song> mappedSongs = localSongs.map((audio) {
        return Song(
          id: 'local:${audio.id}',
          saavnId: 'local_${audio.id}',
          title: audio.title,
          artist: audio.artist ?? 'Unknown Artist',
          album: audio.album ?? 'Unknown Album',
          duration: (audio.duration ?? 0) ~/ 1000,
          coverArt: '', // We can fetch local artwork dynamically if needed
          encryptedMediaUrl: 'file://${audio.data}',
          hasLyrics: false,
          language: 'unknown',
          year: 2024,
          isExplicit: false,
          addedAt: DateTime.now(),
          searchVector: [audio.title.toLowerCase(), (audio.artist ?? '').toLowerCase()],
        );
      }).toList();

      return mappedSongs;
    } catch (e) {
      debugPrint('[LocalAudioService] Error scanning local music: $e');
      return [];
    }
  }
}
