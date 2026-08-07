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
import 'package:it_feels_music/data/services/audio_engine_service.dart';
import 'core/utils/service_locator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/notification_service.dart';
import 'package:it_feels_music/core/router/app_router.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/features/auth/banned_screen.dart';
import 'package:it_feels_music/core/providers/fullscreen_provider.dart';
import 'package:it_feels_music/features/admin/in_app_broadcast_listener.dart';
import 'package:it_feels_music/services/local_proxy_server.dart';
import 'package:it_feels_music/features/home/custom_title_bar.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'package:cached_network_image/cached_network_image.dart';

late AudioPlayerHandler _audioHandler;
late final ProviderContainer appProviderContainer;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}
  
  await setupServiceLocator();
  
  try {
    MediaKit.ensureInitialized();
  } catch (e) {
    debugPrint('Failed to initialize media_kit: $e');
  }

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    try {
      await FirebaseAuth.instance.setLanguageCode('en');
    } catch (_) {}
    
    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      
      // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } else {
      // Fallback for Windows/Linux/Web where Crashlytics isn't fully supported
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('Async Error: $error\n$stack');
        return true;
      };
    }

    await Permission.notification.request();

    final notificationService = NotificationService();
    await notificationService.initialize();
  } catch (e) {
    debugPrint("Firebase/Notification initialization failed: $e");
  }

  // Pre-warm the transitive SQLite image cache database in the background.
  // This prevents the main UI isolate from locking up when rendering the first album art.
  Future.microtask(() {
    try {
      CachedNetworkImageProvider('prewarm_cache_sqlite').evict();
    } catch (_) {}
  });
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
  await locator<AudioEngineService>().init(_audioHandler);

  appProviderContainer = ProviderContainer(
    overrides: [
      audioPlayerProvider.overrideWith(() => AudioPlayerNotifier()),
    ],
  );

  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1280, 720),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(UncontrolledProviderScope(
    container: appProviderContainer,
    child: const PixelPlayerSaavnApp(),
  ));
}

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class PixelPlayerSaavnApp extends ConsumerWidget {
  final AudioPlayerHandler? audioHandler;

  const PixelPlayerSaavnApp({super.key, this.audioHandler});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          return Builder(
            builder: (context) {
              final appThemeMode = ref.watch(audioPlayerProvider).appThemeMode;
              final isLight = appThemeMode == AppThemeMode.light;
              final brightness = isLight ? Brightness.light : Brightness.dark;
              final colorScheme = (isLight ? lightDynamic : darkDynamic) ?? ColorScheme.fromSeed(seedColor: context.themeAccentColor, brightness: brightness);
              
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(audioPlayerProvider.notifier).setMaterialYouColors(colorScheme.surface, colorScheme.surfaceContainer, colorScheme.primary);
              });
              return MaterialApp.router(
                scaffoldMessengerKey: rootScaffoldMessengerKey,
                title: 'It Feels',
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  useMaterial3: true,
                  brightness: brightness,
                  colorScheme: colorScheme,
                  scaffoldBackgroundColor: context.themeBackgroundColor,
                  textTheme: GoogleFonts.interTextTheme(isLight ? ThemeData.light().textTheme : ThemeData.dark().textTheme),
                ),
                routerConfig: appRouter,
                builder: (context, child) {
                  final isBanned = ref.watch(banProvider).isBanned;
                  if (isBanned) return const BannedScreen();
                  return Consumer(
                    builder: (context, ref, childWidget) {
                      final isFullscreen = ref.watch(fullscreenProvider);
                      return Column(
                        children: [
                          Expanded(
                            child: childWidget!,
                          ),
                        ],
                      );
                    },
                    child: InAppBroadcastListener(child: child ?? const SizedBox()),
                  );
                },
              );
            },
          );
        },
    );
  }
}
