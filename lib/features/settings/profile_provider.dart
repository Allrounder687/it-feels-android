import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/services/storage_service.dart';

@immutable
class ProfileState {
  final String userName;
  final String userAvatar;

  const ProfileState({
    this.userName = '',
    this.userAvatar = '',
  });

  String getGreeting() {
    final hour = DateTime.now().hour;
    String timeGreeting = 'Good Evening';
    if (hour < 12) {
      timeGreeting = 'Good Morning';
    } else if (hour < 17) {
      timeGreeting = 'Good Afternoon';
    }

    if (userName.isNotEmpty) {
      return '$timeGreeting, $userName';
    }
    return timeGreeting;
  }

  ProfileState copyWith({
    String? userName,
    String? userAvatar,
  }) {
    return ProfileState(
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
    );
  }
}

class ProfileNotifier extends Notifier<ProfileState> {
  @override
  ProfileState build() {
    _loadProfile();
    return const ProfileState();
  }

  Future<void> _loadProfile() async {
    final profile = await StorageService.loadUserProfile();
    state = state.copyWith(
      userName: profile['name'] ?? '',
      userAvatar: profile['avatar'] ?? '',
    );
  }

  Future<void> updateProfile({required String name, required String avatar}) async {
    state = state.copyWith(userName: name, userAvatar: avatar);
    await StorageService.saveUserProfile(name: name, avatar: avatar);
  }
}

typedef ProfileProvider = ProfileNotifier;
