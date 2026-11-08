import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
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
import 'package:it_feels_music/features/player/palette_extractor_service.dart';
import 'package:it_feels_music/data/services/audio_engine_service.dart';
import 'package:it_feels_music/features/social/listen_together_service.dart';
import 'package:it_feels_music/services/download_service.dart';
import 'package:it_feels_music/data/services/smart_cache_service.dart';
import 'package:it_feels_music/data/services/equalizer_service.dart';
import 'package:it_feels_music/core/intelligence/playlists/dynamic_playlist_service.dart';
import 'package:it_feels_music/core/diagnostics/observability_service.dart';
import 'package:it_feels_music/core/diagnostics/trackers/playback_diagnostics_tracker.dart';
import 'package:it_feels_music/core/diagnostics/export/diagnostic_export_service.dart';

import 'package:it_feels_music/data/datasources/local_cache_data_source.dart';
import 'package:it_feels_music/data/services/feedback_email_service.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';

final GetIt locator = GetIt.instance;

/// Sets up the service locator for Dependency Injection.
/// Call this before runApp() in main.dart.
Future<void> setupServiceLocator() async {
  // Initialize Isar Database
  await DatabaseService.init();
  locator.registerLazySingleton<DatabaseService>(() => DatabaseService());

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

  // Register Core DataSources & Services
  locator.registerLazySingleton<LocalCacheDataSource>(() => LocalCacheDataSource());
  locator.registerLazySingleton<FeedbackEmailService>(() => FeedbackEmailService());
  locator.registerLazySingleton<IMusicRepository>(() => MusicRepository(
        cacheDataSource: locator<LocalCacheDataSource>(),
      ));

  // Register Core Services
  locator.registerLazySingleton<CloudSyncService>(() => CloudSyncService());
  locator.registerLazySingleton<TelemetryService>(() => TelemetryService());
  locator.registerLazySingleton<LyricsService>(() => LyricsService());
  locator.registerLazySingleton<NotificationService>(() => NotificationService());
  locator.registerLazySingleton<SocialService>(() => SocialService());
  locator.registerLazySingleton<RoomService>(() => RoomService());
  locator.registerLazySingleton<it_feels_music_cast_service.CastService>(() => it_feels_music_cast_service.CastService());
  locator.registerLazySingleton<SmartStorageService>(() => SmartStorageService());
  locator.registerLazySingleton<LastfmService>(() => LastfmService());
  locator.registerLazySingleton<PaletteExtractorService>(() => PaletteExtractorService());
  locator.registerLazySingleton<AudioEngineService>(() => AudioEngineService());
  locator.registerLazySingleton<ListenTogetherService>(() => ListenTogetherService());
  locator.registerLazySingleton<DownloadService>(() => DownloadService(apiService: locator<IMusicRepository>()));
  locator.registerLazySingleton<SmartCacheService>(() => SmartCacheService());
  locator.registerLazySingleton<EqualizerService>(() => EqualizerService());
  locator.registerLazySingleton<DynamicPlaylistService>(() => DynamicPlaylistService.instance);
  locator.registerLazySingleton<ObservabilityService>(() => ObservabilityService.instance);
  locator.registerLazySingleton<PlaybackDiagnosticsTracker>(() => PlaybackDiagnosticsTracker.instance);
  locator.registerLazySingleton<DiagnosticExportService>(() => DiagnosticExportService.instance);
}

