import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class ProfileProvider extends ChangeNotifier {
  String _userName = '';
  String _userAvatar = '';

  String get userName => _userName;
  String get userAvatar => _userAvatar;

  ProfileProvider() {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await StorageService.loadUserProfile();
    _userName = profile['name'] ?? '';
    _userAvatar = profile['avatar'] ?? '';
    notifyListeners();
  }

  Future<void> updateProfile({required String name, required String avatar}) async {
    _userName = name;
    _userAvatar = avatar;
    await StorageService.saveUserProfile(name: name, avatar: avatar);
    notifyListeners();
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    String timeGreeting = 'Good Evening';
    if (hour < 12) {
      timeGreeting = 'Good Morning';
    } else if (hour < 17) {
      timeGreeting = 'Good Afternoon';
    }

    if (_userName.isNotEmpty) {
      return '$timeGreeting, $_userName';
    }
    return timeGreeting;
  }
}
