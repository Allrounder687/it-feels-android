import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:it_feels_music/core/models/keyboard_shortcut_models.dart';

enum ConflictSeverity {
  none,
  notice,
  warning,
  critical,
}

class ShortcutConflict {
  final ConflictSeverity severity;
  final String title;
  final String message;
  final PlayerAction? overlappingAction;

  const ShortcutConflict({
    required this.severity,
    required this.title,
    required this.message,
    this.overlappingAction,
  });

  bool get hasConflict => severity != ConflictSeverity.none;
}

class WindowsShortcutDetector {
  static DynamicLibrary? _user32;
  static DynamicLibrary? _kernel32;
  static int Function(int, int, int, int)? _registerHotKey;
  static int Function(int, int)? _unregisterHotKey;
  static int Function()? _getLastError;
  static bool _ffiInitialized = false;

  static void _initFfi() {
    if (_ffiInitialized) return;
    _ffiInitialized = true;

    if (!kIsWeb && Platform.isWindows) {
      try {
        _user32 = DynamicLibrary.open('user32.dll');
        _kernel32 = DynamicLibrary.open('kernel32.dll');

        _registerHotKey = _user32!
            .lookupFunction<Int32 Function(IntPtr, Int32, Uint32, Uint32), int Function(int, int, int, int)>('RegisterHotKey');
        _unregisterHotKey = _user32!
            .lookupFunction<Int32 Function(IntPtr, Int32), int Function(int, int)>('UnregisterHotKey');
        _getLastError = _kernel32!
            .lookupFunction<Uint32 Function(), int Function()>('GetLastError');
      } catch (e) {
        debugPrint('[WindowsShortcutDetector] FFI init failed: $e');
      }
    }
  }

  /// Maps LogicalKeyboardKey to Win32 Virtual Key (VK) code
  static int? getVkCode(LogicalKeyboardKey key) {
    final id = key.keyId;

    // Letters A-Z (0x00000061 - 0x0000007a)
    if (id >= 0x00000061 && id <= 0x0000007a) {
      return 0x41 + (id - 0x00000061);
    }
    // Numbers 0-9 (0x00000030 - 0x00000039)
    if (id >= 0x00000030 && id <= 0x00000039) {
      return id;
    }
    // Standard keys
    if (key == LogicalKeyboardKey.space) return 0x20;
    if (key == LogicalKeyboardKey.enter) return 0x0D;
    if (key == LogicalKeyboardKey.tab) return 0x09;
    if (key == LogicalKeyboardKey.escape) return 0x1B;
    if (key == LogicalKeyboardKey.arrowLeft) return 0x25;
    if (key == LogicalKeyboardKey.arrowUp) return 0x26;
    if (key == LogicalKeyboardKey.arrowRight) return 0x27;
    if (key == LogicalKeyboardKey.arrowDown) return 0x28;

    // Function keys F1-F12
    if (key == LogicalKeyboardKey.f1) return 0x70;
    if (key == LogicalKeyboardKey.f2) return 0x71;
    if (key == LogicalKeyboardKey.f3) return 0x72;
    if (key == LogicalKeyboardKey.f4) return 0x73;
    if (key == LogicalKeyboardKey.f5) return 0x74;
    if (key == LogicalKeyboardKey.f6) return 0x75;
    if (key == LogicalKeyboardKey.f7) return 0x76;
    if (key == LogicalKeyboardKey.f8) return 0x77;
    if (key == LogicalKeyboardKey.f9) return 0x78;
    if (key == LogicalKeyboardKey.f10) return 0x79;
    if (key == LogicalKeyboardKey.f11) return 0x7A;
    if (key == LogicalKeyboardKey.f12) return 0x7B;

    // Media keys
    if (key == LogicalKeyboardKey.mediaPlayPause) return 0xB3;
    if (key == LogicalKeyboardKey.mediaTrackNext) return 0xB0;
    if (key == LogicalKeyboardKey.mediaTrackPrevious) return 0xB1;
    if (key == LogicalKeyboardKey.audioVolumeMute) return 0xAD;
    if (key == LogicalKeyboardKey.audioVolumeDown) return 0xAE;
    if (key == LogicalKeyboardKey.audioVolumeUp) return 0xAF;

    return null;
  }

