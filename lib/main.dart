import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/services/audio_engine_service.dart';
import 'package:it_feels_music/core/diagnostics/crash_diagnostics_service.dart';
import 'package:it_feels_music/core/diagnostics/observability_service.dart';
import 'package:it_feels_music/core/diagnostics/models/diagnostic_subsystem.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:it_feels_music/core/theme/app_typography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/data/services/audio_player_handler.dart';
import 'package:it_feels_music/features/social/listen_together_service.dart';
import 'package:it_feels_music/data/services/equalizer_service.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';


import 'package:it_feels_music/core/widgets/dev_toolkit.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/notification_service.dart';
import 'package:it_feels_music/core/router/app_router.dart';
import 'package:it_feels_music/features/auth/banned_screen.dart';

import 'package:it_feels_music/features/admin/in_app_broadcast_listener.dart';
import 'package:it_feels_music/data/services/smart_storage_service.dart';
import 'package:it_feels_music/data/services/addon_manager.dart';
import 'package:it_feels_music/services/local_proxy_server.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:it_feels_music/core/utils/system_tray_manager.dart';
import 'package:smtc_windows/smtc_windows.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:it_feels_music/services/keyboard_shortcut_service.dart';
import 'package:app_links/app_links.dart';
import 'package:protocol_registry/protocol_registry.dart';
import 'package:it_feels_music/core/widgets/tv_focusable_card.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

late AudioPlayerHandler _audioHandler;
late ProviderContainer appProviderContainer;

