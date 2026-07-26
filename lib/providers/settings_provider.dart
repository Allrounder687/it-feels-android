import 'package:flutter/material.dart';
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

  Future<void> _loadSettings() async {
    final settings = await StorageService.loadSettings();
    _wifiQuality = settings['wifiQuality'];
    _mobileQuality = settings['mobileQuality'];
    _downloadQuality = settings['downloadQuality'];
    _theme = settings['theme'];
    _customDownloadPath = settings['customDownloadPath'];
    _enableAndroidAuto = settings['enableAndroidAuto'];
    _hapticsMode = settings['hapticsMode'];
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

  void _save() {
    StorageService.saveSettings(
      wifiQuality: _wifiQuality,
      mobileQuality: _mobileQuality,
      downloadQuality: _downloadQuality,
      theme: _theme,
      customDownloadPath: _customDownloadPath,
      enableAndroidAuto: _enableAndroidAuto,
      hapticsMode: _hapticsMode,
    );
    notifyListeners();
  }
}
