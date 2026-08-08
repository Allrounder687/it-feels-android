import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart';
import 'package:it_feels_music/core/theme/app_typography.dart';
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
import 'package:it_feels_music/features/auth/banned_screen.dart';
import 'package:it_feels_music/core/providers/fullscreen_provider.dart';
import 'package:it_feels_music/features/admin/in_app_broadcast_listener.dart';
import 'package:it_feels_music/data/services/smart_storage_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:smtc_windows/smtc_windows.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:app_links/app_links.dart';

import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

late AudioPlayerHandler _audioHandler;
late final ProviderContainer appProviderContainer;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enforce strict global ImageCache bounds to prevent Out-Of-Memory exceptions
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50 MB
  PaintingBinding.instance.imageCache.maximumSize = 100; // 100 images maximum

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    if (Platform.isWindows) {
      try {
        await SMTCWindows.initialize();
      } catch (_) {}
    }
  }

  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}
  
  await setupServiceLocator();
  
  try {
    MediaKit.ensureInitialized();
  } catch (e) {
    debugPrint('Failed to initialize media_kit: $e');
  }

  final firebaseFuture = () async {
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
  }();

  final audioFuture = () async {
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
  }();

  // Pre-warm the transitive SQLite image cache database in the background.
  // This prevents the main UI isolate from locking up when rendering the first album art.
  Future.microtask(() {
    try {
      const CachedNetworkImageProvider('prewarm_cache_sqlite').evict();
      
      // Automatically enforce the SmartStorageService cache limits in the background
      locator<SmartStorageService>().enforceCacheLimit();
    } catch (_) {}
  });

  await Future.wait([firebaseFuture, audioFuture]);

  appProviderContainer = ProviderContainer(
    overrides: [
      audioPlayerProvider.overrideWith(() => AudioPlayerNotifier()),
    ],
  );

  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await hotKeyManager.unregisterAll();
    
    // Ctrl+Space: Raycast Search
    await hotKeyManager.register(
      HotKey(key: LogicalKeyboardKey.space, modifiers: [HotKeyModifier.control], scope: HotKeyScope.system),
      keyDownHandler: (HotKey hotKey) async {
        await windowManager.show();
        await windowManager.focus();
        appRouter.push('/raycast');
      },
    );

    // Ctrl+Alt+Space: Play/Pause
    await hotKeyManager.register(
      HotKey(key: LogicalKeyboardKey.space, modifiers: [HotKeyModifier.control, HotKeyModifier.alt], scope: HotKeyScope.system),
      keyDownHandler: (HotKey hotKey) async {
        final engine = locator<AudioEngineService>();
        if (engine.isPlaying) {
          await engine.pause();
        } else {
          await engine.play();
        }
      },
    );

    // Ctrl+Alt+Right: Next
    await hotKeyManager.register(
      HotKey(key: LogicalKeyboardKey.arrowRight, modifiers: [HotKeyModifier.control, HotKeyModifier.alt], scope: HotKeyScope.system),
      keyDownHandler: (HotKey hotKey) async {
        await locator<AudioEngineService>().skipToNext();
      },
    );

    // Ctrl+Alt+Left: Previous
    await hotKeyManager.register(
      HotKey(key: LogicalKeyboardKey.arrowLeft, modifiers: [HotKeyModifier.control, HotKeyModifier.alt], scope: HotKeyScope.system),
      keyDownHandler: (HotKey hotKey) async {
        await locator<AudioEngineService>().skipToPrevious();
      },
    );

    if (Platform.isWindows) {
      await WindowsSingleInstance.ensureSingleInstance(
        args,
        "it_feels_music_instance",
        onSecondWindow: (args) async {
          await windowManager.show();
          await windowManager.focus();
        },
      );
    }
    
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1280, 720),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    if (Platform.isWindows) {
      await windowManager.setPreventClose(true);
      
      await trayManager.setIcon(
        Platform.isWindows ? 'assets/images/icon.ico' : 'assets/images/icon.png',
      );

      Menu menu = Menu(
        items: [
          MenuItem(
            key: 'show_app',
            label: 'Show App',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit_app',
            label: 'Exit',
          ),
        ],
      );
      await trayManager.setContextMenu(menu);

      windowManager.addListener(AppWindowListener());
      trayManager.addListener(AppWindowListener());
    }
  }

  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    final appLinks = AppLinks();
    appLinks.uriLinkStream.listen((uri) async {
      if (uri.scheme == 'itfeels') {
        if (uri.host == 'search') {
          final query = uri.queryParameters['q'];
          if (query != null && query.isNotEmpty) {
            appRouter.go('/search?q=${Uri.encodeComponent(query)}');
            await windowManager.show();
            await windowManager.focus();
          }
        }
      }
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
              final appThemeMode = ref.watch(audioPlayerProvider.select((p) => p.appThemeMode));
              final seedColor = ref.watch(audioPlayerProvider.select((p) => p.themeAccentColor));
              final bgColor = ref.watch(audioPlayerProvider.select((p) => p.themeBackgroundColor));
              
              final isLight = appThemeMode == AppThemeMode.light;
              final brightness = isLight ? Brightness.light : Brightness.dark;
              final colorScheme = (isLight ? lightDynamic : darkDynamic) ?? ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
              
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
                  scaffoldBackgroundColor: bgColor,
                  textTheme: isLight ? AppTypography.lightTextTheme : AppTypography.darkTextTheme,
                ),
                themeAnimationDuration: Duration.zero,
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

class AppWindowListener extends WindowListener with TrayListener {
  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      windowManager.hide();
    }
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_app') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      windowManager.destroy();
    }
  }
}

