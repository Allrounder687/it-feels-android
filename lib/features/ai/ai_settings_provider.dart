import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/ai/ai_provider.dart';
import 'package:it_feels_music/core/ai/mock_ai_provider.dart';
import 'package:it_feels_music/core/ai/providers/gemini_provider.dart';
import 'package:it_feels_music/core/ai/providers/chatgpt_provider.dart';
import 'package:it_feels_music/core/ai/providers/claude_provider.dart';
import 'package:it_feels_music/services/ai_service.dart';
import 'package:it_feels_music/services/storage_service.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';

@immutable
class AISettingsState {
  final bool aiEnabled;
  final String selectedProviderId;
  final bool isLoading;
  final String? lastError;
  final String geminiKey;
  final String openaiKey;
  final String anthropicKey;

  const AISettingsState({
    this.aiEnabled = true,
    this.selectedProviderId = 'auto',
    this.isLoading = false,
    this.lastError,
    this.geminiKey = '',
    this.openaiKey = '',
    this.anthropicKey = '',
  });

  bool get isInitialized => AIService.instance.isInitialized;
  bool get isConfigured => geminiKey.isNotEmpty || openaiKey.isNotEmpty || anthropicKey.isNotEmpty;

  List<Map<String, String>> get providerOptions => [
        {'id': 'auto', 'name': 'Auto'},
        {'id': 'chatgpt', 'name': 'ChatGPT'},
        {'id': 'gemini', 'name': 'Gemini'},
        {'id': 'claude', 'name': 'Claude'},
      ];

  AISettingsState copyWith({
    bool? aiEnabled,
    String? selectedProviderId,
    bool? isLoading,
    String? lastError,
    String? geminiKey,
    String? openaiKey,
    String? anthropicKey,
  }) {
    return AISettingsState(
      aiEnabled: aiEnabled ?? this.aiEnabled,
      selectedProviderId: selectedProviderId ?? this.selectedProviderId,
      isLoading: isLoading ?? this.isLoading,
      lastError: lastError,
      geminiKey: geminiKey ?? this.geminiKey,
      openaiKey: openaiKey ?? this.openaiKey,
      anthropicKey: anthropicKey ?? this.anthropicKey,
    );
  }
}

class AISettingsNotifier extends Notifier<AISettingsState> {
  @override
  AISettingsState build() {
    _loadSettings();
    return const AISettingsState();
  }

  Future<void> _loadSettings() async {
    final settings = await StorageService.loadAISettings();
    final gemini = settings['geminiKey'] as String;
    final openai = settings['openaiKey'] as String;
    final anthropic = settings['anthropicKey'] as String;

    state = state.copyWith(
      aiEnabled: settings['aiEnabled'] as bool,
      selectedProviderId: settings['selectedProvider'] as String,
      geminiKey: gemini,
      openaiKey: openai,
      anthropicKey: anthropic,
    );

    _reinitializeProviders(gemini: gemini, openai: openai, anthropic: anthropic);
  }

  void _reinitializeProviders({String? gemini, String? openai, String? anthropic}) {
    final g = gemini ?? state.geminiKey;
    final o = openai ?? state.openaiKey;
    final a = anthropic ?? state.anthropicKey;

    final providers = <AIProvider>[MockAIProvider()];
    if (g.isNotEmpty) providers.add(GeminiProvider(g));
    if (o.isNotEmpty) providers.add(ChatGPTProvider(o));
    if (a.isNotEmpty) providers.add(ClaudeProvider(a));

    AIService.instance.initialize(providers);
  }

  void setAIEnabled(bool enabled) {
    state = state.copyWith(aiEnabled: enabled);
    _save();
  }

  void setSelectedProvider(String providerId) {
    state = state.copyWith(selectedProviderId: providerId);
    AIService.instance.switchProvider(providerId);
    _save();
  }

  void resetProvider() {
    state = state.copyWith(selectedProviderId: 'auto');
    _save();
  }

  void setGeminiKey(String key) {
    state = state.copyWith(geminiKey: key);
    _save();
    _reinitializeProviders(gemini: key);
  }

  void setOpenaiKey(String key) {
    state = state.copyWith(openaiKey: key);
    _save();
    _reinitializeProviders(openai: key);
  }

  void setAnthropicKey(String key) {
    state = state.copyWith(anthropicKey: key);
    _save();
    _reinitializeProviders(anthropic: key);
  }

  Future<AIResponse> askAI(String request, List<dynamic> library) async {
    if (!state.aiEnabled) {
      return AIResponse.failure(providerId: 'none', error: 'AI is disabled');
    }
    state = state.copyWith(isLoading: true, lastError: null);

    try {
      AIResponse result = await AIService.instance.generatePlaylistFromRequest(
        userRequest: request,
        localLibrary: library.cast<Song>(),
      );

      if (!result.success || result.resultSongs == null || result.resultSongs!.length < 10) {
        final existingSongs = result.success && result.resultSongs != null ? List<Song>.from(result.resultSongs!) : <Song>[];
        await Future.delayed(const Duration(milliseconds: 2000));
        
        final globalResult = await AIService.instance.generateGlobalPlaylistNames(
          userRequest: request,
        );
        
        if (globalResult.success && globalResult.resultNames != null) {
          final musicService = MusicApiService();
          final resolvedSongs = <Song>[];
          
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
              await Future.delayed(const Duration(milliseconds: 400));
            } catch (_) {}
          }
          
          existingSongs.addAll(resolvedSongs);
          
          if (existingSongs.isNotEmpty) {
            result = AIResponse.songs(providerId: globalResult.providerId, songs: existingSongs);
          } else {
            state = state.copyWith(lastError: 'Failed to find matching global songs on JioSaavn.');
          }
        } else if (!globalResult.success && existingSongs.isEmpty) {
          state = state.copyWith(lastError: globalResult.error);
        } else if (existingSongs.isNotEmpty) {
          result = AIResponse.songs(providerId: result.providerId, songs: existingSongs);
        }
      }

      if (!result.success && state.lastError == null) {
        state = state.copyWith(lastError: result.error);
      }
      return result;
    } catch (e) {
      final err = e.toString();
      state = state.copyWith(lastError: err);
      return AIResponse.failure(
        providerId: AIService.instance.currentProviderId ?? 'unknown',
        error: err,
      );
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void _save() {
    StorageService.saveAISettings(
      aiEnabled: state.aiEnabled,
      selectedProvider: state.selectedProviderId,
      geminiKey: state.geminiKey,
      openaiKey: state.openaiKey,
      anthropicKey: state.anthropicKey,
    );
  }
}

typedef AISettingsProvider = AISettingsNotifier;
