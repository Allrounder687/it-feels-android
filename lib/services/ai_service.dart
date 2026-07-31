import 'dart:async';
import 'package:flutter/material.dart';
import 'package:it_feels_music/core/ai/ai_provider.dart';
import 'package:it_feels_music/data/models/song_model.dart';

class AIService extends ChangeNotifier {
  static AIService? _instance;
  static AIService get instance {
    _instance ??= AIService._();
    return _instance!;
  }

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  final Map<String, AIProvider> _providerRegistry = {};
  final Map<String, Map<String, dynamic>> _providerStats = {};
  final List<AIProvider> _providerOrder = [];

  AIProvider? _activeProvider;
  String _selectedProviderId = '';
  String? _persistedSelection;
  bool _enableFailureMode = false;
  Duration? _lastOperationDuration;

  AIService._();

  bool get enableFailureMode => _enableFailureMode;
  set enableFailureMode(bool value) {
    if (_enableFailureMode != value) {
      _enableFailureMode = value;
      notifyListeners();
    }
  }

  AIProvider? get activeProvider => _activeProvider;
  String? get currentProviderId => _activeProvider?.id;
  AIProvider? get currentProvider => _activeProvider;
  Duration? get lastOperationDuration => _lastOperationDuration;

  Map<String, dynamic>? getProviderStats(String id) => _providerStats[id];

