import 'package:shared_preferences/shared_preferences.dart';
import 'app_experience.dart';

class AppExperienceStorage {
  static const String _key = 'app_experience_mode_v2';
  static const String _legacyKey = 'ui_experience_mode';

  /// Loads the persisted experience mode. Defaults to [AppExperience.classic].
  static Future<AppExperience> loadExperience() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      if (raw == AppExperience.newExperience.name || raw == 'appleNeo') {
        return AppExperience.newExperience;
      }
      return AppExperience.classic;
    }

    // Check legacy key if present
    final legacy = prefs.getString(_legacyKey);
    if (legacy == 'appleNeo' || legacy == 'newExperience') {
      return AppExperience.newExperience;
    }

    // Strict default for all users is Classic
    return AppExperience.classic;
  }

  /// Persists the selected experience mode across reboots.
  static Future<void> saveExperience(AppExperience experience) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, experience.name);
    // Keep legacy key synchronized for backward compatibility
    await prefs.setString(
      _legacyKey,
      experience == AppExperience.newExperience ? 'appleNeo' : 'classic',
    );
  }
}
