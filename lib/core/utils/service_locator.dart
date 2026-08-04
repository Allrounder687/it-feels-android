import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/data/services/lyrics_service.dart';
import 'package:it_feels_music/services/notification_service.dart';
import 'package:it_feels_music/services/cloud_sync_service.dart';
import 'package:it_feels_music/services/telemetry_service.dart';
import 'package:it_feels_music/features/social/social_service.dart';
import 'package:it_feels_music/features/cast/cast_service.dart' as it_feels_music_cast_service;
import 'package:it_feels_music/services/database_service.dart';
import 'package:it_feels_music/features/social/room_service.dart';
import 'package:it_feels_music/data/services/smart_storage_service.dart';
import 'package:it_feels_music/services/lastfm_service.dart';
import 'package:it_feels_music/data/services/radio_api_service.dart';

final GetIt locator = GetIt.instance;

/// Sets up the service locator for Dependency Injection.
/// Call this before runApp() in main.dart.
Future<void> setupServiceLocator() async {
  // Initialize Isar Database
  await DatabaseService.init();

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
  locator.registerLazySingleton<RoomService>(() => RoomService());
  locator.registerLazySingleton<it_feels_music_cast_service.CastService>(() => it_feels_music_cast_service.CastService());
  locator.registerLazySingleton<SmartStorageService>(() => SmartStorageService());
  locator.registerLazySingleton<LastfmService>(() => LastfmService());
  locator.registerLazySingleton<RadioApiService>(() => RadioApiService());
}
