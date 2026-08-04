import 'dart:io';
import 'package:flutter/services.dart';

class DeviceUtils {
  static const MethodChannel _channel = MethodChannel('com.itfeels.it_feels_music/device_info');
  static bool? _isLowRamDevice;

  static Future<bool> isLowRamDevice() async {
    if (_isLowRamDevice != null) return _isLowRamDevice!;
    if (Platform.isAndroid) {
      try {
        final bool result = await _channel.invokeMethod('isLowRamDevice');
        _isLowRamDevice = result;
      } catch (e) {
        _isLowRamDevice = false;
      }
    } else {
      _isLowRamDevice = false; // Only checking Android
    }
    return _isLowRamDevice!;
  }
}
