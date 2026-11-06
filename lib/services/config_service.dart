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

  // The 10 Next-Gen Intelligence Feature Flags (Section 18)
  final bool dynamicHomeEnabled;
  final bool recommendationEngineEnabled;
  final bool personalizedMixesEnabled;
  final bool discoverWeeklyEnabled;
  final bool releaseRadarEnabled;
  final bool aiPlaylistEnabled;
  final bool tasteProfileEnabled;
  final bool smartShuffleEnabled;
  final bool endlessPlaybackEnabled;
  final bool playlistVersioningEnabled;

  AppConfig({
    required this.minVersion,
    required this.latestVersionCode,
    required this.latestVersion,
    required this.updateUrl,
    this.releaseNotes,
    this.iosUpdateUrl,
    this.windowsUpdateUrl,
    this.dynamicHomeEnabled = true,
    this.recommendationEngineEnabled = true,
    this.personalizedMixesEnabled = true,
    this.discoverWeeklyEnabled = true,
    this.releaseRadarEnabled = true,
    this.aiPlaylistEnabled = true,
    this.tasteProfileEnabled = true,
    this.smartShuffleEnabled = true,
    this.endlessPlaybackEnabled = true,
    this.playlistVersioningEnabled = true,
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
      dynamicHomeEnabled: data['dynamic_home_enabled'] ?? true,
      recommendationEngineEnabled: data['recommendation_engine_enabled'] ?? true,
      personalizedMixesEnabled: data['personalized_mixes_enabled'] ?? true,
      discoverWeeklyEnabled: data['discover_weekly_enabled'] ?? true,
      releaseRadarEnabled: data['release_radar_enabled'] ?? true,
      aiPlaylistEnabled: data['ai_playlist_enabled'] ?? true,
      tasteProfileEnabled: data['taste_profile_enabled'] ?? true,
      smartShuffleEnabled: data['smart_shuffle_enabled'] ?? true,
      endlessPlaybackEnabled: data['endless_playback_enabled'] ?? true,
      playlistVersioningEnabled: data['playlist_versioning_enabled'] ?? true,
    );
  }
}

class ConfigService {
  // All 10 Required Feature Flags (Section 18)
  static bool dynamicHomeEnabled = true;
  static bool recommendationEngineEnabled = true;
  static bool personalizedMixesEnabled = true;
  static bool discoverWeeklyEnabled = true;
  static bool releaseRadarEnabled = true;
  static bool aiPlaylistEnabled = true;
  static bool tasteProfileEnabled = true;
  static bool smartShuffleEnabled = true;
  static bool endlessPlaybackEnabled = true;
  static bool playlistVersioningEnabled = true;

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
          final cfg = AppConfig.fromMap(doc.data()!);
          dynamicHomeEnabled = cfg.dynamicHomeEnabled;
          recommendationEngineEnabled = cfg.recommendationEngineEnabled;
          personalizedMixesEnabled = cfg.personalizedMixesEnabled;
          discoverWeeklyEnabled = cfg.discoverWeeklyEnabled;
          releaseRadarEnabled = cfg.releaseRadarEnabled;
          aiPlaylistEnabled = cfg.aiPlaylistEnabled;
          tasteProfileEnabled = cfg.tasteProfileEnabled;
          smartShuffleEnabled = cfg.smartShuffleEnabled;
          endlessPlaybackEnabled = cfg.endlessPlaybackEnabled;
          playlistVersioningEnabled = cfg.playlistVersioningEnabled;
          return cfg;
        } else {
          // If the document doesn't exist, it means no forced updates are configured for this platform.
          return AppConfig(
            minVersion: 1,
            latestVersionCode: 1,
            latestVersion: '1.0.0',
            updateUrl: '',
          );
        }
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          debugPrint('[ConfigService] client_config/$_platformConfigDoc permission denied. Falling back to default app config.');
          return AppConfig(
            minVersion: 1,
            latestVersionCode: 1,
            latestVersion: '1.0.0',
            updateUrl: '',
          );
        }
        if (i == 2) {
          return AppConfig(
            minVersion: 1,
            latestVersionCode: 1,
            latestVersion: '1.0.0',
            updateUrl: '',
          );
        }
        debugPrint('[ConfigService] FirebaseException (Attempt ${i + 1}/3): ${e.message}');
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
        debugPrint('[ConfigService] Error fetching remote config (Attempt ${i + 1}/3): $e');
      }
      if (i < 2) await Future.delayed(const Duration(milliseconds: 500));
    }
    return AppConfig(
      minVersion: 1,
      latestVersionCode: 1,
      latestVersion: '1.0.0',
      updateUrl: '',
    );
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

  static Future<bool> shouldForceUpdate(AppConfig config) => requiresForceUpdate(config);

  static Future<bool> isUpdateAvailable(AppConfig config) => hasSoftUpdate(config);
}
