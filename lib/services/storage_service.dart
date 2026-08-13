import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/data/models/song_model.dart';

class StorageService {
  static const String _favKey = 'favorite_songs_json_v1';
  static const String _downKey = 'downloaded_songs_json_v1';
  static const String _wifiQualityKey = 'wifi_quality_setting';
  static const String _mobileQualityKey = 'mobile_quality_setting';
  static const String _downloadQualityKey = 'download_quality_setting';
  static const String _themeKey = 'primary_theme_setting';
  static const String _downloadPathKey = 'custom_download_path_setting';
  static const String _customPlaylistsKey = 'custom_playlists_v1';
  static const String _playbackStateKey = 'playback_state_v1';
  static const String _artistHistoryKey = 'artist_history_v1';
  static const String _recentSongsKey = 'recent_songs_v1';
  

  static const String _audioSpeedKey = 'audio_speed_v1';
  static const String _audioPitchKey = 'audio_pitch_v1';
  static const String _customVideoLinksKey = 'custom_video_links_v1';
  static const String _hasSeenOnboardingKey = 'has_seen_onboarding_v1';
  
  static const String _favoriteArtistsKey = 'favorite_artists_v1';

  static Future<List<String>> getFavoriteArtists() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoriteArtistsKey) ?? [];
  }

  static Future<void> setFavoriteArtists(List<String> artists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoriteArtistsKey, artists);
  }

  /// Learning Engine: Artist History
  static Future<void> saveListeningHistory(Map<String, int> artistCounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_artistHistoryKey, json.encode(artistCounts));
  }

  /// Onboarding State
  static Future<void> setHasSeenOnboarding(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenOnboardingKey, value);
  }

  static Future<bool> getHasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenOnboardingKey) ?? false;
  }

  static Future<Map<String, int>> loadListeningHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_artistHistoryKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as int));
    } catch (e) {
      return {};
    }
  }

  /// Learning Engine: Recently Played
  static Future<void> saveRecentlyPlayed(List<Song> songs) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = songs.map((s) => {
      'id': s.id,
      'saavnId': s.saavnId,
      'title': s.title,
      'artist': s.artist,
      'album': s.album,
      'duration': s.duration,
      'coverArt': s.coverArt,
      'encryptedMediaUrl': null, // Clear ephemeral CDN URL to force fresh fetch
      'hasLyrics': s.hasLyrics,
    }).toList();
    await prefs.setString(_recentSongsKey, json.encode(jsonList));
  }

  static Future<List<Song>> loadRecentlyPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentSongsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = json.decode(raw) as List<dynamic>;
      return decoded.map((item) => Song.fromJson(Map<String, dynamic>.from(item))).toList();
    } catch (e) {
      return [];
    }
  }

  /// Playback Memory State
  static Future<void> savePlaybackState(List<Song> queue, int currentIndex, {int positionSeconds = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    if (queue.isEmpty) {
      await prefs.remove(_playbackStateKey);
      return;
    }
    final jsonList = queue
        .map((s) => {
              'id': s.id,
              'saavnId': s.saavnId,
              'title': s.title,
              'artist': s.artist,
              'album': s.album,
              'duration': s.duration,
              'coverArt': s.coverArt,
              'encryptedMediaUrl': null, // Clear ephemeral CDN URL to force fresh fetch
              'hasLyrics': s.hasLyrics,
            })
        .toList();
    
    final state = {
      'currentIndex': currentIndex,
      'positionSeconds': positionSeconds,
      'queue': jsonList,
    };
    await prefs.setString(_playbackStateKey, json.encode(state));
  }

  static Future<Map<String, dynamic>?> loadPlaybackState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_playbackStateKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = json.decode(raw);
      final List<dynamic> rawQueue = decoded['queue'] ?? [];
      final queue = rawQueue.map((item) => Song.fromJson(Map<String, dynamic>.from(item))).toList();
      return {
        'currentIndex': decoded['currentIndex'] ?? 0,
        'positionSeconds': decoded['positionSeconds'] ?? 0,
        'queue': queue,
      };
    } catch (e) {
      return null;
    }
  }

  /// Custom Playlists
  static Future<void> saveCustomPlaylists(String jsonString) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customPlaylistsKey, jsonString);
  }

  static Future<String?> loadCustomPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customPlaylistsKey);
  }

  /// Default Category
  static Future<void> saveDefaultCategory(String category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_category', category);
  }

  static Future<String> loadDefaultCategory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('default_category') ?? 'Bollywood';
  }

  /// Save favorites list
  static Future<void> saveFavorites(List<Song> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = favorites
        .map((s) => {
              'id': s.id,
              'saavnId': s.saavnId,
              'title': s.title,
              'artist': s.artist,
              'album': s.album,
              'duration': s.duration,
              'coverArt': s.coverArt,
              'encryptedMediaUrl': null, // Clear ephemeral CDN URL to force fresh fetch
              'hasLyrics': s.hasLyrics,
            })
        .toList();
    await prefs.setString(_favKey, json.encode(jsonList));
  }

  /// Load favorites list
  static Future<List<Song>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final List<dynamic> decoded = json.decode(raw);
      return decoded.map((item) => Song.fromJson(Map<String, dynamic>.from(item))).toList();
    } catch (e) {
      return [];
    }
  }

  /// Save hidden songs list
  static Future<void> saveHiddenSongs(List<Song> hiddenSongs) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = hiddenSongs
        .map((s) => {
              'id': s.id,
              'saavnId': s.saavnId,
              'title': s.title,
              'artist': s.artist,
              'album': s.album,
              'duration': s.duration,
              'coverArt': s.coverArt,
              'encryptedMediaUrl': s.encryptedMediaUrl,
              'hasLyrics': s.hasLyrics,
            })
        .toList();
    await prefs.setString('hidden_songs_json_v1', json.encode(jsonList));
  }

  /// Load hidden songs list
  static Future<List<Song>> loadHiddenSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('hidden_songs_json_v1');
    if (raw == null || raw.isEmpty) return [];

    try {
      final List<dynamic> decoded = json.decode(raw);
      return decoded.map((item) => Song.fromJson(Map<String, dynamic>.from(item))).toList();
    } catch (e) {
      return [];
    }
  }

  /// Save downloaded songs list
  static Future<void> saveDownloads(List<Song> downloads) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = downloads
        .map((s) => {
              'id': s.id,
              'saavnId': s.saavnId,
              'title': s.title,
              'artist': s.artist,
              'album': s.album,
              'duration': s.duration,
              'coverArt': s.coverArt,
              'encryptedMediaUrl': s.encryptedMediaUrl,
              'hasLyrics': s.hasLyrics,
            })
        .toList();
    await prefs.setString(_downKey, json.encode(jsonList));
  }

  /// Load downloaded songs list
  static Future<List<Song>> loadDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_downKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final List<dynamic> decoded = json.decode(raw);
      return decoded.map((item) => Song.fromJson(Map<String, dynamic>.from(item))).toList();
    } catch (e) {
      return [];
    }
  }

  /// Quality & Theme Settings
  static Future<void> saveSettings({
    required String wifiQuality,
    required String mobileQuality,
    required String downloadQuality,
    required String theme,
    required String customDownloadPath,
    required bool enableAndroidAuto,
    required String hapticsMode,
    bool? useProxyBackend,
    String? proxyUrl,
    bool? enableMusicVideos,
    bool? useVideoAudioSource,
    bool? isDataSaverEnabled,
    bool? enableHardwareDecoding,
    String? defaultVideoQuality,
    String? graphicsQuality,
    bool? enableSmartDownloads,
    bool? useSolidTitleBar,
    bool? launchAtStartup,
    bool? adaptiveGlassTint,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wifiQualityKey, wifiQuality);
    await prefs.setString(_mobileQualityKey, mobileQuality);
    await prefs.setString(_downloadQualityKey, downloadQuality);
    await prefs.setString(_themeKey, theme);
    await prefs.setString(_downloadPathKey, customDownloadPath);
    await prefs.setBool('enable_android_auto', enableAndroidAuto);
    await prefs.setString('haptics_mode', hapticsMode);
    if (useProxyBackend != null) await prefs.setBool('use_proxy_backend', useProxyBackend);
    if (proxyUrl != null) await prefs.setString('proxy_url', proxyUrl);
    if (enableMusicVideos != null) await prefs.setBool('enable_music_videos', enableMusicVideos);
    if (useVideoAudioSource != null) await prefs.setBool('use_video_audio_source', useVideoAudioSource);
    if (isDataSaverEnabled != null) await prefs.setBool('is_data_saver_enabled', isDataSaverEnabled);
    if (enableHardwareDecoding != null) await prefs.setBool('enable_hardware_decoding', enableHardwareDecoding);
    if (defaultVideoQuality != null) await prefs.setString('default_video_quality', defaultVideoQuality);
    if (graphicsQuality != null) await prefs.setString('graphics_quality', graphicsQuality);
    if (enableSmartDownloads != null) await prefs.setBool('enable_smart_downloads_v1', enableSmartDownloads);
    if (useSolidTitleBar != null) await prefs.setBool('use_solid_title_bar', useSolidTitleBar);
    if (launchAtStartup != null) await prefs.setBool('launch_at_startup', launchAtStartup);
    if (adaptiveGlassTint != null) await prefs.setBool('adaptive_glass_tint', adaptiveGlassTint);
  }

  static Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'wifiQuality': prefs.getString(_wifiQualityKey) ?? '320 kbps (Very High)',
      'mobileQuality': prefs.getString(_mobileQualityKey) ?? '160 kbps (High)',
      'downloadQuality': prefs.getString(_downloadQualityKey) ?? '320 kbps (Very High)',
      'theme': prefs.getString(_themeKey) ?? 'Glass (Desktop)',
      'customDownloadPath': prefs.getString(_downloadPathKey) ?? '',
      'enableAndroidAuto': prefs.getBool('enable_android_auto') ?? false,
      'hapticsMode': prefs.getString('haptics_mode') ?? 'Off',
      'useProxyBackend': prefs.getBool('use_proxy_backend') ?? true,
      'proxyUrl': prefs.getString('proxy_url') ?? 'https://it-feels-proxy.cleverfox687.workers.dev',
      'enableMusicVideos': prefs.getBool('enable_music_videos') ?? false,
      'useVideoAudioSource': prefs.getBool('use_video_audio_source') ?? false,
      'isDataSaverEnabled': prefs.getBool('is_data_saver_enabled') ?? false,
      'enableHardwareDecoding': prefs.getBool('enable_hardware_decoding') ?? true,
      'defaultVideoQuality': prefs.getString('default_video_quality') ?? '720p',
      'graphicsQuality': prefs.getString('graphics_quality') ?? 'high',
      'enableSmartDownloads': prefs.getBool('enable_smart_downloads_v1') ?? true,
      'useSolidTitleBar': prefs.getBool('use_solid_title_bar') ?? false,
      'launchAtStartup': prefs.getBool('launch_at_startup') ?? false,
      'adaptiveGlassTint': prefs.getBool('adaptive_glass_tint') ?? true,
    };
  }

  /// Save Downloaded Offline Video
  static Future<void> saveDownloadedVideo(Map<String, dynamic> videoData) async {
    final prefs = await SharedPreferences.getInstance();
    final videos = await loadDownloadedVideos();
    videos.removeWhere((v) => v['id'] == videoData['id']);
    videos.insert(0, videoData);
    await prefs.setString('offline_downloaded_videos_v1', json.encode(videos));
  }

  /// Load Downloaded Offline Videos
  static Future<List<Map<String, dynamic>>> loadDownloadedVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('offline_downloaded_videos_v1');
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = json.decode(raw);
      return list.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Delete Downloaded Video
  static Future<void> deleteDownloadedVideo(String videoId) async {
    final prefs = await SharedPreferences.getInstance();
    final videos = await loadDownloadedVideos();
    videos.removeWhere((v) => v['id'] == videoId);
    await prefs.setString('offline_downloaded_videos_v1', json.encode(videos));
  }

  /// Audio Enhancements (DSP, Haptics, Speed, Pitch)
  static Future<void> saveAudioSettings({
    required bool dspEngine,
    required bool uiHaptics,
    required bool audioSyncHaptics,
    required double speed,
    required double pitch,
    required bool autoplay,
    required double crossfade,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dspEngine', dspEngine);
    await prefs.setBool('uiHaptics', uiHaptics);
    await prefs.setBool('audioSyncHaptics', audioSyncHaptics);
    await prefs.setDouble(_audioSpeedKey, speed);
    await prefs.setDouble(_audioPitchKey, pitch);
    await prefs.setBool('autoplay', autoplay);
    await prefs.setDouble('crossfade_v1', crossfade);
  }

  static Future<Map<String, dynamic>> loadAudioSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'dspEngine': prefs.getBool('dspEngine') ?? false,
      'uiHaptics': prefs.getBool('uiHaptics') ?? true,
      'audioSyncHaptics': prefs.getBool('audioSyncHaptics') ?? false,
      'speed': prefs.getDouble(_audioSpeedKey) ?? 1.0,
      'pitch': prefs.getDouble(_audioPitchKey) ?? 1.0,
      'autoplay': prefs.getBool('autoplay') ?? true,
      'crossfade': prefs.getDouble('crossfade_v1') ?? 0.0,
    };
  }

  // ── AI Settings ──────────────────────────────────────────────
  static const String _aiEnabledKey = 'ai_enabled_v1';
  static const String _aiProviderKey = 'ai_selected_provider_v1';
  static const String _geminiKeyKey = 'gemini_api_key_v1';
  static const String _openaiKeyKey = 'openai_api_key_v1';
  static const String _anthropicKeyKey = 'anthropic_api_key_v1';

  static Future<void> saveAISettings({
    required bool aiEnabled,
    required String selectedProvider,
    String? geminiKey,
    String? openaiKey,
    String? anthropicKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aiEnabledKey, aiEnabled);
    await prefs.setString(_aiProviderKey, selectedProvider);
    if (geminiKey != null) await prefs.setString(_geminiKeyKey, geminiKey);
    if (openaiKey != null) await prefs.setString(_openaiKeyKey, openaiKey);
    if (anthropicKey != null) await prefs.setString(_anthropicKeyKey, anthropicKey);
  }

  static Future<Map<String, dynamic>> loadAISettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'aiEnabled': prefs.getBool(_aiEnabledKey) ?? true,
      'selectedProvider': prefs.getString(_aiProviderKey) ?? 'auto',
      'geminiKey': prefs.getString(_geminiKeyKey) ?? '',
      'openaiKey': prefs.getString(_openaiKeyKey) ?? '',
      'anthropicKey': prefs.getString(_anthropicKeyKey) ?? '',
    };
  }

  // ── Profile Settings ──────────────────────────────────────────
  static const String _userNameKey = 'user_name_v1';
  static const String _userAvatarKey = 'user_avatar_v1';

  static Future<void> saveUserProfile({required String name, required String avatar}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, name);
    await prefs.setString(_userAvatarKey, avatar);
  }

  static Future<Map<String, String>> loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_userNameKey) ?? '',
      'avatar': prefs.getString(_userAvatarKey) ?? '',
    };
  }

  /// Custom Video Linking
  static Future<void> saveCustomVideoLink(String songId, String videoId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customVideoLinksKey);
    Map<String, String> links = {};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        links = decoded.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {}
    }
    links[songId] = videoId;
    await prefs.setString(_customVideoLinksKey, json.encode(links));
  }

  static Future<String?> getCustomVideoLink(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customVideoLinksKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded[songId]?.toString();
    } catch (_) {
      return null;
    }
  }
}
