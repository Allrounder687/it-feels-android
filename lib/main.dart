import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'core/theme/app_colors.dart';
import 'data/services/audio_player_handler.dart';
import 'data/services/music_api_service.dart';
import 'data/services/lyrics_service.dart';
import 'providers/audio_player_provider.dart';
import 'providers/download_provider.dart';
import 'providers/home_provider.dart';
import 'providers/hidden_songs_provider.dart';
import 'providers/custom_playlist_provider.dart';
import 'providers/listening_history_provider.dart';
import 'providers/lyrics_provider.dart';
import 'providers/search_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/ai_settings_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/video_player_provider.dart';
import 'providers/subscription_provider.dart';
import 'services/notification_service.dart';
import 'views/main_navigation_wrapper.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

late AudioPlayerHandler _audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Permission.notification.request();

  final notificationService = NotificationService();
  await notificationService.initialize();

  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  // Initialize Android background AudioService
  final apiService = MusicApiService();
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

  runApp(const PixelPlayerSaavnApp());
}

class PixelPlayerSaavnApp extends StatelessWidget {
  final AudioPlayerHandler? audioHandler;

  const PixelPlayerSaavnApp({super.key, this.audioHandler});

  @override
  Widget build(BuildContext context) {
    final apiService = MusicApiService();
    final lyricsService = LyricsService();
    final handler = audioHandler ?? _audioHandler;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AudioPlayerProvider(
            audioHandler: handler,
            apiService: apiService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => DownloadProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => HomeProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => SearchProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => LyricsProvider(lyricsService: lyricsService),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => HiddenSongsProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => CustomPlaylistProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ListeningHistoryProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => AISettingsProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ProfileProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => VideoPlayerProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => SubscriptionProvider(),
        ),
      ],
      child: DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          return Builder(
            builder: (context) {
              final colorScheme = darkDynamic ?? ColorScheme.fromSeed(seedColor: context.themeAccentColor, brightness: Brightness.dark);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final provider = Provider.of<AudioPlayerProvider>(context, listen: false);
                provider.setMaterialYouColors(colorScheme.surface, colorScheme.surfaceContainer, colorScheme.primary);
              });
              return MaterialApp(
                title: 'It Feels',
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  useMaterial3: true,
                  brightness: Brightness.dark,
                  colorScheme: colorScheme,
                  scaffoldBackgroundColor: context.themeBackgroundColor,
                  textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
                ),
                home: const MainNavigationWrapper(),
              );
            },
          );
        },
      ),
    );
  }
}
