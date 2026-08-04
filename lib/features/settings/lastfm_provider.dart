import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/services/lastfm_service.dart';

class LastfmState {
  final bool isLoading;
  final bool isConfigured;
  final bool isLoggedIn;
  final String? username;
  final String? errorMessage;

  const LastfmState({
    this.isLoading = true,
    this.isConfigured = false,
    this.isLoggedIn = false,
    this.username,
    this.errorMessage,
  });

  LastfmState copyWith({
    bool? isLoading,
    bool? isConfigured,
    bool? isLoggedIn,
    String? username,
    String? errorMessage,
  }) {
    return LastfmState(
      isLoading: isLoading ?? this.isLoading,
      isConfigured: isConfigured ?? this.isConfigured,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      username: username ?? this.username,
      errorMessage: errorMessage, // null by default unless explicitly set
    );
  }
}

class LastfmNotifier extends StateNotifier<LastfmState> {
  final LastfmService _lastfmService = locator<LastfmService>();

  LastfmNotifier() : super(const LastfmState()) {
    checkStatus();
  }

  Future<void> checkStatus() async {
    state = state.copyWith(isLoading: true);
    
    final loggedIn = await _lastfmService.isLoggedIn();
    String? username;
    if (loggedIn) {
      username = await _lastfmService.getUsername();
    }
    
    state = state.copyWith(
      isConfigured: _lastfmService.isConfigured,
      isLoggedIn: loggedIn,
      username: username,
      isLoading: false,
    );
  }

  Future<void> login(String username, String password) async {
    if (username.isEmpty || password.isEmpty) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    final success = await _lastfmService.authenticate(username, password);
    
    if (success) {
      await checkStatus();
    } else {
      state = state.copyWith(isLoading: false, errorMessage: "Failed to login to Last.fm. Check your credentials.");
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await _lastfmService.logout();
    await checkStatus();
  }
}

final lastfmProvider = StateNotifierProvider<LastfmNotifier, LastfmState>((ref) {
  return LastfmNotifier();
});
