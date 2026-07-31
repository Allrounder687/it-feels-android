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
// RIVERPOD ARCHITECTURE LAYER
// -------------------------------------------------------------------------

final audioPlayerProvider = ChangeNotifierProvider<AudioPlayerProvider>((ref) {
  throw UnimplementedError('audioPlayerProvider must be overridden in ProviderScope');
});

final downloadProvider = ChangeNotifierProvider<DownloadProvider>((ref) => DownloadProvider(apiService: locator<MusicApiService>()));
final homeProvider = ChangeNotifierProvider<HomeProvider>((ref) => HomeProvider(apiService: locator<MusicApiService>()));
final searchProvider = ChangeNotifierProvider<SearchProvider>((ref) => SearchProvider(apiService: locator<MusicApiService>()));
final lyricsProvider = ChangeNotifierProvider<LyricsProvider>((ref) => LyricsProvider(lyricsService: locator<LyricsService>()));

// Group 1: Immutable Notifiers
final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
final hiddenSongsProvider = NotifierProvider<HiddenSongsNotifier, HiddenSongsState>(HiddenSongsNotifier.new);
final listeningHistoryProvider = NotifierProvider<ListeningHistoryNotifier, ListeningHistoryState>(ListeningHistoryNotifier.new);
final profileProvider = NotifierProvider<ProfileNotifier, ProfileState>(ProfileNotifier.new);

// Remaining Bridge Providers
final customPlaylistProvider = ChangeNotifierProvider<CustomPlaylistProvider>((ref) => CustomPlaylistProvider());
final aiSettingsProvider = ChangeNotifierProvider<AISettingsProvider>((ref) => AISettingsProvider());
final authProvider = ChangeNotifierProvider<AuthProvider>((ref) => AuthProvider());
final videoPlayerProvider = ChangeNotifierProvider<VideoPlayerProvider>((ref) => VideoPlayerProvider());
final subscriptionProvider = ChangeNotifierProvider<SubscriptionProvider>((ref) => SubscriptionProvider());
