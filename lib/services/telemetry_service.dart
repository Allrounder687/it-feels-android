import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class TelemetryService with WidgetsBindingObserver {
  String? _uid;
  String? _userEmail;
  bool _isTracking = false;
  Stopwatch? _sessionStopwatch;
  
  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;
  TelemetryService._internal();

  Future<void> startTracking(User user) async {
    _uid = user.uid;
    _userEmail = user.email;
    if (_isTracking) return;
    
    _isTracking = true;
    WidgetsBinding.instance.addObserver(this);
    
    // Fetch and update static data (device + location)
    await _updateDeviceAndLocation();
    
    // Initial online state
    _setOnlineStatus(true);
    _startStopwatch();
  }

  void stopTracking() {
    if (!_isTracking) return;
    
    _isTracking = false;
    WidgetsBinding.instance.removeObserver(this);
    
    _stopStopwatchAndSync();
    _setOnlineStatus(false);
    _uid = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isTracking || _uid == null) return;
    
    if (state == AppLifecycleState.resumed) {
      _setOnlineStatus(true);
      _startStopwatch();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _setOnlineStatus(false);
      _stopStopwatchAndSync();
    }
  }

  void _startStopwatch() {
    _sessionStopwatch = Stopwatch()..start();
  }

  Future<void> _stopStopwatchAndSync() async {
    if (_sessionStopwatch == null || !_sessionStopwatch!.isRunning) return;
    
    _sessionStopwatch!.stop();
    final elapsedSeconds = _sessionStopwatch!.elapsed.inSeconds;
    
    if (elapsedSeconds > 0 && _uid != null) {
      try {
        final docRef = FirebaseFirestore.instance.collection('users').doc(_uid);
        await docRef.set({
          'totalUsageSeconds': FieldValue.increment(elapsedSeconds),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[TelemetryService] Error syncing usage time: $e');
      }
    }
    _sessionStopwatch = null;
  }

  Future<void> _setOnlineStatus(bool isOnline) async {
    if (_uid == null) return;
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(_uid);
      await docRef.set({
        'isOnline': isOnline,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[TelemetryService] Error setting online status: $e');
    }
  }

  Future<void> _updateDeviceAndLocation() async {
    if (_uid == null) return;
    
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(_uid);
      final updateData = <String, dynamic>{};
      
      if (_userEmail != null) {
        updateData['email'] = _userEmail;
      }
      
      // Get Device Info
      final deviceInfo = DeviceInfoPlugin();
      String deviceDesc = 'Unknown Device';
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceDesc = '${androidInfo.brand} ${androidInfo.model} (Android ${androidInfo.version.release})';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceDesc = 'Apple ${iosInfo.name} (iOS ${iosInfo.systemVersion})';
      } else if (Platform.isWindows) {
        final winInfo = await deviceInfo.windowsInfo;
        deviceDesc = 'Windows PC (Build ${winInfo.buildNumber})';
      }
      updateData['deviceInfo'] = deviceDesc;
      
      // Get Location (IP Based)
      try {
        final response = await http.get(Uri.parse('http://ip-api.com/json/')).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'success') {
            final city = data['city'] ?? 'Unknown City';
            final country = data['country'] ?? 'Unknown Country';
            updateData['location'] = '$city, $country';
          }
        }
      } catch (e) {
        debugPrint('[TelemetryService] Error fetching IP location: $e');
      }
      
      await docRef.set(updateData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[TelemetryService] Error updating device/location: $e');
    }
  }
}
