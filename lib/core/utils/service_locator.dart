import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/data/services/lyrics_service.dart';
import 'package:it_feels_music/services/notification_service.dart';
import 'package:it_feels_music/services/cloud_sync_service.dart';
import 'package:it_feels_music/services/telemetry_service.dart';
import 'package:it_feels_music/features/social/social_service.dart';

final GetIt locator = GetIt.instance;

/// Sets up the service locator for Dependency Injection.
/// Call this before runApp() in main.dart.
Future<void> setupServiceLocator() async {
  // Setup structured logging
  locator.registerLazySingleton<Logger>(() => Logger(
        printer: PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 5,
          lineLength: 80,
          colors: true,
          printEmojis: true,
          dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
        ),
      ));

  // Register Core Services
  locator.registerLazySingleton<CloudSyncService>(() => CloudSyncService());
  locator.registerLazySingleton<TelemetryService>(() => TelemetryService());
  locator.registerLazySingleton<MusicApiService>(() => MusicApiService());
  locator.registerLazySingleton<LyricsService>(() => LyricsService());
  locator.registerLazySingleton<NotificationService>(() => NotificationService());
  locator.registerLazySingleton<SocialService>(() => SocialService());

  // (Optional) You can register ViewModels or other Providers here if you migrate away from ChangeNotifierProvider in the future.
}
