import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/core/appearance/app_experience.dart';
import 'package:it_feels_music/core/appearance/app_experience_storage.dart';
import 'package:it_feels_music/core/appearance/app_experience_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppExperience Enum Tests', () {
    test('Default experience should be classic', () {
      const exp = AppExperience.classic;
      expect(exp.isClassic, isTrue);
      expect(exp.isNewExperience, isFalse);
      expect(exp.displayName, 'Classic Experience');
      expect(exp.shortLabel, 'Classic');
    });

    test('New Experience metadata should be correct', () {
      const exp = AppExperience.newExperience;
      expect(exp.isNewExperience, isTrue);
      expect(exp.isClassic, isFalse);
      expect(exp.displayName, 'New Experience (2026)');
      expect(exp.shortLabel, 'Next-Gen 2026');
    });
  });

  group('AppExperienceStorage Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Loads classic by default when no value stored', () async {
      final loaded = await AppExperienceStorage.loadExperience();
      expect(loaded, AppExperience.classic);
    });

    test('Saves and loads newExperience correctly', () async {
      await AppExperienceStorage.saveExperience(AppExperience.newExperience);
      final loaded = await AppExperienceStorage.loadExperience();
      expect(loaded, AppExperience.newExperience);
    });

    test('Saves and loads classic correctly', () async {
      await AppExperienceStorage.saveExperience(AppExperience.classic);
      final loaded = await AppExperienceStorage.loadExperience();
      expect(loaded, AppExperience.classic);
    });
  });

  group('AppExperienceNotifier Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initializes with default classic experience', () {
      final notifier = AppExperienceNotifier();
      expect(notifier.state, AppExperience.classic);
    });

    test('setExperience updates state and triggers persistence', () async {
      final notifier = AppExperienceNotifier();
      await notifier.setExperience(AppExperience.newExperience);
      expect(notifier.state, AppExperience.newExperience);

      // Verify persisted to storage
      final persisted = await AppExperienceStorage.loadExperience();
      expect(persisted, AppExperience.newExperience);
    });

    test('toggleExperience toggles between classic and newExperience', () async {
      final notifier = AppExperienceNotifier();
      expect(notifier.state, AppExperience.classic);

      notifier.toggleExperience();
      expect(notifier.state, AppExperience.newExperience);

      notifier.toggleExperience();
      expect(notifier.state, AppExperience.classic);
    });
  });
}
