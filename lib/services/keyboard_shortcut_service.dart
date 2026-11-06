import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:it_feels_music/core/models/keyboard_shortcut_models.dart';
import 'package:it_feels_music/core/router/app_router.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/main.dart';
import 'package:it_feels_music/services/storage_service.dart';

class KeyboardShortcutService extends ChangeNotifier {
  static final KeyboardShortcutService _instance = KeyboardShortcutService._internal();
  factory KeyboardShortcutService() => _instance;
  KeyboardShortcutService._internal();

  final Map<PlayerAction, KeyboardShortcutCombination> _bindings = {};
  bool _isInitialized = false;

  Map<PlayerAction, KeyboardShortcutCombination> get bindings => Map.unmodifiable(_bindings);

  KeyboardShortcutCombination getCombination(PlayerAction action) {
    return _bindings[action] ?? action.defaultCombination;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Populate default combinations
    for (final action in PlayerAction.values) {
      _bindings[action] = action.defaultCombination;
    }

    // 2. Load custom overrides from persistent storage
    try {
      final saved = await StorageService.loadKeyboardShortcuts();
      if (saved != null) {
        for (final entry in saved.entries) {
          final action = PlayerAction.fromId(entry.key);
          if (action != null && entry.value is Map<String, dynamic>) {
            _bindings[action] = KeyboardShortcutCombination.fromJson(entry.value as Map<String, dynamic>);
          }
        }
      }
    } catch (e) {
      debugPrint('[KeyboardShortcutService] Error loading shortcuts: $e');
    }

    // 3. Register global in-app keyboard event handler
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    // 4. On Desktop, register background system hotkeys
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      await _syncSystemGlobalHotkeys();
    }
  }

  bool _isTextInputFocused() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    final widget = focus.context?.widget;
    if (widget is EditableText) return true;
    final isInsideEditable = focus.context?.findAncestorWidgetOfExactType<EditableText>() != null;
    return isInsideEditable;
  }

  bool _handleKeyEvent(KeyEvent event) {
    // Only process on key down / repeat
    if (event is! KeyDownEvent) return false;

    // Check if an editable text field currently has focus
    final textInputFocused = _isTextInputFocused();

    for (final entry in _bindings.entries) {
      final action = entry.key;
      final combination = entry.value;

      if (combination.matchesKeyEvent(event)) {
        // If user is actively typing in a text field:
        // Protect text input: Only trigger if the shortcut uses Ctrl or Alt modifiers
        if (textInputFocused && !combination.ctrl && !combination.alt) {
          return false;
        }

        executeAction(action);
        return true; // Mark as handled
      }
    }

    return false;
  }

  Future<void> executeAction(PlayerAction action, {BuildContext? context}) async {
    try {
      final player = appProviderContainer.read(audioPlayerProvider.notifier);
      final playerState = appProviderContainer.read(audioPlayerProvider);

      switch (action) {
        case PlayerAction.playPause:
          await player.togglePlayPause();
          break;

        case PlayerAction.nextTrack:
          await player.skipToNext();
          break;

        case PlayerAction.previousTrack:
          await player.skipToPrevious();
          break;

        case PlayerAction.seekForward:
          await player.seekForward(seconds: 10);
          break;

        case PlayerAction.seekBackward:
          await player.seekBackward(seconds: 10);
          break;

        case PlayerAction.volumeUp:
          await player.adjustVolume(5);
          break;

        case PlayerAction.volumeDown:
          await player.adjustVolume(-5);
          break;

        case PlayerAction.toggleMute:
          await player.toggleMute();
          break;

        case PlayerAction.toggleShuffle:
          player.toggleShuffle();
          break;

        case PlayerAction.toggleRepeat:
          player.toggleRepeat();
          break;

        case PlayerAction.toggleFavorite:
          final currentSong = playerState.currentSong;
          if (currentSong != null) {
            player.toggleFavorite(currentSong);
          }
          break;

        case PlayerAction.openSearch:
          try {
            appRouter.push('/search');
          } catch (_) {}
          break;

        case PlayerAction.toggleLyrics:
          try {
            appRouter.push('/lyrics');
          } catch (_) {}
          break;
      }
    } catch (e) {
      debugPrint('[KeyboardShortcutService] Action execution error ($action): $e');
    }
  }

  Future<void> updateBinding(PlayerAction action, KeyboardShortcutCombination newCombo) async {
    // If another action has the same shortcut, resolve overlap
    final conflictingAction = _bindings.entries
        .where((e) => e.key != action && e.value == newCombo)
        .map((e) => e.key)
        .firstOrNull;

    if (conflictingAction != null) {
      // Clear conflicting action or assign none
      _bindings.remove(conflictingAction);
    }

    _bindings[action] = newCombo;
    notifyListeners();

    await _saveBindings();

    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      await _syncSystemGlobalHotkeys();
    }
  }

  Future<void> resetBinding(PlayerAction action) async {
    _bindings[action] = action.defaultCombination;
    notifyListeners();
    await _saveBindings();

    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      await _syncSystemGlobalHotkeys();
    }
  }

  Future<void> resetAllToDefaults() async {
    _bindings.clear();
    for (final action in PlayerAction.values) {
      _bindings[action] = action.defaultCombination;
    }
    notifyListeners();
    await _saveBindings();

    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      await _syncSystemGlobalHotkeys();
    }
  }

  Future<void> _saveBindings() async {
    final Map<String, dynamic> jsonMap = {};
    for (final entry in _bindings.entries) {
      jsonMap[entry.key.id] = entry.value.toJson();
    }
    await StorageService.saveKeyboardShortcuts(jsonMap);
  }

  Future<void> _syncSystemGlobalHotkeys() async {
    // In-app keyboard shortcuts are fully handled via HardwareKeyboard.instance.addHandler
    // which operates cross-platform without native hotkey_manager plugin crashes.
    // Background OS hotkey registration is bypassed to prevent hotkey_manager_windows_plugin.dll
    // 0xc0000409 buffer overrun crashes on Windows 10/11.
    return;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }
}
