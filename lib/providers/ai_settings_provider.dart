import 'package:flutter/material.dart';
import '../core/ai/ai_provider.dart';
import '../core/ai/mock_ai_provider.dart';
import '../core/ai/providers/gemini_provider.dart';
import '../core/ai/providers/chatgpt_provider.dart';
import '../core/ai/providers/claude_provider.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../data/models/song_model.dart';
import '../data/services/music_api_service.dart';

/// Manages AI feature state for the app.
/// Wires AIService into the Flutter provider tree.
class AISettingsProvider extends ChangeNotifier {
  bool _aiEnabled = true;
  String _selectedProviderId = 'auto';
  bool _isLoading = false;
  String? _lastError;

  String _geminiKey = '';
  String _openaiKey = '';
  String _anthropicKey = '';

  AISettingsProvider() {
    _loadSettings();
  }

  bool get aiEnabled => _aiEnabled;
  String get selectedProviderId => _selectedProviderId;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  bool get isInitialized => AIService.instance.isInitialized;

  String get geminiKey => _geminiKey;
  String get openaiKey => _openaiKey;
  String get anthropicKey => _anthropicKey;

  bool get isConfigured => _geminiKey.isNotEmpty || _openaiKey.isNotEmpty || _anthropicKey.isNotEmpty;

  List<Map<String, String>> get providerOptions => [
        {'id': 'auto', 'name': 'Auto'},
        {'id': 'chatgpt', 'name': 'ChatGPT'},
        {'id': 'gemini', 'name': 'Gemini'},
        {'id': 'claude', 'name': 'Claude'},
      ];

  Future<void> _loadSettings() async {
    final settings = await StorageService.loadAISettings();
    _aiEnabled = settings['aiEnabled'] as bool;
    _selectedProviderId = settings['selectedProvider'] as String;
    _geminiKey = settings['geminiKey'] as String;
    _openaiKey = settings['openaiKey'] as String;
    _anthropicKey = settings['anthropicKey'] as String;

    _reinitializeProviders();
  }

  void _reinitializeProviders() {
    final providers = <AIProvider>[MockAIProvider()];
    if (_geminiKey.isNotEmpty) providers.add(GeminiProvider(_geminiKey));
    if (_openaiKey.isNotEmpty) providers.add(ChatGPTProvider(_openaiKey));
    if (_anthropicKey.isNotEmpty) providers.add(ClaudeProvider(_anthropicKey));

    AIService.instance.initialize(providers);
    notifyListeners();
  }

  void setAIEnabled(bool enabled) {
    _aiEnabled = enabled;
    _save();
  }

  void setSelectedProvider(String providerId) {
    _selectedProviderId = providerId;
    AIService.instance.switchProvider(providerId);
    _save();
  }

  void resetProvider() {
    _selectedProviderId = 'auto';
    _save();
  }

  void setGeminiKey(String key) {
    _geminiKey = key;
    _save();
    _reinitializeProviders();
  }

  void setOpenaiKey(String key) {
    _openaiKey = key;
    _save();
    _reinitializeProviders();
  }

  void setAnthropicKey(String key) {
    _anthropicKey = key;
    _save();
    _reinitializeProviders();
  }

  Future<AIResponse> askAI(String request, List<dynamic> library) async {
    if (!_aiEnabled) {
      return AIResponse.failure(providerId: 'none', error: 'AI is disabled');
    }
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      AIResponse result = await AIService.instance.generatePlaylistFromRequest(
        userRequest: request,
        localLibrary: library.cast<Song>(),
      );

      // If library is empty or less than 10 songs were found, fall back to global search to fill the gap
      if (!result.success || result.resultSongs == null || result.resultSongs!.length < 10) {
        final existingSongs = result.success && result.resultSongs != null ? List<Song>.from(result.resultSongs!) : <Song>[];
        
        // Add a delay to prevent Gemini 429 Rate Limit error for back-to-back requests
        await Future.delayed(const Duration(milliseconds: 2000));
        
        final globalResult = await AIService.instance.generateGlobalPlaylistNames(
          userRequest: request,
        );
        
        if (globalResult.success && globalResult.resultNames != null) {
          final musicService = MusicApiService();
          final resolvedSongs = <Song>[];
          
          // Run sequentially instead of concurrently to prevent JioSaavn rate limits
          // and SocketException host lookup failures on Android devices.
          for (final name in globalResult.resultNames!) {
            try {
              final searchRes = await musicService.searchSongs(name, count: 1);
              if (searchRes.isNotEmpty) {
                final s = searchRes.first;
                final isDup = existingSongs.any((e) => e.id == s.id || (e.title == s.title && e.artist == s.artist)) ||
                              resolvedSongs.any((r) => r.id == s.id || (r.title == s.title && r.artist == s.artist));
                if (!isDup) {
                  resolvedSongs.add(s);
                }
              }
              // Prevent JioSaavn rate limit 429s
              await Future.delayed(const Duration(milliseconds: 400));
            } catch (_) {}
          }
          
          existingSongs.addAll(resolvedSongs);
          
          if (existingSongs.isNotEmpty) {
            result = AIResponse.songs(providerId: globalResult.providerId, songs: existingSongs);
          } else {
             _lastError = 'Failed to find matching global songs on JioSaavn.';
          }
        } else if (!globalResult.success && existingSongs.isEmpty) {
           _lastError = globalResult.error;
        } else if (existingSongs.isNotEmpty) {
           // We have some local songs, but global failed. Just use local.
           result = AIResponse.songs(providerId: result.providerId, songs: existingSongs);
        }
      }

      if (!result.success && _lastError == null) {
        _lastError = result.error;
      }
      return result;
    } catch (e) {
      _lastError = e.toString();
      return AIResponse.failure(
        providerId: AIService.instance.currentProviderId ?? 'unknown',
        error: _lastError!,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _save() {
    StorageService.saveAISettings(
      aiEnabled: _aiEnabled,
      selectedProvider: _selectedProviderId,
      geminiKey: _geminiKey,
      openaiKey: _openaiKey,
      anthropicKey: _anthropicKey,
    );
    notifyListeners();
  }
}
