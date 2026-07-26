import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  String _wifiQuality = '320 kbps (Very High)';
  String _mobileQuality = '160 kbps (High)';
  String _downloadQuality = '320 kbps (Very High)';
  String _theme = 'Dynamic (Album Art)';
  String _defaultCategory = 'Bollywood';

  SettingsProvider() {
    _loadSettings();
  }

  String get wifiQuality => _wifiQuality;
  String get mobileQuality => _mobileQuality;
  String get downloadQuality => _downloadQuality;
  String get theme => _theme;
  String get defaultCategory => _defaultCategory;

  Future<void> _loadSettings() async {
    final settings = await StorageService.loadSettings();
    _wifiQuality = settings['wifiQuality']!;
    _mobileQuality = settings['mobileQuality']!;
    _downloadQuality = settings['downloadQuality']!;
    _theme = settings['theme']!;
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

  void _save() {
    StorageService.saveSettings(
      wifiQuality: _wifiQuality,
      mobileQuality: _mobileQuality,
      downloadQuality: _downloadQuality,
      theme: _theme,
    );
    notifyListeners();
  }
}
