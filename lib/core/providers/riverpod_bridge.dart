import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import 'package:it_feels_music/features/auth/ban_provider.dart';
import 'package:it_feels_music/features/player/video_player_provider.dart';
import 'package:it_feels_music/features/subscription/subscription_provider.dart';

// -------------------------------------------------------------------------
// RIVERPOD ARCHITECTURE LAYER - ALL NOTIFIERS & IMMUTABLE STATES
// -------------------------------------------------------------------------

// Core Audio Player Engine Notifier
final audioPlayerProvider = NotifierProvider<AudioPlayerNotifier, AudioPlayerState>(AudioPlayerNotifier.new);

// Group 1: Preferences & Settings Notifiers
final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
final hiddenSongsProvider = NotifierProvider<HiddenSongsNotifier, HiddenSongsState>(HiddenSongsNotifier.new);
final listeningHistoryProvider = NotifierProvider<ListeningHistoryNotifier, ListeningHistoryState>(ListeningHistoryNotifier.new);
final profileProvider = NotifierProvider<ProfileNotifier, ProfileState>(ProfileNotifier.new);

// Group 2: Library & Auth Notifiers
final customPlaylistProvider = NotifierProvider<CustomPlaylistNotifier, CustomPlaylistState>(CustomPlaylistNotifier.new);
final downloadProvider = NotifierProvider<DownloadNotifier, DownloadState>(DownloadNotifier.new);
final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
final banProvider = NotifierProvider<BanNotifier, BanState>(BanNotifier.new);
final aiSettingsProvider = NotifierProvider<AISettingsNotifier, AISettingsState>(AISettingsNotifier.new);

// Group 3: Media & Discovery Notifiers
final homeProvider = NotifierProvider<HomeNotifier, HomeState>(HomeNotifier.new);
final searchProvider = NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);
final lyricsProvider = NotifierProvider<LyricsNotifier, LyricsState>(LyricsNotifier.new);
final videoPlayerProvider = NotifierProvider<VideoPlayerNotifier, VideoPlayerState>(VideoPlayerNotifier.new);

// Subscription Provider
final subscriptionProvider = ChangeNotifierProvider<SubscriptionProvider>((ref) => SubscriptionProvider());

// Shorebird OTA Update State
final shorebirdUpdatePendingProvider = StateProvider<bool>((ref) => false);
