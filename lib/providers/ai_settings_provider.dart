import 'package:flutter/material.dart';
import '../core/ai/ai_provider.dart';
import '../core/ai/mock_ai_provider.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';

/// Manages AI feature state for the app.
/// Wires AIService into the Flutter provider tree.
class AISettingsProvider extends ChangeNotifier {
  bool _aiEnabled = true;
  String _selectedProviderId = 'auto';
  bool _isLoading = false;
  String? _lastError;

  AISettingsProvider() {
    _loadSettings();
  }

  bool get aiEnabled => _aiEnabled;
  String get selectedProviderId => _selectedProviderId;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  bool get isInitialized => AIService.instance.isInitialized;

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

    // Initialize AIService with mock provider (real providers added later)
    await AIService.instance.initialize([MockAIProvider()]);

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
    );
    notifyListeners();
  }
}