Future<void> main(List<String> args) async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  try {
    await ObservabilityService.instance.init();
    await CrashDiagnosticsService.instance.init();
  } catch (_) {}

  await LocalProxyServer.start();

  if (Platform.isWindows && !kDebugMode) {
    await WindowsSingleInstance.ensureSingleInstance(
      args,
      "it_feels_music_instance",
      onSecondWindow: (args) async {
        await windowManager.show();
        await windowManager.focus();
        
        // Handle deep link passed to the second instance
        if (args.isNotEmpty) {
          final uriStr = args.firstWhere((arg) => arg.startsWith('itfeels'), orElse: () => '');
          if (uriStr.isNotEmpty) {
            final uri = Uri.parse(uriStr);
            if (uri.scheme == 'itfeelsmusic') {
              if (uri.host == 'room') {
                final roomId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
                if (roomId != null && roomId.isNotEmpty) {
                  final exp = uri.queryParameters['exp'];
                  final route = exp != null ? '/room/$roomId?exp=$exp' : '/room/$roomId';
                  appRouter.go(route);
                }
              } else if (uri.host == 'song') {
                final songId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
                if (songId != null && songId.isNotEmpty) {
                  appRouter.go('/song/$songId');
                }
              } else if (uri.host == 'download') {
                final songId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
                if (songId != null && songId.isNotEmpty) {
                  appRouter.go('/download/$songId');
                }
              }
            } else if (uri.scheme == 'itfeels' && uri.host == 'search') {
              final query = uri.queryParameters['q'];
              if (query != null && query.isNotEmpty) {
                appRouter.go('/search?q=${Uri.encodeComponent(query)}');
              }
            }
          }
        }
      },
    );
  }

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

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      LaunchAtStartup.instance.setup(
        appName: packageInfo.appName,
        appPath: Platform.resolvedExecutable,
      );
    } catch (_) {}
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
      if (!kIsWeb && Platform.isWindows) {
        try {
          FirebaseFirestore.instance.settings = const Settings(
            persistenceEnabled: false,
          );
          debugPrint('[Firebase] Disabled LevelDB persistence on Windows to prevent runtime assertions.');
        } catch (e) {
          debugPrint('[Firebase] Could not set Firestore persistence on Windows: $e');
        }
      }
      try {
        await FirebaseAuth.instance.setLanguageCode('en');
      } catch (_) {}
      
      // Pass all uncaught "fatal" errors from the framework to CrashDiagnostics & Crashlytics
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
        FlutterError.onError = (details) {
          ObservabilityService.instance.fatal(
            subsystem: DiagnosticSubsystem.framework,
            component: 'FlutterFramework',
            eventName: 'uncaught_flutter_error',
            errorMessage: details.exceptionAsString(),
            stackTrace: details.stack,
            metadata: {
              'library': details.library ?? 'flutter',
              'context': details.context?.toDescription(),
            },
          );
          CrashDiagnosticsService.instance.recordFrameworkError(details);
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        };
        
        // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework
        PlatformDispatcher.instance.onError = (error, stack) {
          ObservabilityService.instance.fatal(
            subsystem: DiagnosticSubsystem.platform,
            component: 'PlatformDispatcher',
            eventName: 'uncaught_async_error',
            errorMessage: error.toString(),
            stackTrace: stack,
          );
          CrashDiagnosticsService.instance.record(
            category: DiagnosticCategory.platform,
            severity: DiagnosticSeverity.fatal,
            message: error.toString(),
            stackTrace: stack,
          );
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      } else {
        // Fallback for Windows/Linux/Web with full privacy-conscious local crash diagnostics
        FlutterError.onError = (details) {
          ObservabilityService.instance.fatal(
            subsystem: DiagnosticSubsystem.framework,
            component: 'FlutterFramework',
            eventName: 'uncaught_flutter_error',
            errorMessage: details.exceptionAsString(),
            stackTrace: details.stack,
            metadata: {
              'library': details.library ?? 'flutter',
              'context': details.context?.toDescription(),
            },
          );
          CrashDiagnosticsService.instance.recordFrameworkError(details);
          FlutterError.presentError(details);
        };
        PlatformDispatcher.instance.onError = (error, stack) {
          ObservabilityService.instance.fatal(
            subsystem: DiagnosticSubsystem.platform,
            component: 'PlatformDispatcher',
            eventName: 'uncaught_async_error',
            errorMessage: error.toString(),
            stackTrace: stack,
          );
          CrashDiagnosticsService.instance.record(
            category: DiagnosticCategory.platform,
            severity: DiagnosticSeverity.fatal,
            message: error.toString(),
            stackTrace: stack,
          );
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
    final apiService = locator<IMusicRepository>();
    _audioHandler = await AudioService.init(
      builder: () => AudioPlayerHandler(apiService: apiService),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.itfeels.music.channel.audio',
        androidNotificationChannelName: 'It Feels Playback',
        androidStopForegroundOnPause: false,
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
    try {
      await hotKeyManager.unregisterAll();
      
      // Ctrl+Space: Raycast Search
      await hotKeyManager.register(
        HotKey(key: LogicalKeyboardKey.space, modifiers: [HotKeyModifier.control], scope: HotKeyScope.system),
        keyDownHandler: (HotKey hotKey) async {
          try {
            await windowManager.show();
            await windowManager.focus();
            appRouter.push('/raycast');
          } catch (_) {}
        },
      );
    } catch (e) {
      debugPrint('[hotKeyManager] Raycast registration error: $e');
    }

    // Initialize custom keyboard controls & Windows overlap detection
    await KeyboardShortcutService().initialize();

    await windowManager.ensureInitialized();
    
    // Layer 1: Native OS Compositor Material
    await Window.initialize();
    if (Platform.isWindows) {
      final deviceInfo = DeviceInfoPlugin();
      final windowsInfo = await deviceInfo.windowsInfo;
      final isWindows11 = windowsInfo.buildNumber >= 22000;
      
      await Window.setEffect(
        effect: isWindows11 ? WindowEffect.mica : WindowEffect.acrylic,
        dark: true,
        color: const Color(0x00000000), // Fully transparent base
      );
    } else if (Platform.isMacOS) {
      await Window.setEffect(
        effect: WindowEffect.hudWindow, // Deep vibrancy for macOS
        dark: true,
      );
    }

    const windowOptions = WindowOptions(
      size: Size(1280, 720),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Color(0xFF0A0D14),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);

      await windowManager.show();
      await windowManager.focus();
    });

    if (Platform.isWindows) {
      await windowManager.setPreventClose(true);
      
      await trayManager.setIcon('assets/images/icon.ico');
      await trayManager.setToolTip('IT Feels Music');

      windowManager.addListener(AppWindowListener());
      await SystemTrayManager.instance.init();
    }
  }

  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    final appLinks = AppLinks();
    appLinks.uriLinkStream.listen((uri) async {
      if (uri.scheme == 'itfeelsmusic') {
        if (uri.host == 'room') {
          final roomId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
          if (roomId != null && roomId.isNotEmpty) {
            final exp = uri.queryParameters['exp'];
            final route = exp != null ? '/room/$roomId?exp=$exp' : '/room/$roomId';
            appRouter.go(route);
            await windowManager.show();
            await windowManager.focus();
          }
        } else if (uri.host == 'song') {
          final songId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
          if (songId != null && songId.isNotEmpty) {
            appRouter.go('/song/$songId');
            await windowManager.show();
            await windowManager.focus();
          }
        } else if (uri.host == 'download') {
          final songId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
          if (songId != null && songId.isNotEmpty) {
            appRouter.go('/download/$songId');
            await windowManager.show();
            await windowManager.focus();
          }
        }
      } else if (uri.scheme == 'itfeels') {
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
    
    // Register custom URL protocol to ensure deep links work natively on Windows & Linux
    try {
      if (Platform.isWindows || Platform.isLinux) {
        final registry = getRegistry();
        final appPath = Platform.resolvedExecutable;
        await registry.add(ProtocolScheme(
          scheme: 'itfeelsmusic',
          appName: 'IT Feels',
          appPath: appPath,
        ));
        await registry.add(ProtocolScheme(
          scheme: 'itfeels',
          appName: 'IT Feels',
          appPath: appPath,
        ));

        // MPRIS Linux Desktop Entry Hardening
        if (Platform.isLinux) {
          try {
            final home = Platform.environment['HOME'] ?? '';
            if (home.isNotEmpty) {
              final desktopFile = File('$home/.local/share/applications/itfeels.desktop');
              if (!desktopFile.existsSync()) {
                await desktopFile.writeAsString('''[Desktop Entry]
Name=IT Feels
Comment=Music Player
Exec="$appPath" %u
Icon=itfeels
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Player;
MimeType=x-scheme-handler/itfeelsmusic;x-scheme-handler/itfeels;
StartupWMClass=it_feels_music
''');
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  await locator.allReady();

  runApp(UncontrolledProviderScope(
    container: appProviderContainer,
    child: const PixelPlayerSaavnApp(),
  ));

  // Warm up AddonManager JS engine in background bootstrap so we don't freeze the first frame
  Future(() async {
    try {
      await AddonManager().initialize();
    } catch (_) {} finally {
      FlutterNativeSplash.remove();
    }
  });
}

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class PixelPlayerSaavnApp extends ConsumerStatefulWidget {
  final AudioPlayerHandler? audioHandler;

  const PixelPlayerSaavnApp({super.key, this.audioHandler});

  @override
  ConsumerState<PixelPlayerSaavnApp> createState() => _PixelPlayerSaavnAppState();
}

class _PixelPlayerSaavnAppState extends ConsumerState<PixelPlayerSaavnApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void reassemble() {
    super.reassemble();
    // Hot Restart / Hot Reload Safety Hook:
    // Detach EqualizerService and flush audio filter graph to prevent dangling libmpv callbacks
    try {
      if (locator.isRegistered<EqualizerService>()) {
        locator<EqualizerService>().detachPlayer();
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      try {
        if (locator.isRegistered<ListenTogetherService>()) {
          locator<ListenTogetherService>().dispose();
        }
      } catch (_) {}
      try {
        if (locator.isRegistered<AudioPlayerHandler>()) {
          locator<AudioPlayerHandler>().dispose();
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      if (locator.isRegistered<ListenTogetherService>()) {
        locator<ListenTogetherService>().dispose();
      }
    } catch (_) {}
    try {
      if (locator.isRegistered<AudioPlayerHandler>()) {
        locator<AudioPlayerHandler>().dispose();
      }
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                scrollBehavior: const MaterialScrollBehavior().copyWith(
                  dragDevices: {
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.touch,
                    PointerDeviceKind.stylus,
                    PointerDeviceKind.trackpad,
                  },
                ),
                themeAnimationDuration: Duration.zero,
                routerConfig: appRouter,
                builder: (context, child) {
                  final isBanned = ref.watch(banProvider).isBanned;
                  if (isBanned) return const BannedScreen();
                  final mediaQuery = MediaQuery.of(context);
                  final clampedScaler = mediaQuery.textScaler.clamp(
                    minScaleFactor: 0.85,
                    maxScaleFactor: 1.15,
                  );
                  return MediaQuery(
                    data: mediaQuery.copyWith(textScaler: clampedScaler),
                    child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.tab ||
                            event.logicalKey.keyLabel.startsWith('Arrow')) {
                          isKeyboardNavigating.value = true;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Listener(
                      onPointerDown: (_) => isKeyboardNavigating.value = false,
                      onPointerHover: (_) => isKeyboardNavigating.value = false,
                      child: Consumer(
                        builder: (context, ref, childWidget) {
                          return Stack(
                            children: [
                              Column(
                                children: [
                                  Expanded(
                                    child: childWidget!,
                                  ),
                                ],
                              ),
                              if (kDebugMode) const DevToolkitOverlay(),
                            ],
                          );
                        },
                        child: InAppBroadcastListener(child: child ?? const SizedBox()),
                      ),
                    ),
                  ));
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
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show_app') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      try {
        if (locator.isRegistered<AudioPlayerHandler>()) {
          await locator<AudioPlayerHandler>().dispose();
        }
      } catch (_) {}
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
      exit(0);
    }
  }
}
