import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/services/backend_api_service.dart';
import 'package:it_feels_music/services/storage_service.dart';
enum GraphicsQuality { high, medium, low }

@immutable
class SettingsState {
  bool get enablePerformanceMode => graphicsQuality == GraphicsQuality.low;
  bool get isPerformanceMode => graphicsQuality == GraphicsQuality.low;
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
  final bool enableHardwareDecoding;
  final String defaultVideoQuality;
  final GraphicsQuality graphicsQuality;
  final bool enableSmartDownloads;
  final bool useSolidTitleBar;
  final bool launchAtStartup;
  final bool adaptiveGlassTint;

  const SettingsState({
    this.wifiQuality = '320 kbps (Very High)',
    this.mobileQuality = '160 kbps (High)',
    this.downloadQuality = '320 kbps (Very High)',
    this.theme = 'Pitch Black (AMOLED)',
    this.defaultCategory = 'Bollywood',
    this.customDownloadPath = '',
    this.enableAndroidAuto = true,
    this.hapticsMode = 'Off',
    this.useProxyBackend = true,
    this.proxyUrl = 'https://it-feels-proxy.cleverfox687.workers.dev',
    this.enableMusicVideos = false,
    this.useVideoAudioSource = false,
    this.isDataSaverEnabled = false,
    this.enableHardwareDecoding = true,
    this.defaultVideoQuality = '480p',
    this.graphicsQuality = GraphicsQuality.high,
    this.enableSmartDownloads = true,
    this.useSolidTitleBar = false,
    this.launchAtStartup = false,
    this.adaptiveGlassTint = true,
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
    bool? enableHardwareDecoding,
    String? defaultVideoQuality,
    GraphicsQuality? graphicsQuality,
    bool? enableSmartDownloads,
    bool? useSolidTitleBar,
    bool? launchAtStartup,
    bool? adaptiveGlassTint,
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
      enableHardwareDecoding: enableHardwareDecoding ?? this.enableHardwareDecoding,
      defaultVideoQuality: defaultVideoQuality ?? this.defaultVideoQuality,
      graphicsQuality: graphicsQuality ?? this.graphicsQuality,
      enableSmartDownloads: enableSmartDownloads ?? this.enableSmartDownloads,
      useSolidTitleBar: useSolidTitleBar ?? this.useSolidTitleBar,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      adaptiveGlassTint: adaptiveGlassTint ?? this.adaptiveGlassTint,
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

    final loadedQuality = GraphicsQuality.values.firstWhere(
      (e) => e.name == settings['graphicsQuality'],
      orElse: () => GraphicsQuality.high,
    );

    state = state.copyWith(
      wifiQuality: settings['wifiQuality'],
      mobileQuality: settings['mobileQuality'],
      downloadQuality: settings['downloadQuality'],
      theme: settings['theme'],
      customDownloadPath: settings['customDownloadPath'],
      enableAndroidAuto: settings['enableAndroidAuto'] ?? true,
      hapticsMode: settings['hapticsMode'],
      useProxyBackend: useProxy,
      proxyUrl: proxyUrlVal,
      enableMusicVideos: settings['enableMusicVideos'] == true,
      useVideoAudioSource: settings['useVideoAudioSource'] == true,
      isDataSaverEnabled: settings['isDataSaverEnabled'] == true,
      enableHardwareDecoding: settings['enableHardwareDecoding'] ?? true, // Default to true
      defaultVideoQuality: settings['defaultVideoQuality'] as String? ?? '480p',
      graphicsQuality: loadedQuality,
      enableSmartDownloads: settings['enableSmartDownloads'] ?? true,
      useSolidTitleBar: settings['useSolidTitleBar'] ?? false,
      launchAtStartup: settings['launchAtStartup'] ?? false,
      adaptiveGlassTint: settings['adaptiveGlassTint'] ?? true,
      defaultCategory: defaultCat,
    );

    _applyGraphicsQuality(loadedQuality);
  }

  void _applyGraphicsQuality(GraphicsQuality quality) {
    if (kIsWeb) return; // PaintingBinding imageCache isn't easily manipulatable the same way on Web
    switch (quality) {
      case GraphicsQuality.low:
        PaintingBinding.instance.imageCache.maximumSize = 50;
        PaintingBinding.instance.imageCache.maximumSizeBytes = 20 * 1024 * 1024; // 20 MB
        break;
      case GraphicsQuality.medium:
        PaintingBinding.instance.imageCache.maximumSize = 150;
        PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50 MB
        break;
      case GraphicsQuality.high:
        PaintingBinding.instance.imageCache.maximumSize = 300;
        PaintingBinding.instance.imageCache.maximumSizeBytes = 150 * 1024 * 1024; // 150 MB
        break;
    }
  }

  void setWifiQuality(String quality) {
    state = state.copyWith(wifiQuality: quality);
    _save();
  }

  void setDefaultVideoQuality(String quality) {
    state = state.copyWith(defaultVideoQuality: quality);
    _save();
  }

  void setEnableHardwareDecoding(bool enable) {
    state = state.copyWith(enableHardwareDecoding: enable);
    _save();
  }

  void setGraphicsQuality(GraphicsQuality quality) {
    state = state.copyWith(graphicsQuality: quality);
    _applyGraphicsQuality(quality);
    _save();
  }

  void setEnableSmartDownloads(bool enable) {
    state = state.copyWith(enableSmartDownloads: enable);
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

  void setAdaptiveGlassTint(bool value) {
    state = state.copyWith(adaptiveGlassTint: value);
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
      enableHardwareDecoding: state.enableHardwareDecoding,
      defaultVideoQuality: state.defaultVideoQuality,
      graphicsQuality: state.graphicsQuality.name,
      enableSmartDownloads: state.enableSmartDownloads,
      useSolidTitleBar: state.useSolidTitleBar,
      launchAtStartup: state.launchAtStartup,
      adaptiveGlassTint: state.adaptiveGlassTint,
    );
  }

  Future<void> toggleSolidTitleBar(bool value) async {
    state = state.copyWith(useSolidTitleBar: value);
    _save();
  }

  Future<void> toggleLaunchAtStartup(bool value) async {
    state = state.copyWith(launchAtStartup: value);
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      if (value) {
        await LaunchAtStartup.instance.enable();
      } else {
        await LaunchAtStartup.instance.disable();
      }
    }
    _save();
  }
}

// Backward compatibility alias for legacy code referencing SettingsProvider
typedef SettingsProvider = SettingsNotifier;
