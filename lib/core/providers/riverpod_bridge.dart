import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/data/services/lyrics_service.dart';

import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/features/library/download_provider.dart';
import 'package:it_feels_music/features/home/home_provider.dart';
import 'package:it_feels_music/features/search/search_provider.dart';
import 'package:it_feels_music/features/player/lyrics_provider.dart';
import 'package:it_feels_music/features/settings/settings_provider.dart';
import 'package:it_feels_music/features/settings/hidden_songs_provider.dart';
import 'package:it_feels_music/features/library/custom_playlist_provider.dart';
import 'package:it_feels_music/features/library/listening_history_provider.dart';
import 'package:it_feels_music/features/ai/ai_settings_provider.dart';
import 'package:it_feels_music/features/settings/profile_provider.dart';
import 'package:it_feels_music/features/auth/auth_provider.dart';
import 'package:it_feels_music/features/player/video_player_provider.dart';
import 'package:it_feels_music/features/subscription/subscription_provider.dart';

// -------------------------------------------------------------------------
// RIVERPOD BRIDGE LAYER
// -------------------------------------------------------------------------
// This file serves as a temporary bridge to convert the legacy 
// ChangeNotifierProviders into Riverpod format during Phase 4 migration.
// Eventually, these ChangeNotifiers will be destroyed and rewritten as 
// strictly immutable Notifiers.
// -------------------------------------------------------------------------

// We use an UnimplementedError placeholder here because audioPlayer requires
// the global AudioPlayerHandler which is asynchronously initialized in main.dart.
// We will explicitly override this in ProviderScope in main.dart.
final audioPlayerProvider = ChangeNotifierProvider<AudioPlayerProvider>((ref) {
  throw UnimplementedError('audioPlayerProvider must be overridden in ProviderScope');
});

final downloadProvider = ChangeNotifierProvider<DownloadProvider>((ref) => DownloadProvider(apiService: locator<MusicApiService>()));
final homeProvider = ChangeNotifierProvider<HomeProvider>((ref) => HomeProvider(apiService: locator<MusicApiService>()));
final searchProvider = ChangeNotifierProvider<SearchProvider>((ref) => SearchProvider(apiService: locator<MusicApiService>()));
final lyricsProvider = ChangeNotifierProvider<LyricsProvider>((ref) => LyricsProvider(lyricsService: locator<LyricsService>()));
final settingsProvider = ChangeNotifierProvider<SettingsProvider>((ref) => SettingsProvider());
final hiddenSongsProvider = ChangeNotifierProvider<HiddenSongsProvider>((ref) => HiddenSongsProvider());
final customPlaylistProvider = ChangeNotifierProvider<CustomPlaylistProvider>((ref) => CustomPlaylistProvider());
final listeningHistoryProvider = ChangeNotifierProvider<ListeningHistoryProvider>((ref) => ListeningHistoryProvider());
final aiSettingsProvider = ChangeNotifierProvider<AISettingsProvider>((ref) => AISettingsProvider());
final profileProvider = ChangeNotifierProvider<ProfileProvider>((ref) => ProfileProvider());
final authProvider = ChangeNotifierProvider<AuthProvider>((ref) => AuthProvider());
final videoPlayerProvider = ChangeNotifierProvider<VideoPlayerProvider>((ref) => VideoPlayerProvider());
final subscriptionProvider = ChangeNotifierProvider<SubscriptionProvider>((ref) => SubscriptionProvider());
