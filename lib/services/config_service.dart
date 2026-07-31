import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppConfig {
  final int minVersion;
  final String latestVersion;
  final String updateUrl;
  final String? releaseNotes;
  final String? iosUpdateUrl;

  AppConfig({
    required this.minVersion,
    required this.latestVersion,
    required this.updateUrl,
    this.releaseNotes,
    this.iosUpdateUrl,
  });

  factory AppConfig.fromMap(Map<String, dynamic> data) {
    return AppConfig(
      minVersion: data['min_version_code'] ?? 1,
      latestVersion: data['latest_version'] ?? '1.0.0',
      updateUrl: data['update_url'] ?? '',
      releaseNotes: data['release_notes'],
      iosUpdateUrl: data['ios_update_url'],
    );
  }
}

class ConfigService {
  static Future<AppConfig?> fetchRemoteConfig() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('client_config').doc('android').get();
      if (doc.exists && doc.data() != null) {
        return AppConfig.fromMap(doc.data()!);
      }
    } catch (e) {
      debugPrint('[ConfigService] Error fetching remote config: $e');
    }
    return null;
  }

  static Future<bool> requiresForceUpdate(AppConfig config) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;
      
      return currentBuildNumber < config.minVersion;
    } catch (e) {
      debugPrint('[ConfigService] Error checking version: $e');
      return false;
    }
  }
}
