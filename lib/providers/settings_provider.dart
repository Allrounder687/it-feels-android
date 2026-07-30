import 'package:flutter/material.dart';
import '../services/backend_api_service.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  String _wifiQuality = '320 kbps (Very High)';
  String _mobileQuality = '160 kbps (High)';
  String _downloadQuality = '320 kbps (Very High)';
  String _theme = 'System (Material You)';
  String _defaultCategory = 'Bollywood';
  String _customDownloadPath = '';
  bool _enableAndroidAuto = false;
  String _hapticsMode = 'Off'; // Off, UI Only, Audio Sync
  bool _useProxyBackend = false;
  String _proxyUrl = 'https://it-feels-proxy.cleverfox687.workers.dev';
  bool _enableMusicVideos = false;
  bool _useVideoAudioSource = false; // Default: keep high quality audio from music player when in video mode
  bool _isDataSaverEnabled = false;

  SettingsProvider() {
    _loadSettings();
  }

  String get wifiQuality => _wifiQuality;
  String get mobileQuality => _mobileQuality;
  String get downloadQuality => _downloadQuality;
  String get theme => _theme;
  bool _isDataSaverEnabled = false;

  SettingsProvider() {
    _loadSettings();
  }

  String get wifiQuality => _wifiQuality;
  String get mobileQuality => _mobileQuality;
  String get downloadQuality => _downloadQuality;
  String get theme => _theme;
  String get defaultCategory => _defaultCategory;
  String get customDownloadPath => _customDownloadPath;
  bool get enableAndroidAuto => _enableAndroidAuto;
  String get hapticsMode => _hapticsMode;
  bool get useProxyBackend => _useProxyBackend;
  String get proxyUrl => _proxyUrl;
  bool get enableMusicVideos => _enableMusicVideos;
  bool get useVideoAudioSource => _useVideoAudioSource;
  bool get isDataSaverEnabled => _isDataSaverEnabled;

  Future<void> _loadSettings() async {
    final settings = await StorageService.loadSettings();
    _wifiQuality = settings['wifiQuality'] ?? _wifiQuality;
    _mobileQuality = settings['mobileQuality'] ?? _mobileQuality;
    _downloadQuality = settings['downloadQuality'] ?? _downloadQuality;
    _theme = settings['theme'] ?? _theme;
    _customDownloadPath = settings['customDownloadPath'] ?? _customDownloadPath;
    _enableAndroidAuto = settings['enableAndroidAuto'] ?? _enableAndroidAuto;
    _hapticsMode = settings['hapticsMode'] ?? _hapticsMode;
    _useProxyBackend = settings['useProxyBackend'] == true;
    _proxyUrl = settings['proxyUrl'] ?? _proxyUrl;
    _enableMusicVideos = settings['enableMusicVideos'] == true;
    _useVideoAudioSource = settings['useVideoAudioSource'] == true;
    _isDataSaverEnabled = settings['isDataSaverEnabled'] == true;
    
    BackendApiService.useProxyBackend = _useProxyBackend;
    BackendApiService.baseUrl = _proxyUrl;
    
    _defaultCategory = await StorageService.loadDefaultCategory();
    notifyListeners();
  }

  void setWifiQuality(String quality) {
    _wifiQuality = quality;
    _save();
  }

  void setMobileQuality(String quality) {
    _mobileQuality = quality;
    _save();
  }

  void setDownloadQuality(String quality) {
    _downloadQuality = quality;
    _save();
  }

  void setTheme(String newTheme) {
    _theme = newTheme;
    _save();
  }

  void setDefaultCategory(String category) {
    _defaultCategory = category;
    StorageService.saveDefaultCategory(category);
    notifyListeners();
  }

  void setCustomDownloadPath(String path) {
    _customDownloadPath = path;
    _save();
  }

  void setEnableAndroidAuto(bool enable) {
    _enableAndroidAuto = enable;
    _save();
  }

  void setHapticsMode(String mode) {
    _hapticsMode = mode;
    _save();
  }

  void setUseProxyBackend(bool enable) {
    _useProxyBackend = enable;
    BackendApiService.useProxyBackend = enable;
    _save();
  }

  void setProxyUrl(String url) {
    _proxyUrl = url;
    BackendApiService.baseUrl = url;
    _save();
  }

  void setEnableMusicVideos(bool enable) {
    _enableMusicVideos = enable;
    _save();
  }

  void setUseVideoAudioSource(bool value) {
    _useVideoAudioSource = value;
    _save();
  }

  void setDataSaverEnabled(bool value) {
    _isDataSaverEnabled = value;
    if (value) {
      _wifiQuality = '64 kbps (Low)';
      _mobileQuality = '64 kbps (Low)';
    }
    _save();
  }

  Future<void> _save() async {
    await StorageService.saveSettings({
      'wifiQuality': _wifiQuality,
      'mobileQuality': _mobileQuality,
      'downloadQuality': _downloadQuality,
      'theme': _theme,
      'customDownloadPath': _customDownloadPath,
      'enableAndroidAuto': _enableAndroidAuto,
      'hapticsMode': _hapticsMode,
      'useProxyBackend': _useProxyBackend,
      'proxyUrl': _proxyUrl,
      'enableMusicVideos': _enableMusicVideos,
      'useVideoAudioSource': _useVideoAudioSource,
      'isDataSaverEnabled': _isDataSaverEnabled,
    });
    notifyListeners();
  }
}
