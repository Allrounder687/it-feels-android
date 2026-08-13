import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppConfig {
  final int minVersion;
  final int latestVersionCode;
  final String latestVersion;
  final String updateUrl;
  final String? releaseNotes;
  final String? iosUpdateUrl;
  final String? windowsUpdateUrl;

  AppConfig({
    required this.minVersion,
    required this.latestVersionCode,
    required this.latestVersion,
    required this.updateUrl,
    this.releaseNotes,
    this.iosUpdateUrl,
    this.windowsUpdateUrl,
  });

  factory AppConfig.fromMap(Map<String, dynamic> data) {
    return AppConfig(
      minVersion: data['min_version_code'] ?? 1,
      latestVersionCode: data['latest_version_code'] ?? data['min_version_code'] ?? 1,
      latestVersion: data['latest_version'] ?? '1.0.0',
      updateUrl: data['update_url'] ?? '',
      releaseNotes: data['release_notes'],
      iosUpdateUrl: data['ios_update_url'],
      windowsUpdateUrl: data['windows_update_url'],
    );
  }
}

class ConfigService {
  @visibleForTesting
  static FirebaseFirestore? customFirestore;

  static FirebaseFirestore get _firestore => customFirestore ?? FirebaseFirestore.instance;

  static String get _platformConfigDoc {
    if (!kIsWeb && Platform.isWindows) return 'windows';
    if (!kIsWeb && Platform.isIOS) return 'ios';
    return 'android';
  }

  static Future<AppConfig?> fetchRemoteConfig() async {
    for (int i = 0; i < 3; i++) {
      try {
        final doc = await _firestore
            .collection('client_config')
            .doc(_platformConfigDoc)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 5));
        
        if (doc.exists && doc.data() != null) {
          return AppConfig.fromMap(doc.data()!);
        } else {
          // If the document doesn't exist, it means no forced updates are configured for this platform.
          return AppConfig(
            minVersion: 1,
            latestVersionCode: 1,
            latestVersion: '1.0.0',
            updateUrl: '',
          );
        }
      } catch (e) {
        if (i == 2) {
          // If all retries fail, return a safe fallback to prevent hanging the splash screen
          return AppConfig(
            minVersion: 1,
            latestVersionCode: 1,
            latestVersion: '1.0.0',
            updateUrl: '',
          );
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    return null;
  }

  static Future<bool> requiresForceUpdate(AppConfig config) async {
    if (kDebugMode) return false;
    
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;
      
      return currentBuildNumber < config.minVersion;
    } catch (e) {
      debugPrint('[ConfigService] Error checking version: $e');
      return false;
    }
  }

  static Future<bool> hasSoftUpdate(AppConfig config) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;
      
      // If we need a force update, this shouldn't trigger (handled separately)
      if (currentBuildNumber < config.minVersion) return false;
      
      return currentBuildNumber < config.latestVersionCode;
    } catch (e) {
      debugPrint('[ConfigService] Error checking soft update version: $e');
      return false;
    }
  }
}
