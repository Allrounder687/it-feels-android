import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cast/cast.dart';
import 'package:it_feels_music/data/models/song_model.dart';

class CastService extends ChangeNotifier {
  CastSession? _session;
  CastDevice? _connectedDevice;
  
  bool get isConnected => _session != null;
  CastDevice? get connectedDevice => _connectedDevice;
  
  Future<List<CastDevice>> searchDevices() async {
    return await CastDiscoveryService().search();
  }
  
  Future<void> connectToDevice(CastDevice device) async {
    _session = await CastSessionManager().startSession(device);
    _connectedDevice = device;
    notifyListeners();
    
    _session!.stateStream.listen((state) {
      if (state == CastSessionState.closed) {
        _session = null;
        _connectedDevice = null;
        notifyListeners();
      }
    });
  }
  
  Future<void> disconnect() async {
    if (_session != null) {
      _session!.close();
      _session = null;
      _connectedDevice = null;
      notifyListeners();
    }
  }

  Future<void> loadMedia(Song song, String streamUrl, Duration position, bool autoPlay) async {
    if (!isConnected) return;

    _session!.sendMessage(CastSession.kNamespaceMedia, {
      'type': 'LOAD',
      'autoPlay': autoPlay,
      'currentTime': position.inSeconds,
      'media': {
        'contentId': streamUrl,
        'contentType': 'audio/mpeg',
        'streamType': 'BUFFERED',
        'metadata': {
          'type': 3, // MUSIC_TRACK
          'metadataType': 3,
          'title': song.title,
          'artist': song.artist,
          'albumName': song.album,
          'images': [
            {'url': song.coverArt}
          ]
        }
      }
    });
  }

  Future<void> play() async {
    if (!isConnected) return;
    _session!.sendMessage(CastSession.kNamespaceMedia, {
      'type': 'PLAY',
    });
  }

  Future<void> pause() async {
    if (!isConnected) return;
    _session!.sendMessage(CastSession.kNamespaceMedia, {
      'type': 'PAUSE',
    });
  }
  
  Future<void> seek(Duration position) async {
    if (!isConnected) return;
    _session!.sendMessage(CastSession.kNamespaceMedia, {
      'type': 'SEEK',
      'currentTime': position.inSeconds,
    });
  }
}