  bool get isAvailable {
    try {
      final current = currentProvider;
      if (current == null) return false;
      final stats = _providerStats[current.id];
      if (stats == null) return true;
      final failing = stats['failing_until'];
      if (failing is int && failing > DateTime.now().millisecondsSinceEpoch) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> initialize(List<AIProvider> providers) async {
    _providerRegistry.clear();
    _providerOrder.clear();
    for (final p in providers) {
      _providerRegistry[p.id] = p;
      _providerOrder.add(p);
      if (!_providerStats.containsKey(p.id)) {
        _providerStats[p.id] = <String, dynamic>{};
      }
    }
    if (_providerOrder.isNotEmpty) {
      final persisted = _persistedSelection;
      if (persisted != null && _providerRegistry.containsKey(persisted) && persisted != 'auto') {
        _selectProvider(persisted, notify: false);
      } else {
        // If 'auto' or not found, try to pick the first REAL provider (not mock)
        _activeProvider = _providerOrder.firstWhere(
          (p) => p.id != 'mock',
          orElse: () => _providerOrder.first,
        );
      }
      _selectedProviderId = _activeProvider?.id ?? '';
    }
    _isInitialized = true;
    notifyListeners();
  }

  bool switchProvider(String id) {
    return _selectProvider(id, notify: true);
  }

  bool _selectProvider(String id, {bool notify = true}) {
    if (!_providerRegistry.containsKey(id)) return false;
    _activeProvider = _providerRegistry[id];
    _selectedProviderId = id;
    _persistedSelection = id;
    if (notify) notifyListeners();
    return true;
  }

  Future<AIResponse> withProvider(
    String providerId,
    Future<AIResponse> Function(AIProvider) action,
  ) async {
    final provider = _providerRegistry[providerId];
    if (provider == null) {
      return AIResponse.failure(providerId: providerId, error: 'Unknown provider');
    }

    final stats = _providerStats[providerId] ?? <String, dynamic>{};
    final failingUntil = stats['failing_until'];
    if (failingUntil is int && failingUntil > DateTime.now().millisecondsSinceEpoch) {
      final waitMs = failingUntil - DateTime.now().millisecondsSinceEpoch;
      throw Exception('Provider is temporarily failing. $waitMs ms left.');
    }

    try {
      final watch = Stopwatch()..start();
      final result = await action(provider);
      watch.stop();
      _lastOperationDuration = watch.elapsed;
      return result;
    } catch (error) {
      _lastOperationDuration = null;
      final message = _extractUserFacingMessage(error);
      _recordFailure(providerId, message);
      rethrow;
    }
  }

  void _recordFailure(String providerId, String? error) {
    final stats = _providerStats[providerId];
    if (stats == null) return;
    // Set a very short lockout (e.g. 10 seconds) just to prevent spam loops, 
    // instead of 15 minutes which ruins UX if it was a simple network drop.
    stats['failing_until'] =
        DateTime.now().add(const Duration(seconds: 10)).millisecondsSinceEpoch;
    stats['last_error'] = error;
  }

  Future<AIResponse> _executeWithProvider<T>(
    Future<T> Function() action,
    String functionName,
  ) async {
    if (!_isInitialized) {
      return AIResponse.failure(
        providerId: _selectedProviderId,
        error: 'AI service is not ready yet.',
      );
    }
    if (!isAvailable) {
      return AIResponse.failure(
        providerId: _selectedProviderId,
        error: 'No AI provider is currently available.',
      );
    }
    try {
      final watch = Stopwatch()..start();
      final result = await action();
      watch.stop();
      
      final providerId = _activeProvider?.id ?? 'unknown';
      _lastOperationDuration = watch.elapsed;
      
      if (result is List<Song>) {
        return AIResponse.songs(providerId: providerId, songs: result);
      } else if (result is List<String>) {
        return AIResponse.names(providerId: providerId, names: result);
      } else if (result is String) {
        return AIResponse.text(providerId: providerId, text: result);
      }
      return AIResponse.failure(
        providerId: providerId,
        error: 'Unknown response type from provider.',
      );
    } catch (e) {
      String providerId = 'unknown';
      if (_selectedProviderId.isNotEmpty && _providerRegistry.containsKey(_selectedProviderId)) {
        providerId = _selectedProviderId;
      } else if (_activeProvider != null) {
        providerId = _activeProvider!.id;
      }
      final message = _extractUserFacingMessage(e);
      _recordFailure(providerId, message);
      _lastOperationDuration = null;
      return AIResponse.failure(providerId: providerId, error: message);
    }
  }

  String _extractUserFacingMessage(Object error) {
    final message = error.toString();
    if (message.isEmpty) return 'Something went wrong with AI.';
    final lower = message.toLowerCase();
    if (lower.contains('network') || lower.contains('connection')) {
      return 'No internet connection. Please try again.';
    }
    if (lower.contains('timeout')) {
      return 'AI request timed out. Please try again.';
    }
    if (lower.contains('invalid') || lower.contains('format')) {
      return 'Unable to understand that request. Please rephrase.';
    }
    if (lower.contains('overloaded') || lower.contains('busy') || lower.contains('503') || lower.contains('unavailable')) {
      return 'AI service is temporarily unavailable. Please try shortly.';
    }
    return message;
  }

  Future<AIResponse> generatePlaylistFromRequest({
    required String userRequest,
    required List<Song> localLibrary,
    Duration? maxResponseTime,
  }) async {
    final provider = _activeProvider;
    if (provider == null) {
      return AIResponse.failure(providerId: 'unknown', error: 'No AI provider configured');
    }
    if (localLibrary.isEmpty) {
      return AIResponse.failure(providerId: provider.id, error: 'Your music library is empty');
    }
    if (userRequest.trim().isEmpty) {
      return AIResponse.failure(providerId: provider.id, error: 'Please enter a request');
    }
    return _executeWithProvider(
      () => provider.generatePlaylistFromRequest(
        userRequest: userRequest,
        localLibrary: localLibrary,
        maxResponseTime: maxResponseTime,
      ),
      'generatePlaylistFromRequest',
    );
  }

  Future<AIResponse> generateGlobalPlaylistNames({
    required String userRequest,
    Duration? maxResponseTime,
  }) async {
    final provider = _activeProvider;
    if (provider == null) {
      return AIResponse.failure(providerId: 'unknown', error: 'No AI provider configured');
    }
    if (userRequest.trim().isEmpty) {
      return AIResponse.failure(providerId: provider.id, error: 'Please enter a request');
    }
    return _executeWithProvider(
      () => provider.generateGlobalPlaylistNames(
        userRequest: userRequest,
        maxResponseTime: maxResponseTime,
      ),
      'generateGlobalPlaylistNames',
    );
  }

  Future<AIResponse> reorderQueueByMood({
    required List<Song> queue,
    required String moodDescription,
  }) async {
    final provider = _activeProvider;
    if (provider == null) {
      return AIResponse.failure(providerId: 'unknown', error: 'No AI provider configured');
    }
    if (queue.isEmpty) {
      return AIResponse.failure(providerId: provider.id, error: 'Queue is empty');
    }
    return _executeWithProvider(
      () => provider.reorderQueueByMood(queue: queue, moodDescription: moodDescription),
      'reorderQueueByMood',
    );
  }

  Future<AIResponse> suggestPlaylistName({
    required String initialName,
    required List<Song> songs,
  }) {
    final provider = _activeProvider;
    if (provider == null) throw Exception('No AI provider configured');
    return _executeWithProvider(
      () => provider.suggestPlaylistName(initialName: initialName, songs: songs),
      'suggestPlaylistName',
    );
  }

  Future<AIResponse> describePlaylistVibe({required List<Song> songs}) {
    final provider = _activeProvider;
    if (provider == null) throw Exception('No AI provider configured');
    return _executeWithProvider(
      () => provider.describePlaylistVibe(songs: songs),
      'describePlaylistVibe',
    );
  }

  Future<AIResponse> recommendSongs({
    required List<Song> library,
    required String context,
  }) {
    final provider = _activeProvider;
    if (provider == null) throw Exception('No AI provider configured');
    if (library.isEmpty) {
      return Future.value(AIResponse.failure(providerId: provider.id, error: 'Library is empty'));
    }
    return _executeWithProvider(
      () => provider.recommendSongs(library: library, context: context),
      'recommendSongs',
    );
  }
}
