import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_experience.dart';
import 'app_experience_storage.dart';

class AppExperienceNotifier extends StateNotifier<AppExperience> {
  AppExperienceNotifier() : super(AppExperience.classic) {
    _init();
  }

  Future<void> _init() async {
    final saved = await AppExperienceStorage.loadExperience();
    if (mounted) {
      state = saved;
    }
  }

  /// Atomically updates the experience mode, persisting to disk and triggering reactive UI rebuilds.
  Future<void> setExperience(AppExperience experience) async {
    if (state == experience) return;
    state = experience;
    await AppExperienceStorage.saveExperience(experience);
  }

  void toggleExperience() {
    setExperience(
      state == AppExperience.classic
          ? AppExperience.newExperience
          : AppExperience.classic,
    );
  }
}

final appExperienceProvider =
    StateNotifierProvider<AppExperienceNotifier, AppExperience>((ref) {
  return AppExperienceNotifier();
});
