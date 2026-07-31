import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/services/backend_api_service.dart';
import 'package:it_feels_music/services/storage_service.dart';

@immutable
class SettingsState {
  final String wifiQuality;
  final String mobileQuality;
  final String downloadQuality;
  final String theme;
  final String defaultCategory;
  final String customDownloadPath;
  final bool enableAndroidAuto;
  final String hapticsMode;
  final bool useProxyBackend;
  final String proxyUrl;
  final bool enableMusicVideos;
  final bool useVideoAudioSource;
  final bool isDataSaverEnabled;

  const SettingsState({
    this.wifiQuality = '320 kbps (Very High)',
    this.mobileQuality = '160 kbps (High)',
    this.downloadQuality = '320 kbps (Very High)',
    this.theme = 'System (Material You)',
    this.defaultCategory = 'Bollywood',
    this.customDownloadPath = '',
    this.enableAndroidAuto = false,
    this.hapticsMode = 'Off',
    this.useProxyBackend = false,
    this.proxyUrl = 'https://it-feels-proxy.cleverfox687.workers.dev',
    this.enableMusicVideos = false,
    this.useVideoAudioSource = false,
    this.isDataSaverEnabled = false,
  });

  SettingsState copyWith({
    String? wifiQuality,
    String? mobileQuality,
    String? downloadQuality,
    String? theme,
    String? defaultCategory,
    String? customDownloadPath,
    bool? enableAndroidAuto,
    String? hapticsMode,
    bool? useProxyBackend,
    String? proxyUrl,
    bool? enableMusicVideos,
    bool? useVideoAudioSource,
    bool? isDataSaverEnabled,
  }) {
    return SettingsState(
      wifiQuality: wifiQuality ?? this.wifiQuality,
      mobileQuality: mobileQuality ?? this.mobileQuality,
      downloadQuality: downloadQuality ?? this.downloadQuality,
      theme: theme ?? this.theme,
      defaultCategory: defaultCategory ?? this.defaultCategory,
      customDownloadPath: customDownloadPath ?? this.customDownloadPath,
      enableAndroidAuto: enableAndroidAuto ?? this.enableAndroidAuto,
      hapticsMode: hapticsMode ?? this.hapticsMode,
      useProxyBackend: useProxyBackend ?? this.useProxyBackend,
      proxyUrl: proxyUrl ?? this.proxyUrl,
      enableMusicVideos: enableMusicVideos ?? this.enableMusicVideos,
      useVideoAudioSource: useVideoAudioSource ?? this.useVideoAudioSource,
      isDataSaverEnabled: isDataSaverEnabled ?? this.isDataSaverEnabled,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    _loadSettings();
    return const SettingsState();
  }

  Future<void> _loadSettings() async {
    final settings = await StorageService.loadSettings();
    final defaultCat = await StorageService.loadDefaultCategory();

    final useProxy = settings['useProxyBackend'] == true;
    final proxyUrlVal = settings['proxyUrl'] ?? 'https://it-feels-proxy.cleverfox687.workers.dev';

    BackendApiService.useProxyBackend = useProxy;
    BackendApiService.baseUrl = proxyUrlVal;

    state = state.copyWith(
      wifiQuality: settings['wifiQuality'],
      mobileQuality: settings['mobileQuality'],
      downloadQuality: settings['downloadQuality'],
      theme: settings['theme'],
      customDownloadPath: settings['customDownloadPath'],
      enableAndroidAuto: settings['enableAndroidAuto'],
      hapticsMode: settings['hapticsMode'],
      useProxyBackend: useProxy,
      proxyUrl: proxyUrlVal,
      enableMusicVideos: settings['enableMusicVideos'] == true,
      useVideoAudioSource: settings['useVideoAudioSource'] == true,
      isDataSaverEnabled: settings['isDataSaverEnabled'] == true,
      defaultCategory: defaultCat,
    );
  }

  void setWifiQuality(String quality) {
    state = state.copyWith(wifiQuality: quality);
    _save();
  }

  void setMobileQuality(String quality) {
    state = state.copyWith(mobileQuality: quality);
    _save();
  }

  void setDownloadQuality(String quality) {
    state = state.copyWith(downloadQuality: quality);
    _save();
  }

  void setTheme(String newTheme) {
    state = state.copyWith(theme: newTheme);
    _save();
  }

  void setDefaultCategory(String category) {
    state = state.copyWith(defaultCategory: category);
    StorageService.saveDefaultCategory(category);
  }

  void setCustomDownloadPath(String path) {
    state = state.copyWith(customDownloadPath: path);
    _save();
  }

  void setEnableAndroidAuto(bool enable) {
    state = state.copyWith(enableAndroidAuto: enable);
    _save();
  }

  void setHapticsMode(String mode) {
    state = state.copyWith(hapticsMode: mode);
    _save();
  }

  void setUseProxyBackend(bool enable) {
    BackendApiService.useProxyBackend = enable;
    state = state.copyWith(useProxyBackend: enable);
    _save();
  }

  void setProxyUrl(String url) {
    BackendApiService.baseUrl = url;
    state = state.copyWith(proxyUrl: url);
    _save();
  }

  void setEnableMusicVideos(bool enable) {
    state = state.copyWith(enableMusicVideos: enable);
    _save();
  }

  void setUseVideoAudioSource(bool value) {
    state = state.copyWith(useVideoAudioSource: value);
    _save();
  }

  void setDataSaverEnabled(bool value) {
    if (value) {
      state = state.copyWith(
        isDataSaverEnabled: true,
        wifiQuality: '64 kbps (Low)',
        mobileQuality: '64 kbps (Low)',
      );
    } else {
      state = state.copyWith(isDataSaverEnabled: false);
    }
    _save();
  }

  Future<void> _save() async {
    await StorageService.saveSettings(
      wifiQuality: state.wifiQuality,
      mobileQuality: state.mobileQuality,
      downloadQuality: state.downloadQuality,
      theme: state.theme,
      customDownloadPath: state.customDownloadPath,
      enableAndroidAuto: state.enableAndroidAuto,
      hapticsMode: state.hapticsMode,
      useProxyBackend: state.useProxyBackend,
      proxyUrl: state.proxyUrl,
      enableMusicVideos: state.enableMusicVideos,
      useVideoAudioSource: state.useVideoAudioSource,
      isDataSaverEnabled: state.isDataSaverEnabled,
    );
  }
}

// Backward compatibility alias for legacy code referencing SettingsProvider
typedef SettingsProvider = SettingsNotifier;
