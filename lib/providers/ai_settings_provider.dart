import 'package:flutter/material.dart';
import '../core/ai/ai_provider.dart';
import '../core/ai/mock_ai_provider.dart';
import '../core/ai/providers/gemini_provider.dart';
import '../core/ai/providers/chatgpt_provider.dart';
import '../core/ai/providers/claude_provider.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';

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
      final result = await AIService.instance.generatePlaylistFromRequest(
        userRequest: request,
        localLibrary: library.cast(),
      );
      if (!result.success) {
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
