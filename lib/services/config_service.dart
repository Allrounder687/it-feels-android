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
  static String get _platformConfigDoc {
    if (!kIsWeb && Platform.isWindows) return 'windows';
    if (!kIsWeb && Platform.isIOS) return 'ios';
    return 'android';
  }

  static Future<AppConfig?> fetchRemoteConfig() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('client_config').doc(_platformConfigDoc).get();
      if (doc.exists && doc.data() != null) {
        return AppConfig.fromMap(doc.data()!);
      }
    } catch (e) {
      debugPrint('[ConfigService] Error fetching remote config: $e');
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
