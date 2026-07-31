import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'data/services/audio_player_handler.dart';
import 'data/services/music_api_service.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'core/utils/service_locator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/notification_service.dart';
import 'package:it_feels_music/core/router/app_router.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';

late AudioPlayerHandler _audioHandler;
late final ProviderContainer appProviderContainer;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Failed to load .env file: $e");
  }
  
  await setupServiceLocator();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    
    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    
    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    await Permission.notification.request();

    final notificationService = NotificationService();
    await notificationService.initialize();
  } catch (e) {
    debugPrint("Firebase/Notification initialization failed: $e");
  }


  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  // Initialize Android background AudioService
  final apiService = locator<MusicApiService>();
  _audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(apiService: apiService),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.itfeels.music.channel.audio',
      androidNotificationChannelName: 'It Feels Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidShowNotificationBadge: true,
    ),
  );

  locator.registerSingleton<AudioPlayerHandler>(_audioHandler);

  appProviderContainer = ProviderContainer(
    overrides: [
      audioPlayerProvider.overrideWith(() => AudioPlayerNotifier(
        _audioHandler,
        locator<MusicApiService>(),
      )),
    ],
  );

  runApp(UncontrolledProviderScope(
    container: appProviderContainer,
    child: const PixelPlayerSaavnApp(),
  ));
}

class PixelPlayerSaavnApp extends ConsumerWidget {
  final AudioPlayerHandler? audioHandler;

  const PixelPlayerSaavnApp({super.key, this.audioHandler});

  Widget build(BuildContext context, WidgetRef ref) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          return Builder(
            builder: (context) {
              final colorScheme = darkDynamic ?? ColorScheme.fromSeed(seedColor: context.themeAccentColor, brightness: Brightness.dark);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final provider = ref.read(audioPlayerProvider);
                provider.setMaterialYouColors(colorScheme.surface, colorScheme.surfaceContainer, colorScheme.primary);
              });
              return MaterialApp.router(
                title: 'It Feels',
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  useMaterial3: true,
                  brightness: Brightness.dark,
                  colorScheme: colorScheme,
                  scaffoldBackgroundColor: context.themeBackgroundColor,
                  textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
                ),
                routerConfig: appRouter,
              );
            },
          );
        },
    );
  }
}
