import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/theme/app_colors.dart';
import 'data/services/audio_player_handler.dart';
import 'data/services/jiosaavn_api_service.dart';
import 'data/services/lyrics_service.dart';
import 'providers/audio_player_provider.dart';
import 'providers/download_provider.dart';
import 'providers/home_provider.dart';
import 'providers/lyrics_provider.dart';
import 'providers/search_provider.dart';
import 'providers/settings_provider.dart';
import 'views/main_navigation_wrapper.dart';

late AudioPlayerHandler _audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.notification.request();

  // Initialize Android background AudioService
  _audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
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
    final apiService = JioSaavnApiService();
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
      ],
      child: MaterialApp(
        title: 'It Feels',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.midnightBackground,
          textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        ),
        home: const MainNavigationWrapper(),
      ),
    );
  }
}