  /// Evaluates an input shortcut for internal app overlap, Windows system reservations, and live OS conflicts
  static ShortcutConflict checkConflict(
    KeyboardShortcutCombination combination, {
    PlayerAction? currentAction,
    Map<PlayerAction, KeyboardShortcutCombination>? allBindings,
  }) {
    // 1. Check internal app overlap
    if (allBindings != null) {
      for (final entry in allBindings.entries) {
        if (currentAction != null && entry.key == currentAction) continue;
        if (entry.value == combination) {
          return ShortcutConflict(
            severity: ConflictSeverity.warning,
            title: 'Internal Shortcut Overlap',
            message: 'This shortcut is already mapped to "${entry.key.label}". Saving will reassign it.',
            overlappingAction: entry.key,
          );
        }
      }
    }

    // 2. Check Windows System Reserved Key combinations
    final keyLabel = combination.keyLabel.toLowerCase();

    // Critical OS combos
    if (combination.alt && (keyLabel == 'f4' || combination.keyId == LogicalKeyboardKey.f4.keyId)) {
      return const ShortcutConflict(
        severity: ConflictSeverity.critical,
        title: 'Windows System Conflict: Alt + F4',
        message: 'Alt + F4 is reserved by Windows to terminate and close the active application.',
      );
    }

    if (combination.alt && (keyLabel == 'tab' || combination.keyId == LogicalKeyboardKey.tab.keyId)) {
      return const ShortcutConflict(
        severity: ConflictSeverity.critical,
        title: 'Windows System Conflict: Alt + Tab',
        message: 'Alt + Tab is reserved by Windows for the System Task Switcher.',
      );
    }

    if (combination.ctrl && combination.alt && (keyLabel == 'delete' || keyLabel == 'del')) {
      return const ShortcutConflict(
        severity: ConflictSeverity.critical,
        title: 'Windows Kernel Hotkey: Ctrl + Alt + Delete',
        message: 'Ctrl + Alt + Delete is captured by Windows Security Kernel and cannot be bound.',
      );
    }

    if (combination.ctrl && combination.shift && (keyLabel == 'escape' || keyLabel == 'esc')) {
      return const ShortcutConflict(
        severity: ConflictSeverity.warning,
        title: 'Windows Shortcut: Ctrl + Shift + Esc',
        message: 'Ctrl + Shift + Esc is the standard Windows shortcut for Task Manager.',
      );
    }

    // Windows Key (Meta) combos
    if (combination.meta) {
      final winCombos = {
        'd': 'Show / Hide Desktop',
        'l': 'Lock Computer',
        'e': 'Open File Explorer',
        'r': 'Open Run Dialog',
        'tab': 'Task View / Virtual Desktops',
        's': 'Windows Global Search',
        'q': 'Windows Search / Copilot',
        'a': 'Quick Settings & Action Center',
        'n': 'Notification Center / Calendar',
        'v': 'Windows Clipboard History',
        'g': 'Xbox Game Bar Overlay',
        'x': 'Windows Quick Link Menu',
        'p': 'Project Display Options',
        'i': 'Windows Settings',
        'h': 'Voice Typing',
        'w': 'Windows Widgets',
        'k': 'Cast / Connect Devices',
      };

      final desc = winCombos[keyLabel];
      if (desc != null) {
        return ShortcutConflict(
          severity: ConflictSeverity.warning,
          title: 'Windows Shell Reserved: Win + ${combination.keyLabel.toUpperCase()}',
          message: 'Win + ${combination.keyLabel.toUpperCase()} is reserved by Windows ($desc). Windows may intercept it before the player receives it.',
        );
      } else {
        return const ShortcutConflict(
          severity: ConflictSeverity.notice,
          title: 'Windows Key Modifier',
          message: 'The Windows (Win) key is often captured by the OS for system shell gestures.',
        );
      }
    }

    // Standard text editing collisions (when no Alt or Win modifiers are present)
    if (combination.ctrl && !combination.alt && !combination.shift) {
      if (keyLabel == 'c' || keyLabel == 'v' || keyLabel == 'x' || keyLabel == 'z' || keyLabel == 'a') {
        return ShortcutConflict(
          severity: ConflictSeverity.notice,
          title: 'Standard Clipboard Shortcut: Ctrl + ${keyLabel.toUpperCase()}',
          message: 'Ctrl + ${keyLabel.toUpperCase()} is used for text editing. When focused in input fields, text editing takes precedence.',
        );
      }
    }

    // 3. Live Win32 Native Check on Windows (skipped in automated tests)
    if (!kIsWeb && Platform.isWindows && !Platform.environment.containsKey('FLUTTER_TEST')) {
      final vk = getVkCode(combination.logicalKey);
      if (vk != null && combination.hasModifiers) {
        final conflict = _checkWin32GlobalHotkeyOverlap(combination, vk);
        if (conflict != null) {
          return conflict;
        }
      }
    }

    return const ShortcutConflict(
      severity: ConflictSeverity.none,
      title: 'Valid Shortcut',
      message: 'No conflicts detected. Ready to bind.',
    );
  }

  static ShortcutConflict? _checkWin32GlobalHotkeyOverlap(
    KeyboardShortcutCombination combination,
    int vk,
  ) {
    _initFfi();
    if (_registerHotKey == null || _unregisterHotKey == null || _getLastError == null) {
      return null;
    }

    int fsModifiers = 0;
    if (combination.alt) fsModifiers |= 0x0001; // MOD_ALT
    if (combination.ctrl) fsModifiers |= 0x0002; // MOD_CONTROL
    if (combination.shift) fsModifiers |= 0x0004; // MOD_SHIFT
    if (combination.meta) fsModifiers |= 0x0008; // MOD_WIN

    // Ephemeral test hotkey ID
    const int testId = 0x9FFE;

    try {
      final success = _registerHotKey!(0, testId, fsModifiers, vk);
      if (success == 0) {
        final error = _getLastError!();
        if (error == 1409) {
          // ERROR_HOTKEY_ALREADY_REGISTERED
          return const ShortcutConflict(
            severity: ConflictSeverity.warning,
            title: 'Windows Hotkey Overlap Detected (Error 1409)',
            message: 'This key combination is already captured globally by Windows or another running desktop application.',
          );
        }
      } else {
        // Successfully registered -> immediately unregister so we don't hold it
        _unregisterHotKey!(0, testId);
      }
    } catch (e) {
      debugPrint('[WindowsShortcutDetector] Live Win32 check exception: $e');
    }

    return null;
  }
}
